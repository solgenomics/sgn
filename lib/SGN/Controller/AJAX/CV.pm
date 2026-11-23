=head1 NAME

SGN::Controller::AJAX::CV - a REST controller class for managing cv-level
properties (visibility and editability) through the cvprop table

=head1 DESCRIPTION

Properties are stored as cvprop rows whose type is a cvterm in the
'cv_property' cv ('cv_visible' or 'cv_editable'), with a value of 0 or 1
and a rank of 0. These cvterms are created by the AddCVProperty dbpatch.

All endpoints require curator privileges.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

package SGN::Controller::AJAX::CV;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

=head2 set_visibility

Public Path: /ajax/cv/set_visibility

POST parameters: cv_id, value (0 or 1)

Sets whether a cv is visible through the user interface.

=cut

sub set_visibility : Path('/ajax/cv/set_visibility') : ActionClass('REST') { }

sub set_visibility_POST {
    my ($self, $c) = @_;
    $self->_set_cv_property($c, 'cv_visible');
}

=head2 set_editable

Public Path: /ajax/cv/set_editable

POST parameters: cv_id, value (0 or 1)

Sets whether a cv is editable through the user interface.

=cut

sub set_editable : Path('/ajax/cv/set_editable') : ActionClass('REST') { }

sub set_editable_POST {
    my ($self, $c) = @_;
    $self->_set_cv_property($c, 'cv_editable');
}

=head2 get_properties

Public Path: /ajax/cv/get_properties

GET parameters: cv_ids (comma-separated list of cv_ids)

Returns the visibility and editability of each requested cv:

  { cvs => [ { cv_id => 4, cv_name => '...', cv_visible => 1, cv_editable => 0 }, ... ] }

A property with no cvprop row is returned as null (undef).

=cut

sub get_properties : Path('/ajax/cv/get_properties') : ActionClass('REST') { }

sub get_properties_GET {
    my ($self, $c) = @_;

    my @cv_ids = grep { length } split /\s*,\s*/, ($c->req->param('cv_ids') // '');
    if (!@cv_ids || grep { !/^\d+$/ } @cv_ids) {
        $c->stash->{rest} = { error => "cv_ids must be a comma-separated list of cv_ids." };
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my %type_name_for;   # cvterm_id => 'cv_visible' | 'cv_editable'
    my $property_terms = $schema->resultset('Cv::Cvterm')->search(
        { 'me.name' => { -in => [ 'cv_visible', 'cv_editable' ] }, 'cv.name' => 'cv_property' },
        { join => 'cv' }
    );
    while (my $term = $property_terms->next) {
        $type_name_for{ $term->cvterm_id } = $term->name;
    }
    if (keys %type_name_for != 2) {
        $c->stash->{rest} = { error => "The 'cv_visible' and 'cv_editable' terms were not found in the 'cv_property' cv. Have the dbpatches been run?" };
        return;
    }

    my %result;
    my $cvs = $schema->resultset('Cv::Cv')->search({ cv_id => { -in => \@cv_ids } });
    while (my $cv = $cvs->next) {
        $result{ $cv->cv_id } = {
            cv_id       => $cv->cv_id,
            cv_name     => $cv->name,
            cv_visible  => undef,
            cv_editable => undef,
        };
    }

    my $cvprops = $schema->resultset('Cv::Cvprop')->search({
        cv_id   => { -in => \@cv_ids },
        type_id => { -in => [ keys %type_name_for ] },
        rank    => 0,
    });
    while (my $prop = $cvprops->next) {
        $result{ $prop->cv_id }->{ $type_name_for{ $prop->type_id } } = $prop->value;
    }

    $c->stash->{rest} = { cvs => [ sort { lc($a->{cv_name}) cmp lc($b->{cv_name}) } values %result ] };
}

# Shared implementation: upserts the cvprop row (cv_id, type_id = $property_name term, rank 0).
sub _set_cv_property {
    my ($self, $c, $property_name) = @_;

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to change cv properties." };
        return;
    }
    if (!$c->user()->check_roles('curator')) {
        $c->stash->{rest} = { error => "You must have curator privileges to change cv properties." };
        return;
    }

    my $cv_id = $c->req->param('cv_id');
    my $value = $c->req->param('value');

    if (!defined $cv_id || $cv_id !~ /^\d+$/) {
        $c->stash->{rest} = { error => "A valid cv_id is required." };
        return;
    }
    if (!defined $value || $value !~ /^[01]$/) {
        $c->stash->{rest} = { error => "value must be 0 or 1." };
        return;
    }

    my $sp_person_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    my $cv = $schema->resultset('Cv::Cv')->find({ cv_id => $cv_id });
    if (!$cv) {
        $c->stash->{rest} = { error => "No cv found with cv_id $cv_id." };
        return;
    }

    my $property_term = $schema->resultset('Cv::Cvterm')->find(
        { 'me.name' => $property_name, 'cv.name' => 'cv_property' },
        { join => 'cv' }
    );
    if (!$property_term) {
        $c->stash->{rest} = { error => "The '$property_name' term was not found in the 'cv_property' cv. Have the dbpatches been run?" };
        return;
    }

    eval {
        my $cvprop = $schema->resultset('Cv::Cvprop')->find({
            cv_id   => $cv_id,
            type_id => $property_term->cvterm_id,
            rank    => 0,
        });

        if ($cvprop) {
            $cvprop->update({ value => $value });
        } else {
            $schema->resultset('Cv::Cvprop')->create({
                cv_id   => $cv_id,
                type_id => $property_term->cvterm_id,
                value   => $value,
                rank    => 0,
            });
        }
    };
    if ($@) {
        my $error = $@;
        print STDERR "Error setting $property_name for cv_id $cv_id: $error\n";
        $c->stash->{rest} = { error => "Error setting $property_name: $error" };
        return;
    }

    $c->stash->{rest} = { success => 1, cv_id => $cv_id, $property_name => $value };
}

1;

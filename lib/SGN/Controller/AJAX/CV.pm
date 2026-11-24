=head1 NAME

SGN::Controller::AJAX::CV - a REST controller class for managing cv-level
properties (visibility, editability and composable cvtype) through the cvprop table

=head1 DESCRIPTION

Properties are stored as cvprop rows whose type is a cvterm in the
'cv_property' cv ('cv_visible' or 'cv_editable'), with a value of 0 or 1
and a rank of 0. These cvterms are created by the AddCVProperty dbpatch.

A cv's composable cvtype (trait_ontology, method_ontology, ...) is stored as a
cvprop row whose type is a cvterm in the 'composable_cvtypes' cv.

Endpoints that change data require curator privileges;
get_composable_cvs_of_type only requires a login.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

package SGN::Controller::AJAX::CV;

use Moose;
use CXGN::Onto;

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

  { cvs => [ { cv_id => 4, cv_name => '...', cv_visible => 1, cv_editable => 0, composable_cvtype => 'trait_ontology' }, ... ] }

A property with no cvprop row is returned as null (undef). composable_cvtype is the name of the
'composable_cvtypes' cvterm assigned to the cv via cvprop (comma-joined if there are several),
or null if none is assigned.

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
            composable_cvtype => undef,
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

    # A cv's composable type (trait_ontology, method_ontology, ...) is recorded as a cvprop
    # whose type_id is a cvterm in the 'composable_cvtypes' cv.
    my %composable_types_for;   # cv_id => [ cvtype names ]
    my $composable_props = $schema->resultset('Cv::Cvprop')->search(
        { 'me.cv_id' => { -in => \@cv_ids }, 'cv.name' => 'composable_cvtypes' },
        { join => { type => 'cv' }, '+select' => [ 'type.name' ], '+as' => [ 'cvtype_name' ] }
    );
    while (my $prop = $composable_props->next) {
        push @{ $composable_types_for{ $prop->cv_id } }, $prop->get_column('cvtype_name');
    }
    foreach my $cv_id (keys %composable_types_for) {
        next unless $result{$cv_id};
        my %seen;
        $result{$cv_id}->{composable_cvtype} = join(', ', sort grep { !$seen{$_}++ } @{ $composable_types_for{$cv_id} });
    }

    $c->stash->{rest} = { cvs => [ sort { lc($a->{cv_name}) cmp lc($b->{cv_name}) } values %result ] };
}

=head2 get_composable_cvs_of_type

Public Path: /ajax/cv/get_composable_cvs_of_type

GET parameters: composable_cvtype (name of a cvterm in the 'composable_cvtypes' cv)

Returns the cvs assigned that composable cvtype (see CXGN::Onto::get_composable_cvs_of_type):

  { cvs => { cv_id => { cv_name => '...', db_name => '...' }, ... } }

Requires a login.

=cut

sub get_composable_cvs_of_type : Path('/ajax/cv/get_composable_cvs_of_type') : ActionClass('REST') { }

sub get_composable_cvs_of_type_GET {
    my ($self, $c) = @_;

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to view composable cvtypes." };
        return;
    }

    my $composable_cvtype = $c->req->param('composable_cvtype');
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $onto = CXGN::Onto->new({ schema => $schema });

    my $cvs = eval { $onto->get_composable_cvs_of_type($composable_cvtype) };
    if (my $error = $@) {
        chomp $error;
        $c->stash->{rest} = { error => $error };
        return;
    }

    $c->stash->{rest} = { cvs => $cvs };
}

=head2 assign_composable_cvtype

Public Path: /ajax/cv/assign_composable_cvtype

POST parameters: cv_id, composable_cvtype (name of a cvterm in the 'composable_cvtypes' cv)

Assigns the cv to the composable cvtype (see CXGN::Onto::assign_composable_cvtype).
Any other composable cvtype the cv had is removed. For every cvtype except
trait_ontology, any other cv previously assigned that type is unassigned.

Requires curator privileges.

=cut

sub assign_composable_cvtype : Path('/ajax/cv/assign_composable_cvtype') : ActionClass('REST') { }

sub assign_composable_cvtype_POST {
    my ($self, $c) = @_;

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to change composable cvtypes." };
        return;
    }
    if (!$c->user()->check_roles('curator')) {
        $c->stash->{rest} = { error => "You must have curator privileges to change composable cvtypes." };
        return;
    }

    my $cv_id = $c->req->param('cv_id');
    my $composable_cvtype = $c->req->param('composable_cvtype');

    my $sp_person_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $onto = CXGN::Onto->new({ schema => $schema });

    eval { $onto->assign_composable_cvtype($cv_id, $composable_cvtype) };
    if (my $error = $@) {
        chomp $error;
        print STDERR "Error assigning composable cvtype '".($composable_cvtype // '')."' to cv_id ".($cv_id // '').": $error\n";
        $c->stash->{rest} = { error => $error };
        return;
    }

    $c->stash->{rest} = { success => 1, cv_id => $cv_id, composable_cvtype => $composable_cvtype };
}

=head2 unassign_composable_cvtype

Public Path: /ajax/cv/unassign_composable_cvtype

POST parameters: cv_id

Removes the cv's composable cvtype (see CXGN::Onto::unassign_composable_cvtype).

Requires curator privileges.

=cut

sub unassign_composable_cvtype : Path('/ajax/cv/unassign_composable_cvtype') : ActionClass('REST') { }

sub unassign_composable_cvtype_POST {
    my ($self, $c) = @_;

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to change composable cvtypes." };
        return;
    }
    if (!$c->user()->check_roles('curator')) {
        $c->stash->{rest} = { error => "You must have curator privileges to change composable cvtypes." };
        return;
    }

    my $cv_id = $c->req->param('cv_id');

    my $sp_person_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $onto = CXGN::Onto->new({ schema => $schema });

    eval { $onto->unassign_composable_cvtype($cv_id) };
    if (my $error = $@) {
        chomp $error;
        print STDERR "Error unassigning composable cvtype from cv_id ".($cv_id // '').": $error\n";
        $c->stash->{rest} = { error => $error };
        return;
    }

    $c->stash->{rest} = { success => 1, cv_id => $cv_id };
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

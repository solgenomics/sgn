package SGN::Controller::AJAX::Treatment;

use Moose;
use CXGN::Trait::Treatment;

BEGIN {extends 'Catalyst::Controller::REST'};

use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub create_treatment :Path('/ajax/treatment/create') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "You do not have permission to design new treatments.\n"};
        return;
    }

    my $name = $c->req->param('name');
    my $definition = $c->req->param('definition');
    my $format = $c->req->param('format');
    my $default_value = $c->req->param('default_value');
    my $minimum = $c->req->param('minimum');
    my $maximum = $c->req->param('maximum');
    my $categories = $c->req->param('categories');

    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    $name =~ s/_/ /g;
    $name =~ s/\P{Alpha}//g;
    $name = lc($name);

    $definition =~ s/^\s+//;
    $definition =~ s/\s+$//;

    if ($categories) {
        $categories = lc($categories);
        $categories =~ s/^\s+//;
        $categories =~ s/\s+$//;
    }

    if ($default_value) {
        $default_value = lc($default_value);
        $default_value =~ s/^\s+//;
        $default_value =~ s/\s+$//;
    }

    my $error = "";

    if (!$name) {
        $error .= "You must supply a name.\n";
    }
    if (!$definition) {
        $error .= "You must supply a definition.\n";
    }
    if ($definition && $definition !~ m/(\w+ ){4,}/) {
        $error .= "You supplied a definition, but it seems short. Please ensure the definition fully describes the treatment and allows it to be differentiated from other treatments.\n";
    }
    if (!$format || ($format ne "numeric" && $format ne "qualitative")) {
        $error .= "Treatment format must be numeric or qualitative.\n";
    }
    if ($categories && $default_value && $categories !~ m/$default_value/) {
        $error .= "The default value of the treatment is not in the categories list.\n";
    }
    if ($minimum && $maximum && $maximum < $minimum) {
        $error .= "The maximum value cannot be less than the minimum value.\n";
    }

    if ($error) {
        $c->stash->{rest} = {error => $error};
        return;
    }

    my $new_treatment;

    eval {
        if ($format eq "numeric") {
            $new_treatment = CXGN::Trait::Treatment->new({
                bcs_schema => $schema,
                definition => $definition,
                format => $format,
                minimum => $minimum ? $minimum : undef,
                maximum => $maximum ? $maximum : undef,
                default_value => $default_value ? $default_value : undef
            });
        }
    };

    if ($@) {
        $c->stash->{rest} = {error => "An error occurred trying to create treatment: $@"};
    }

    $c->stash->{rest} = {success => 1};
}

1;
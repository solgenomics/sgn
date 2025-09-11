package SGN::Controller::AJAX::Trait;

use Moose;
use CXGN::Trait;

BEGIN {extends 'Catalyst::Controller::REST'};

use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub create_trait :Path('/ajax/trait/create') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "You do not have permission to design new traits.\n"};
        return;
    }

    if (! $c->config->{allow_cvterm_edits}) {
        $c->stash->{rest} = {error => "You do not have permission to design new traits.\n"};
        return;
    }

    my $name = $c->req->param('name') ? $c->req->param('name') : undef;
    my $definition = $c->req->param('definition') ? $c->req->param('definition') : undef;
    my $format = $c->req->param('format') ? $c->req->param('format') : undef;
    my $default_value = $c->req->param('default_value') ? $c->req->param('default_value') : undef;
    my $minimum = $c->req->param('minimum') ? $c->req->param('minimum') : undef;
    my $maximum = $c->req->param('maximum') ? $c->req->param('maximum') : undef;
    my $categories = $c->req->param('categories') ? $c->req->param('categories') : undef;
    my $repeat_type = $c->req->param('repeat_type') ? $c->req->param('repeat_type') : undef;
    my $parent_term = $c->req->param('parent_term') ? $c->req->param('parent_term') : undef;

    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    $name =~ s/_/ /g;
    $name =~ s/[^\p{Alpha} ]//g;
    if ($format ne "ontology") {
        $name = lc($name);
    }

    $definition =~ s/^\s+//;
    $definition =~ s/\s+$//;

    if (defined($categories)) {
        $categories = lc($categories);
        $categories =~ s/^\s+//;
        $categories =~ s/\s+$//;
    }

    if (defined($default_value)) {
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
    if (defined($definition) && $definition !~ m/([^\s]+\s+){6,}/) {
        $error .= "You supplied a definition, but it seems short. Please ensure the definition fully describes the trait and allows it to be differentiated from other traits.\n";
    }
    if (!$format || $format !~ m/numeric|categorical|date|percent|counter|boolean|text|ontology/i) {
        $error .= "Treatment format must be numeric, categorical, date, percent, counter, boolean, text, or ontology.\n";
    }
    if (defined($categories) && defined($default_value) && $categories !~ m/$default_value/) {
        $error .= "The default value of the trait is not in the categories list.\n";
    }
    if (defined($default_value) && $default_value =~ m/[=\/]/) {
        $error .= "The default value you supplied contains special characters.\n";
    }
    if (defined($minimum) && defined($maximum) && $maximum < $minimum) {
        $error .= "The maximum value cannot be less than the minimum value.\n";
    }
    if ($repeat_type && $repeat_type ne 'single' && $repeat_type ne 'multiple' && $repeat_type ne 'time_series') {
        $error .- "Invalid repeat type. Must be single, multiple, or time_series.\n";
    }

    if ($error) {
        $c->stash->{rest} = {error => $error};
        return;
    }

    my $new_trait;

    eval {
        if ($format =~ m/numeric|percent|counter|boolean|/) {
            $new_trait = CXGN::Trait->new({
                bcs_schema => $schema,
                definition => $definition,
                name => $name,
                format => $format
            });
            if (defined($minimum)) {
                $new_trait->minimum($minimum);
            }
            if (defined($maximum)) {
                $new_trait->maximum($maximum);
            }
            if ($repeat_type) {
                $new_trait->repeat_type($repeat_type);
            }
        } elsif ($format eq "categorical") {
            $new_trait = CXGN::Trait->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format,
                categories => $categories ne "" ? $categories : undef,
            });
            if (defined($categories)) {
                $new_trait->categories($categories);
            }
            if ($repeat_type) {
                $new_trait->repeat_type($repeat_type);
            }
        } elsif ($format eq "ontology" || $format eq "date" || $format eq "text") {
            $new_trait = CXGN::Trait->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format
            });
        }

        if (defined($default_value)) {
            $new_trait->default_value($default_value);
        }

        $new_trait->interactive_store($parent_term);
    };

    if ($@) {
        $c->stash->{rest} = {error => "An error occurred trying to create trait: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

sub edit_trait :Path('/ajax/trait/edit') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "You do not have permission to edit cvterms.\n"};
        return;
    }

    if (! $c->config->{allow_cvterm_edits}) {
        $c->stash->{rest} = {error => "You do not have permission to edit cvterms. Check server configuration.\n"};
        return;
    }

    my $cvterm_id = $c->req->param('cvterm_id') ? $c->req->param('cvterm_id') : undef;
    my $new_name = $c->req->param('new_name') ? $c->req->param('new_name') : undef;
    my $new_definition = $c->req->param('new_definition') ? $c->req->param('new_definition') : undef;

    if (!$cvterm_id) {
        $c->stash->{rest} = {error => "Cvterm ID missing.\n"};
        return;
    }

    eval {
        my $trait = CXGN::Trait->new({
            bcs_schema => $schema,
            cvterm_id => $cvterm_id
        });

        if (defined($new_name)) {
            $trait->name($new_name);
        }
        if (defined($new_definition)) {
            $trait->definition($new_definition);
        }

        $trait->interactive_update();
    };

    if ($@) {
        $c->stash->{rest} = {error => "An error occurred updating cvterm: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

sub delete_trait :Path('/ajax/trait/delete') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "You do not have permission to edit cvterms.\n"};
        return;
    }

    if (! $c->config->{allow_cvterm_edits}) {
        $c->stash->{rest} = {error => "You do not have permission to edit cvterms. Check server configuration.\n"};
        return;
    }

    my $cvterm_id = $c->req->param('cvterm_id') ? $c->req->param('cvterm_id') : undef;

    if (!$cvterm_id) {
        $c->stash->{rest} = {error => "Cvterm ID missing.\n"};
        return;
    }

    eval {
        my $trait = CXGN::Trait->new({
            bcs_schema => $schema,
            cvterm_id => $cvterm_id
        });

        $trait->delete();
    };

    if ($@) {
        $c->stash->{rest} = {error => "An error occurred deleting cvterm: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

1;
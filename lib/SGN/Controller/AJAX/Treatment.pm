package SGN::Controller::AJAX::Treatment;

use SGN::I18N ();

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
    my SGN::I18N $ui_create_treatment_i18n = SGN::I18N::translate($c);

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.you_do_not_have_permission_to_design_new_treatments', 'You do not have permission to design new treatments.
'))};
        return;
    }

    my $editable_ontologies_str = $c->config->{allow_trait_edits};
    my @editable_ontologies = split(",", $editable_ontologies_str);

    if (! grep {$_ eq "EXPERIMENT_TREATMENT"} @editable_ontologies) {
        $c->stash->{rest} = {error => (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.you_do_not_have_permission_to_design_new_treatments', 'You do not have permission to design new treatments.
'))};
        return;
    }

    my $name = $c->req->param('name') ? $c->req->param('name') : undef;
    my $definition = $c->req->param('definition') ? $c->req->param('definition') : undef;
    my $format = $c->req->param('format') ? $c->req->param('format') : undef;
    my $default_value = defined($c->req->param('default_value')) ? $c->req->param('default_value') : undef;
    my $minimum = defined($c->req->param('minimum')) ? $c->req->param('minimum') : undef;
    my $maximum = defined($c->req->param('maximum')) ? $c->req->param('maximum') : undef;
    my $categories = $c->req->param('categories') ? $c->req->param('categories') : undef;
    my $category_details = $c->req->param('category_details') ? $c->req->param('category_details') : undef;
    my $repeat_type = $c->req->param('repeat_type') ? $c->req->param('repeat_type') : undef;
    my $parent_terms = $c->req->param('parent_terms') ? $c->req->param('parent_terms') : undef;

    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    $name =~ s/\|//g;

    $definition =~ s/^\s+//;
    $definition =~ s/\s+$//;

    if (defined($categories)) {
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
        $error .= (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.you_must_supply_a_name', 'You must supply a name.
'));
    }
    if (!$definition) {
        $error .= (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.you_must_supply_a_definition', 'You must supply a definition.
'));
    }
    if (defined($definition) && $definition !~ m/([^\s]+\s+){6,}/) {
        $error .= (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.you_supplied_a_definition_but_it_seems_short_please_ensure_the_defin', 'You supplied a definition, but it seems short. Please ensure the definition fully describes the treatment and allows it to be differentiated from other treatments.
'));
    }
    if (!$format || $format !~ m/numeric|categorical|date|percent|counter|boolean|text|ontology/i) {
        $error .= (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.treatment_format_must_be_numeric_categorical_date_percent_counter_bo', 'Treatment format must be numeric, categorical, date, percent, counter, boolean, text, or ontology.
'));
    }
    if (defined($categories) && defined($default_value) && $categories !~ m/$default_value/) {
        $error .= (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.the_default_value_of_the_treatment_is_not_in_the_categories_list', 'The default value of the treatment is not in the categories list.
'));
    }
    if (defined($default_value) && $default_value =~ m/[=\/]/) {
        $error .= (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.the_default_value_you_supplied_contains_special_characters', 'The default value you supplied contains special characters.
'));
    }
    if (defined($minimum) && defined($maximum) && $maximum < $minimum) {
        $error .= (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.the_maximum_value_cannot_be_less_than_the_minimum_value', 'The maximum value cannot be less than the minimum value.
'));
    }
    if (defined($repeat_type) && $repeat_type ne 'single' && $repeat_type ne 'multiple' && $repeat_type ne 'time_series') {
        $error .- "Invalid repeat type. Must be single, multiple, or time_series.\n";
    }

    if ($error) {
        $c->stash->{rest} = {error => $error};
        return;
    }

    my $new_treatment;

    eval {
        if ($format =~ m/numeric|percent|counter|boolean/i) {
            $new_treatment = CXGN::Trait::Treatment->new({
                bcs_schema => $schema,
                definition => $definition,
                name => $name,
                format => $format
            });
            if (defined($minimum)) {
                $new_treatment->minimum($minimum);
            }
            if (defined($maximum)) {
                $new_treatment->maximum($maximum);
            }
            if ($repeat_type) {
                $new_treatment->repeat_type($repeat_type);
            }
        } elsif ($format eq "categorical") {
            $new_treatment = CXGN::Trait::Treatment->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format,
            });
            if ($categories ne "") {
                $new_treatment->categories($categories);
                $new_treatment->category_details($category_details);
            }
            if ($repeat_type) {
                $new_treatment->repeat_type($repeat_type);
            }
        } elsif ($format eq "ontology" || $format eq "date" || $format eq "text") {
            $new_treatment = CXGN::Trait::Treatment->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format
            });
        } 

        if (defined($default_value)) {
            $new_treatment->default_value($default_value);
        }

        $new_treatment->store($parent_terms);
    };

    if ($@) {
        $c->stash->{rest} = {error => (SGN::I18N::translate($ui_create_treatment_i18n, 'transformation.helper.an_error_occurred_trying_to_create_treatment_error_details', 'An error occurred trying to create treatment: %{error_details}', {error_details => ("" . ("$@"))}))};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

1;
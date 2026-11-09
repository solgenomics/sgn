package SGN::Controller::AJAX::Treatment;

use Moose;
use CXGN::Trait::Treatment;
use CXGN::Chado::Cvterm;
use JSON;

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

    my $editable_ontologies_str = $c->config->{allow_trait_edits};
    my @editable_ontologies = split(",", $editable_ontologies_str);

    if (! grep {$_ eq "EXPERIMENT_TREATMENT"} @editable_ontologies) {
        $c->stash->{rest} = {error => "You do not have permission to design new treatments.\n"};
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
    my $synonyms_json = $c->req->param('synonyms') ? $c->req->param('synonyms') : undef;

    my @synonyms;
    if ($synonyms_json) {
        my $decoded_synonyms = eval { decode_json($synonyms_json) };
        if (ref($decoded_synonyms) ne 'ARRAY') {
            $c->stash->{rest} = {error => "The synonyms supplied could not be read.\n"};
            return;
        }
        my %seen_synonyms;
        foreach my $synonym (@{$decoded_synonyms}) {
            next if !defined($synonym);
            $synonym =~ s/\|//g;
            $synonym =~ s/^\s+|\s+$//g;
            next if !$synonym || $seen_synonyms{lc($synonym)}++;
            push @synonyms, $synonym;
        }
    }

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
        $error .= "You must supply a name.\n";
    }
    if (!$definition) {
        $error .= "You must supply a definition.\n";
    }
    if (defined($definition) && length($definition) < 18) {
        $error .= "You supplied a definition, but it seems short. Please ensure the definition fully describes the treatment and allows it to be differentiated from other treatments.\n";
    }
    if (!$format || $format !~ m/numeric|categorical|date|percent|counter|boolean|text|ontology/i) {
        $error .= "Treatment format must be numeric, categorical, date, percent, counter, boolean, text, or ontology.\n";
    }
    if (defined($categories) && defined($default_value) && $default_value ne "" && $categories !~ m/\Q$default_value\E/) {
        $error .= "The default value of the treatment is not in the categories list.\n";
    }
    if (defined($default_value) && $default_value =~ m/[=\/]/) {
        $error .= "The default value you supplied contains special characters.\n";
    }
    if (defined($minimum) && defined($maximum) && $maximum < $minimum) {
        $error .= "The maximum value cannot be less than the minimum value.\n";
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
        $c->stash->{rest} = {error => "An error occurred trying to create treatment: $@"};
        return;
    }

    # synonyms can only be added once the new term has a cvterm_id, so they are stored in a separate transaction.
    # if this fails, the new term is kept and the client is told that only the synonyms could not be stored.
    # synonyms are not used with grouping (ontology) terms, so any supplied with one are ignored.
    if (@synonyms && $format ne 'ontology') {
        my $dbh = $c->dbc->dbh;
        my $synonym_error;

        my $check_sth = $dbh->prepare("SELECT cvtermsynonym_id FROM cvtermsynonym WHERE lower(synonym) = lower(?)");
        my @existing_synonyms;
        foreach my $synonym (@synonyms) {
            $check_sth->execute($synonym);
            my ($existing_id) = $check_sth->fetchrow_array();
            push @existing_synonyms, $synonym if $existing_id;
        }

        if (@existing_synonyms) {
            $synonym_error = "The synonym(s) '" . join("', '", @existing_synonyms) . "' already exist in the database.\n";
        } else {
            eval {
                $dbh->begin_work();
                my $cvterm = CXGN::Chado::Cvterm->new($dbh, $new_treatment->cvterm_id());
                if (!$cvterm) {
                    die "The new treatment could not be found to attach synonyms to.\n";
                }
                foreach my $synonym (@synonyms) {
                    $cvterm->add_synonym($synonym);
                }
                $dbh->commit();
            };
            if ($@) {
                $synonym_error = $@;
                eval { $dbh->rollback(); };
            }
        }

        if ($synonym_error) {
            $c->stash->{rest} = {
                error => "The new treatment '$name' was saved, but its synonyms could not be stored: $synonym_error",
                term_stored => 1
            };
            return;
        }
    }

    $c->stash->{rest} = {success => 1};
}

1;
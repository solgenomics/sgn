package SGN::Controller::AJAX::Trait;

use Moose;
use CXGN::Trait;
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

sub create_trait :Path('/ajax/trait/create') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "You do not have permission to design new traits.\n"};
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
    my $parent_dbs = $c->req->param('parent_dbs') ? $c->req->param('parent_dbs') : undef;
    my $ontology_db_name = $c->req->param('ontology_db_name') ? $c->req->param('ontology_db_name') : undef;

    if (!$ontology_db_name) {
        $c->stash->{rest} = {error => "You must select the trait ontology that the new trait belongs to.\n"};
        return;
    }

    my $editable_ontologies_str = $c->config->{allow_trait_edits};
    my @editable_ontologies = split(",", $editable_ontologies_str);
    my @parent_dbs = split(",", $parent_dbs);
    foreach my $parent_db (@parent_dbs) { # ALL of the parent DBs need to be editable, or traits need to be editable in general
        if (! ($editable_ontologies_str == 1 || (grep {$parent_db eq $_} @editable_ontologies))) {
            $c->stash->{rest} = {error => "Ontology $parent_db is not editable on this server - contact a system administrator.\n"};
            return;
        }
    }

    # the ontology the new term is stored in must be editable in its own right, since the parent dbs are supplied by the client
    if (! ($editable_ontologies_str == 1 || (grep {$ontology_db_name eq $_} @editable_ontologies))) {
        $c->stash->{rest} = {error => "Ontology $ontology_db_name is not editable on this server - contact a system administrator.\n"};
        return;
    }

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
    if (defined($categories) && defined($default_value) && $default_value ne "" && $categories !~ m/\Q$default_value\E/) {
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
        if ($format =~ m/numeric|percent|counter|boolean/i) {
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
                format => $format
            });
            if (defined($categories)) {
                $new_trait->categories($categories);
                $new_trait->category_details($category_details);
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

        $new_trait->interactive_store($parent_terms, $ontology_db_name);
    };

    if ($@) {
        $c->stash->{rest} = {error => "An error occurred trying to create trait: $@"};
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
                my $cvterm = CXGN::Chado::Cvterm->new($dbh, $new_trait->cvterm_id());
                if (!$cvterm) {
                    die "The new trait could not be found to attach synonyms to.\n";
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
                error => "The new trait '$name' was saved, but its synonyms could not be stored: $synonym_error",
                term_stored => 1
            };
            return;
        }
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

    my $cvterm_id = $c->req->param('cvterm_id') ? $c->req->param('cvterm_id') : undef;
    my $new_name = $c->req->param('new_name') ? $c->req->param('new_name') : undef;
    my $new_definition = $c->req->param('new_definition') ? $c->req->param('new_definition') : undef;
    my $trait;
    if (!$cvterm_id) {
        $c->stash->{rest} = {error => "Cvterm ID missing.\n"};
        return;
    }

    eval {
        $trait = CXGN::Trait->new({
            bcs_schema => $schema,
            cvterm_id => $cvterm_id
        });
    };
    if ($@) {
        $c->stash->{rest} = {error => "An error occurred retrieving cvterm information: $@\n"};
        return;
    }

    my $editable_ontologies_str = $c->config->{allow_trait_edits};
    my @editable_ontologies = split(",", $editable_ontologies_str);

    if (! ($editable_ontologies_str == 1 || (grep {$_ eq $trait->db()} @editable_ontologies ) ) ) {
        $c->stash->{rest} = {error => "You do not have permission to edit traits.\n"};
        return;
    }

    eval {
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

    my $cvterm_id = $c->req->param('cvterm_id') ? $c->req->param('cvterm_id') : undef;

    if (!$cvterm_id) {
        $c->stash->{rest} = {error => "Cvterm ID missing.\n"};
        return;
    }

    my $editable_ontologies_str = $c->config->{allow_trait_edits};
    my @editable_ontologies = split(",", $editable_ontologies_str);

    my $trait = CXGN::Trait->new({
        bcs_schema => $schema,
        cvterm_id => $cvterm_id
    });

    if (! ($editable_ontologies_str == 1 || (grep {$_ eq $trait->db()} @editable_ontologies ) ) ) {
        $c->stash->{rest} = {error => "You do not have permission to delete traits.\n"};
        return;
    }

    eval {

        $trait->delete();
    };

    if ($@) {
        $c->stash->{rest} = {error => "An error occurred deleting cvterm: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

1;
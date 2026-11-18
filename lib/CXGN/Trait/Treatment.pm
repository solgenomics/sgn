=head1 NAME

CXGN::Trait::Treatment - an instance of CXGN::Trait that always uses the experiment_treatment_ontology's db.name

=head1 DESCRIPTION

This module contains functions for creating and storing experimental treatments that can be created by curators.
Treatments are stored and applied in the same way as phenotypes, though with a different ontology. The only
differences between traits and treatments in their implementation is that treatments are always part of the
experiment_treatment_ontology, whose db.name (e.g. EXPERIMENT_TREATMENT) is looked up from the database. All other behavior is essentially the same, 
though this module contains functions for the creation of treatments that are not available to traits. 

=head1 SYNOPSIS

my $treatment = CXGN::Trait::Treatment->new({
    bcs_schema => $schema,
    definition => $definition,
    name => $name,
    format => $format
});

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

package CXGN::Trait::Treatment;

use Moose;
use Data::Dumper;
use List::Util qw(max);
use CXGN::List::Transform;
use CXGN::Onto;
use JSON;

BEGIN {extends 'CXGN::Trait'};

sub BUILD {
    my $self = shift;
    my $schema = $self->bcs_schema();

    # Derive the db name (name space) of the cv tagged as the treatment ontology:
    # cvterm (cv type name) -> cvprop.type_id -> cvprop.cv_id -> cvterm -> dbxref -> db
    my @cvprop_type_ids = map { $_->cvterm_id() } $schema->resultset("Cv::Cvterm")->search({
        name => 'experiment_treatment_ontology'
    })->all();

    my $cvprop_rs = $schema->resultset("Cv::Cvprop")->search({
        type_id => { -in => \@cvprop_type_ids }
    });

    my @db_names;
    my %seen_db_name;
    while (my $cvprop = $cvprop_rs->next()) {
        my $cvterm = $schema->resultset("Cv::Cvterm")->search(
            { cv_id => $cvprop->cv_id() },
            { order_by => 'cvterm_id' }
        )->first();
        next if !$cvterm;

        my $dbxref = $schema->resultset("General::Dbxref")->find({ dbxref_id => $cvterm->dbxref_id() });
        next if !$dbxref;

        my $db = $schema->resultset("General::Db")->find({ db_id => $dbxref->db_id() });
        next if !$db;

        push @db_names, $db->name() if !$seen_db_name{$db->name()}++;
    }

    if (!@db_names) {
        die "No experiment_treatment_ontology could be found in the database. Has the DB patch been run?\n";
    }
    if (@db_names > 1) {
        die "More than one experiment_treatment_ontology found in the database (" . join(", ", @db_names) . ").\n";
    }

    $self->db($db_names[0]);
}

sub store {
    my $self = shift;
    my $parent_terms_json = shift;

    my $schema = $self->bcs_schema();
    my $db_name = $self->db();

    # find the root node of the treatment ontology the new term is being added to
    my $ontology_obj = CXGN::Onto->new({
        schema => $schema
    });
    my @root_nodes = $ontology_obj->get_root_nodes('experiment_treatment_ontology'); # each entry is [ cv_id, "DB:accession Term name" ]

    my ($root_node) = grep { $_->[1] =~ m/^\Q$db_name\E:/ } @root_nodes;

    if (!$root_node) {
        die "No treatment ontology named $db_name could be found in the database.\n";
    }

    my $treatment_cv_id = $root_node->[0];
    my $treatment_ontology = $schema->resultset("Cv::Cv")->find({
        cv_id => $treatment_cv_id
    })->name();

    my $name = $self->name() || die "No name found.\n";

    my $existing_cvterm = $schema->resultset("Cv::Cvterm")->search({ cv_id => $treatment_cv_id })->search(\[ 'lower(me.name) = lower(?)', $name ])->first();
    if ($existing_cvterm) {
        die "Another term in this ontology already has the name '" . $existing_cvterm->name() . "' (names are compared case-insensitively). Please choose a different name.\n";
    }

    my @parent_ids;

    my $parent_terms = [];
    if ($parent_terms_json) {
        $parent_terms = decode_json($parent_terms_json);
    }

    if (@$parent_terms) {
        my $lt = CXGN::List::Transform->new();
        my $transform = $lt->transform($schema, "traits_2_trait_ids", $parent_terms);

        if (@{$transform->{missing}} > 0) {
            die "Parent term(s) " . join(", ", @{$transform->{missing}}) . " could not be found in the database.\n";
        }

        @parent_ids = @{$transform->{transform}};
    } else { # default to the root term of the treatment ontology
        my $root_term_name = $root_node->[1] =~ s/\w+:\d+ //r;

        push @parent_ids, $schema->resultset("Cv::Cvterm")->find({
            name => $root_term_name,
            cv_id => $treatment_cv_id
        })->cvterm_id();
    }

    my $definition = $self->definition() || die "No definition found.\n";
    my $format = $self->format() || die "No format found.\n";
    my $default_value = $self->default_value() ne "" ? $self->default_value() : undef;
    my $minimum = $self->minimum() ne "" ? $self->minimum() : undef;
    my $maximum = $self->maximum() ne "" ? $self->maximum() : undef;
    my $categories = $self->categories() ne "" ? $self->categories() : undef;
    my $repeat_type = $self->repeat_type() ne "" ? $self->repeat_type() : undef;
    my $category_details = $self->category_details() ne "" ? $self->category_details() : undef;

    my $trait_property_cv_id = $schema->resultset("Cv::Cv")->find({name => 'trait_property'})->cv_id();

    my $minimum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_minimum'
    })->cvterm_id();

    my $maximum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_maximum'
    })->cvterm_id();

    my $format_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_format'
    })->cvterm_id();

    my $default_value_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_default_value'
    })->cvterm_id();

    my $categories_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_categories'
    })->cvterm_id();

    my $repeat_type_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_repeat_type'
    })->cvterm_id();

    my $category_details_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_details'
    })->cvterm_id();

    my %cvtermprop_hash = (
        "$format_cvterm_id" => $format,
        "$default_value_cvterm_id" => $default_value,
        "$minimum_cvterm_id" => $minimum,
        "$maximum_cvterm_id" => $maximum,
        "$categories_cvterm_id" => $categories,
        "$repeat_type_cvterm_id" => $repeat_type,
        "$category_details_cvterm_id" => $category_details
    );

    my $get_db_accessions_sql = "SELECT accession FROM dbxref JOIN db USING (db_id) WHERE db.name=?;";

    my $relationship_cv = $schema->resultset("Cv::Cv")->find({ name => 'relationship'});
    my $rel_cv_id;
    if ($relationship_cv) {
        $rel_cv_id = $relationship_cv->cv_id ;
    } else {
        die "No relationship ontology in DB.\n";
    }
    my $variable_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'VARIABLE_OF' , cv_id => $rel_cv_id });
    my $variable_of_id;
    if ($variable_relationship) {
        $variable_of_id = $variable_relationship->cvterm_id();
    }
    my $isa_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'is_a' , cv_id => $rel_cv_id });
    my $isa_id;
    if ($isa_relationship) {
        $isa_id = $isa_relationship->cvterm_id();
    }

    my $h = $schema->storage->dbh->prepare($get_db_accessions_sql);
    $h->execute($db_name);

    my @accessions;

    while (my $accession = $h->fetchrow_array()) {
        push @accessions, int($accession =~ s/^0+//r);
    }

    my $accession_num = max(@accessions) + 1;
    my $zeroes = "0" x (7-length($accession_num));

    my $new_treatment_id;
    my $new_treatment;

    my $coderef = sub {
        eval {
            $new_treatment_id = $schema->resultset("Cv::Cvterm")->create_with({
                name => $name,
                cv => $treatment_ontology,
                db => $db_name,
                dbxref => "$zeroes"."$accession_num"
            })->cvterm_id();

            foreach my $pid (@parent_ids) {
                if ($format eq "ontology") {
                    $schema->resultset("Cv::CvtermRelationship")->find_or_create({
                        object_id => $pid,
                        subject_id => $new_treatment_id,
                        type_id => $isa_id
                    });
                } else {
                    $schema->resultset("Cv::CvtermRelationship")->find_or_create({
                        object_id => $pid,
                        subject_id => $new_treatment_id,
                        type_id => $variable_of_id
                    });
                }
            }

            $new_treatment = $schema->resultset("Cv::Cvterm")->find({
                cv_id => $treatment_cv_id,
                cvterm_id => $new_treatment_id,
                name => $name
            });
            $new_treatment->definition($definition);
            $new_treatment->update();

            foreach my $cvtermprop (keys(%cvtermprop_hash)) {
                if (defined($cvtermprop_hash{$cvtermprop})) {
                    $schema->resultset("Cv::Cvtermprop")->find_or_create({
                        cvterm_id => $new_treatment_id,
                        type_id => $cvtermprop,
                        value => $cvtermprop_hash{$cvtermprop},
                        rank => 0
                    });
                }
            }
        };
        if ($@) {
            $schema->txn_rollback();
            die "An error occurred! $@";
        } else {
            $schema->txn_commit();
        }
    };

    eval {
        $schema->txn_do($coderef);
    };
    if ($@) {
        die "An error occurred saving treatment: $@\n";
    }
    
    $self->cvterm($new_treatment);
    $self->cvterm_id($new_treatment_id);
    $self->dbxref_id($new_treatment->dbxref_id);

    return $new_treatment;
}

1;
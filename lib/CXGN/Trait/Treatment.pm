=head1 NAME

CXGN::Trait::Treatment - an instance of CXGN::Trait that always uses EXPERIMENT_TREATMENT for ontology db.name

=head1 DESCRIPTION

This module contains functions for creating and storing experimental treatments that can be created by curators.
Treatments are stored and applied in the same way as phenotypes, though with a different ontology. The only
differences between traits and treatments in their implementation is that treatments are always part of the
experiment_treatment_ontology, with db.name EXPERIMENT_TREATMENT. All other behavior is essentially the same, 
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
use JSON;

BEGIN {extends 'CXGN::Trait'};

sub BUILD {
    my $self = shift;
    $self->db('EXPERIMENT_TREATMENT');
}

sub store {
    my $self = shift;
    my $parent_term = shift;

    my $schema = $self->bcs_schema();
    
    my $lt = CXGN::List::Transform->new();
    
    my $transform = $lt->transform($schema, "traits_2_trait_ids", [$parent_term]);

    if (@{$transform->{missing}}>0) { 
	    die "Parent term $parent_term could not be found in the database.\n";
    }

    my @parent_id_list = @{$transform->{transform}};
    my $parent_id = $parent_id_list[0];

    my $name = $self->name() || die "No name found.\n";
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

    my $get_db_accessions_sql = "SELECT accession FROM dbxref JOIN db USING (db_id) WHERE db.name='EXPERIMENT_TREATMENT';";

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

    my $experiment_treatment_cv = $schema->resultset("Cv::Cv")->find({ name => 'experiment_treatment'});
    my $experiment_treatment_cv_id;
    if ($experiment_treatment_cv) {
        $experiment_treatment_cv_id = $experiment_treatment_cv->cv_id ;
    } else {
        die "No experiment_treatment CV found. Has DB patch been run?\n";
    }

    my $h = $schema->storage->dbh->prepare($get_db_accessions_sql);
    $h->execute();

    my @accessions;

    while (my $accession = $h->fetchrow_array()) {
        push @accessions, int($accession =~ s/^0+//r);
    }

    my $accession_num = max(@accessions) + 1;
    my $zeroes = "0" x (7-length($accession_num));

    my $new_treatment_id;
    my $new_treatment;

    my $coderef = sub {
        $new_treatment_id = $schema->resultset("Cv::Cvterm")->create_with({
            name => $name,
            cv => 'experiment_treatment',
            db => 'EXPERIMENT_TREATMENT',
            dbxref => "$zeroes"."$accession_num"
        })->cvterm_id();

        if ($format eq "ontology") {
            $schema->resultset("Cv::CvtermRelationship")->find_or_create({
                object_id => $parent_id,
                subject_id => $new_treatment_id,
                type_id => $isa_id
            });
        } else {
            $schema->resultset("Cv::CvtermRelationship")->find_or_create({
                object_id => $parent_id,
                subject_id => $new_treatment_id,
                type_id => $variable_of_id
            });
        }

        $new_treatment = $schema->resultset("Cv::Cvterm")->find({
            cv_id => $experiment_treatment_cv_id,
            cvterm_id => $new_treatment_id,
            name => $name
        });
        $new_treatment->definition($definition);
        $new_treatment->update();

        foreach my $cvtermprop (keys(%cvtermprop_hash)) {
            if (defined($cvtermprop_hash{$cvtermprop})) {
                $schema->resultset("Cv::Cvtermprop")->create({
                    cvterm_id => $new_treatment_id,
                    type_id => $cvtermprop,
                    value => $cvtermprop_hash{$cvtermprop},
                    rank => 0
                });
            }
        }
    };

    $schema->txn_do($coderef);

    $self->cvterm_id($new_treatment_id);
    $self->dbxref_id($new_treatment->dbxref_id);

    return $new_treatment;
}

1;
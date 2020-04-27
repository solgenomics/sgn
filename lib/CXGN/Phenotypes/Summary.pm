package CXGN::Phenotypes::Summary;

=head1 NAME

CXGN::Phenotypes::Summary - an object to handle searching an accession's phenotypes across database.

=head1 SYNOPSIS

returns summary statistics by accession. returns the performace of an accession across all recorded observations for a trait (whether plot, plant, or subplot).
you can provide an arrayref of trial_ids, accession_ids, or trait_ids to filter down the search results.

my $summary_obj = CXGN::Phenotypes::Summary->new({
    bcs_schema => $schema,
    trial_list => [1,2,3],
    accession_list => [10,11,12],
    trait_list => [90]
});
my $summary_info = $summary_obj->search();

$summary_info is an arrayref of arrayref where each entry is:
[trait_name, trait_id, num_phenotypes_count, phenotypes_average, phenotypes_max, phenotypes_min, phenotypes_stddev, accession_name, accession_id]

trial_list, accession_list, and trait_list are optional, so you can do something like this to get the performace of a single accession for all traits:

my $summary_obj = CXGN::Phenotypes::Summary->new({
    bcs_schema => $schema,
    accession_list => [10]
});
my $summary_info = $summary_obj->search();

=head1 AUTHORS

nm529

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'trait_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema;
    print STDERR "Phenotype Summary Search ".localtime()."\n";

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $subplot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_of', 'stock_relationship')->cvterm_id();

    my @rel_types = ($plot_of_type_id, $plant_of_type_id, $subplot_type_id);
    my @stock_types = ($plot_type_id, $plant_type_id, $subplot_type_id);

    my $rel_type_sql = join ("," , @rel_types);
    my $rel_type_where = " AND stock_relationship.type_id IN ($rel_type_sql) ";
    my $stock_type_sql = join ("," , @stock_types);
    my $stock_type_where = " AND plot.type_id IN ($stock_type_sql) ";

    my $additional_trial_where = '';
    if ($self->trial_list){
        my $trial_ids = $self->trial_list;
        if (scalar(@$trial_ids)>0){
            my $sql = join ("," , @$trial_ids);
            $additional_trial_where = " AND project_id IN ($sql) ";
        }
    }
    my $additional_accession_where = '';
    if ($self->accession_list){
        my $accession_ids = $self->accession_list;
        if (scalar(@$accession_ids)>0){
            my $sql = join ("," , @$accession_ids);
            $additional_accession_where = " AND accession.stock_id IN ($sql) ";
        }
    }
    my $additional_trait_where = '';
    if ($self->trait_list){
        my $trait_ids = $self->trait_list;
        if (scalar(@$trait_ids)>0){
            my $sql = join ("," , @$trait_ids);
            $additional_trait_where = " AND cvterm.cvterm_id IN ($sql) ";
        }
    }

    my $h = $schema->storage->dbh->prepare("SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
        cvterm.cvterm_id,
        count(phenotype.value),
        to_char(avg(phenotype.value::real), 'FM999990.990'),
        to_char(max(phenotype.value::real), 'FM999990.990'),
        to_char(min(phenotype.value::real), 'FM999990.990'),
        to_char(stddev(phenotype.value::real), 'FM999990.990'),
        accession.uniquename,
        accession.stock_id
        FROM cvterm
            JOIN phenotype ON (cvterm_id=cvalue_id)
            JOIN nd_experiment_phenotype USING(phenotype_id)
            JOIN nd_experiment_project USING(nd_experiment_id)
            JOIN nd_experiment_stock USING(nd_experiment_id)
            JOIN stock as plot USING(stock_id)
            JOIN stock_relationship on (plot.stock_id = stock_relationship.subject_id)
            JOIN stock as accession on (accession.stock_id = stock_relationship.object_id)
            JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id
        WHERE phenotype.value~?
            $rel_type_where
            $stock_type_where
            AND accession.type_id=?
            $additional_trial_where
            $additional_accession_where
            $additional_trait_where
        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id, accession.stock_id, accession.uniquename
        ORDER BY cvterm.name ASC;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($numeric_regex, $accession_type_id);

    my @phenotype_data;
    while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev, $stock_name, $stock_id) = $h->fetchrow_array()) {
        push @phenotype_data, [$trait, $trait_id, $count, $average, $max, $min, $stddev, $stock_name, $stock_id];
    }
    print STDERR "Phenotype Summary Search End ".localtime()."\n";
    return \@phenotype_data;
}

1;

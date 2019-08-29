package CXGN::Phenotypes::Exact;

=head1 NAME

CXGN::Phenotypes::Exact - an object to retrieve the exact phenotypes and plot/plant names for a given trial id

=head1 SYNOPSIS

my $exact_obj = CXGN::Phenotypes::Exact->new({
    bcs_schema => $schema,
    trial_id => 1
});
my $exact_phenotypes = $exact_obj->search();

$exact_phenotypes is a hashref of hashrefs, where each phenotyped_trait is a key whose value is another hash where each plot_name is a key and trait value is the value

=head1 AUTHORS

bje24

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

has 'trial_id' => (
	isa => 'Int',
	is => 'rw',
    required => 1,
);

has 'data_level' => (
    is => 'ro',
    isa => 'Str',
    default => 'plot',
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_id = $self->trial_id;
    my $data_level = $self->data_level;

    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $data_level, 'stock_type')->cvterm_id();

    my $h = $schema->storage->dbh->prepare("SELECT stock.name, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait, phenotype.value
        FROM project
        JOIN nd_experiment_project USING(project_id)
        JOIN nd_experiment_stock AS all_stocks ON(nd_experiment_project.nd_experiment_id = all_stocks.nd_experiment_id)
        JOIN stock USING(stock_id)
        JOIN nd_experiment_stock AS my_stocks ON(stock.stock_id = my_stocks.stock_id)
        JOIN nd_experiment_phenotype ON(my_stocks.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id)
        JOIN phenotype USING(phenotype_id)
        JOIN cvterm ON(phenotype.cvalue_id = cvterm.cvterm_id)
        JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id
        WHERE project_id = ? AND stock.type_id = ?
        GROUP BY 1,2,3;");

    $h->execute($trial_id, $stock_type_id);

    my %exact_phenotypes;
    while (my ($stock, $synonym, $value) = $h->fetchrow_array()) {
        $exact_phenotypes{$synonym}{$stock} = $value;
    }

    return \%exact_phenotypes;
}

1;

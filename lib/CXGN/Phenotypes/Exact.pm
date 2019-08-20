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

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_id = $self->trial_id;

    my $h = $schema->storage->dbh->prepare("
        SELECT stock.name, synonym, phenotype.value
        FROM project
        JOIN nd_experiment_project using(project_id)
        JOIN nd_experiment_stock on(nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock using(stock_id)
        JOIN nd_experiment_phenotype on (nd_experiment_stock.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id)
        JOIN phenotype using(phenotype_id)
        JOIN cvterm ON (phenotype.cvalue_id = cvterm.cvterm_id)
        JOIN cvtermsynonym using(cvterm_id)
        WHERE project_id = ? AND synonym NOT LIKE '% %' AND synonym NOT LIKE '\%_%';"
    );

    $h->execute($trial_id);

    my %exact_phenotypes;
    while (my ($stock, $synonym, $value) = $h->fetchrow_array()) {
        $exact_phenotypes{$synonym}{$stock} = $value;
    }

    return \%exact_phenotypes;
}

1;

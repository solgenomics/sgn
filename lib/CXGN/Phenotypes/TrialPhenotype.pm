
package CXGN::Phenotypes::TrialPhenotype;


=head1 NAME

CXGN::Phenotypes::TrialPhenotype - an object to handle retrieving of trial phenotype and field information.

=head1 USAGE

my $phenotypes_heatmap = CXGN::Phenotypes::TrialPhenotype->new(
	bcs_schema=>$schema,
	trial_id=>$trial_id
);
my @phenotype = $phenotypes_heatmap->get_trial_phenotypes_heatmap();

=head1 DESCRIPTION


=head1 AUTHORS


=cut



use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Phenotypes::SearchFactory;

BEGIN { extends 'Catalyst::Controller'; }

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'trial_id' => (
	isa => 'Int',
	is => 'rw',
    required => 1,
);


sub get_trial_phenotypes_heatmap {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_id = $self->trial_id;
    
    return ;
}
    

1;
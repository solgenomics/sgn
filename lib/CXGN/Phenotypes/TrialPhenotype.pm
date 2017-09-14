
package CXGN::Phenotypes::TrialPhenotype;

use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Phenotypes::SearchFactory;

BEGIN { extends 'Catalyst::Controller'; }




sub trial_phenotypes_heatmap {
    my $self = shift;
    
    return ;
}
    

1;
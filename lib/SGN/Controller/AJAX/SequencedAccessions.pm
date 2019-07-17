
package SGN::Controller::AJAX::SequencedAccessions;

use Moose;
use CXGN::Stock;

BEGIN { extends 'Catalyst::Controller::REST' };


sub get_all_sequenced_stocks :Path('/ajax/sequenced_accessions_datatable') Args(0) {
    my $self = shift;
    my $c = shift;

    my @sequenced_stocks = CXGN::Stock::all_sequenced_stocks($c->dbic_schema("Bio::Chado::Schema"));
    
}






1;


package SGN::Controller::AJAX::SequencedAccessions;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

sub get_all_sequenced_stocks :Path('/ajax/genomes/sequenced_stocks') :Args(0) {
    my $self = shift;
    my $c = shift;

    my @sequenced_stocks = CXGN::Stock::all_sequenced_stocks($c->dbic->schema("Bio::Chado::Schema"));

    # this call is designed to work with data tables.

    my $html = "";
    foreach my $sq (@sequenced_stocks) {

	my $info = $sq->get_sequencing_project_info();
	
	my $html .= "<tr><td>".join(
	    "</td><td>",
	    "<a href=\"/stock/".$sq->stock_id()."\">".$sq->uniquename."</a>",
	    

    }

    


}







1;

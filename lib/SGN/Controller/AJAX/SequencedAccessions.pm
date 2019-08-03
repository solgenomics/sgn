
package SGN::Controller::AJAX::SequencedAccessions;

use Moose;

use Data::Dumper;
use CXGN::Stock::SequencingInfo;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


BEGIN { extends 'Catalyst::Controller::REST' };

sub get_all_sequenced_stocks :Path('/ajax/genomes/sequenced_stocks') {
    my $self = shift;
    my $c = shift;
    
    my @sequenced_stocks = CXGN::Stock->all_sequenced_stocks($c->dbic_schema("Bio::Chado::Schema"));
    
    my @info = $self->retrieve_sequencing_infos(@sequenced_stocks);

    # this call is designed to work with data tables.
    
    #$c->stash->{rest} = { data => [[ 'a', 'b','c','d','y', 'k'], ['d', 'e','f','g','x', 'f'], ['g', 'h','i', 'z','w', 'z'], ['g', 'h','i', 'x', 'u', 'w']]};
    
    $c->stash->{rest} = { data => \@info };
}
    
sub get_sequencing_info_for_stock :Path('/ajax/genomes/sequenced_stocks') Args(1) {
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    my $stock = CXGN::Stock->new( { schema => $c->dbic_schema("Bio::Chado::Schema"), stock_id => $stock_id });

    my @info = $self->retrieve_sequencing_infos($stock);
    
    $c->stash->{rest} = { data => \@info };
}

sub retrieve_sequencing_infos {
    my $self = shift;
    my @stocks = @_;
    
    my @data = ();
    
    foreach my $s (@stocks) {
	my $info = $s->get_sequencing_project_infos();

	if ($info) { 
	    push @data, [
		"<a href=\"/stock/".$s->stock_id()."\">".$s->uniquename()."</a>",
		$info->{year},
		$info->{organization},
		$info->{website},
		'<a href="">BLAST</a> <a href="">Jbrowse</a>',
		'<a href="">Edit</a> <a href="">Delete</a>'
	    ];
	}
    }

    print STDERR "Data: ".Dumper(\@data);
    return @data;
}

sub store_sequencing_info :Path('/ajax/genomes/store_sequencing_info') Args(0) {
    my $self =shift;
    my $c = shift;

    my $params = $c->req->params();

    print STDERR "store_sequecing_info PARAMS = ".Dumper($params);
    
    my $stockprop_id = $params->{stockprop_id}; # if available, then we update
    my $stock_id = $params->{stock_id};
    
    my $si = CXGN::Stock::SequencingInfo->new();

    $si->from_hash($params);
    
    if ($stockprop_id) {
	$si->stockprop_id($stockprop_id);
    }
    
    my $json = $si->to_json();

    if ($stock_id=~/^\d+$/) { 
	my $s = CXGN::Stock->new({ schema => $c->dbic_schema("Bio::Chado::Schema"), stock_id => $stock_id });
    
	$s->store_sequencing_info($si, $stockprop_id);
    }
    else { die "Need a stock_id!\n"; }
    
    

    
}

1;

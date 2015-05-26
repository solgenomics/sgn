
package SGN::Controller::AJAX::Search::Stock;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub stock_search :Path('/ajax/search/stocks') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $params = $c->req->params() || {};

    my %query;

     #             d.stock_type
     #             d.organism  
     #             d.person    
     #             d.trait     
     #             d.project   
     #             d.location  
     #             d.year      
     #             d.organization

    my $matchtype = $params->{any_name_matchtype};
    my $any_name  = $params->{any_name};

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    my ($or_conditions, $and_conditions);
    if (exists($params->{any_name} ) && $params->{any_name} ) {
	my $start = '%';
	my $end = '%';
	if ( $matchtype eq 'exactly' ) {
	    $start = '';
	    $end = '';
	} elsif ( $matchtype eq 'starts_with' ) {
	    $start = '';
	} elsif ( $matchtype eq 'ends_with' ) {
	    $end = '';
	}

	$or_conditions = [ 
	    { name          => {'ilike', $start.$params->{any_name}.$end} },  
	    { uniquename    => {'ilike', $start.$params->{any_name}.$end} },  
	    { description   => {'ilike', $start.$params->{any_name}.$end} } 
	    ] ; 
    } else { 
	$or_conditions = [ { uniquename => { '!=', undef } } ];
    }
    
    
    ###############
    if (exists($params->{organism} ) && $params->{organism} ) {
	$and_conditions->{organism_id} = $params->{organism} ;
	
    }

    
###############

    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my $rows = $params->{length} || 10;
    my $start = $params->{start};

    my $page = int($start / $rows)+1;


    # get the count first
    my $rs = $schema->resultset("Stock::Stock")->search( 
	{
	    -and => [
		 $or_conditions,
		 $and_conditions
		],
	},
	);

    my $records_total = $rs->count();
    
    #
    my $rs2 = $schema->resultset("Stock::Stock")->search(   
	{
	    -and => [
		 $or_conditions,
		 $and_conditions  
		],
	} ,
	{ 
	    page => $page, 
	    rows => $rows, 
	    order_by => "name" 
	} 
	);
	

    my @result;
    while (my $a     = $rs2->next()) { 
	my $uniquename = $a->uniquename;
	my $type     = $a->type_id ;
	my $organism = $a->organism_id;
	my $stock_id = $a->stock_id;
	push @result, [  "<a href=\"/stock/$stock_id/view\">$uniquename</a>", $type, $organism ];
    }

    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
    
    
}

1;

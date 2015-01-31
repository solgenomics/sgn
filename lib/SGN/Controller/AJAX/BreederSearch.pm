
package SGN::Controller::AJAX::BreederSearch;

use Moose;

use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );

sub get_data : Path('/ajax/breeder/search') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $criteria_list;
    my @selects = qw | select1 select2 select3 |;
    foreach my $s (@selects) { 
	my $value = $c->req->param($s);
	if ($value) { 
	    push @$criteria_list, $c->req->param($s);
	}
    }
    my $output = $c->req->param('select4') || 'plots';

    my $dataref = {};
    
    my @params = qw | c1_data c2_data c3_data |;
    my $data_tainted = 0;

    if (!$criteria_list) {
	$c->stash->{rest} = { };
	return;
    }
    for (my $i=0; $i<scalar(@$criteria_list); $i++) { 
	my $data;
	print STDERR "PARAM: $params[$i]\n";
	if (defined($params[$i]) && ($params[$i] ne '')) { $data =  $c->req->param($params[$i]); }
	if (defined($data) && ($data ne '') && ($data !~ /^[\d,\/ ]+$/g)) { 
	    print STDERR "Illegal chars in '$data'\n"; 
	    $data_tainted =1;
	}
	# items need to be quoted in sql
	#
	print STDERR "DATA: $data\n";
	if ($data) { 
	    my $qdata = join ",", (map { "\'$_\'"; } (split ",", $data));
	    $dataref->{$criteria_list->[-1]}->{$criteria_list->[$i]} = $qdata;
	}
    }
    
    if ($data_tainted) { 
	$c->stash->{rest} =  { error => "Illegal data.", };
	return;
    }
    
    my $stocks = undef;
    my $error = "";

     foreach my $select (@$criteria_list) { 
     	print STDERR "Checking $select\n";
     	chomp($select);
     	if (! any { $select eq $_ } ('accessions', 'projects', 'locations', 'years', 'traits', 'genotypes', undef)) { 
     	    $error = "Valid keys are projects, years, traits and locations";
     	    $c->stash->{rest} = { error => $error };
     	    return;
     	}
     }
     my $dbh = $c->dbc->dbh();

     my $item = $criteria_list->[-1];

     my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );
    
     my $results_ref = $bs->get_intersect($criteria_list, $dataref, $c->config->{trait_ontology_db_name}); 

    my $stock_ref = [];
    my $stockdataref->{$output} = $dataref->{$criteria_list->[-1]};

    push @$criteria_list, $output;
    print STDERR "OUTPUT: $output CRITERIA: ", Data::Dumper::Dumper($criteria_list);
    $stock_ref = $bs->get_intersect($criteria_list, $stockdataref, $c->config->{trait_ontology_db_name});
    
    print STDERR "RESULTS: ".Data::Dumper::Dumper($results_ref);

    if ($stock_ref->{message}) { 
	$c->stash->{rest} = { 
	    list => $results_ref->{results},
	    message => $stock_ref->{message},
	};
    }
    else { 
	
	$c->stash->{rest} = { 
	    list => $results_ref->{results},
	    stocks => $stock_ref->{results},
	};
    }
}
    

1;


    

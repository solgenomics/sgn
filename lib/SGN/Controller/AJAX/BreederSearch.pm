
package SGN::Controller::AJAX::BreederSearch;

use Moose;
use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST' }


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
	push @$criteria_list, $c->req->param($s);
    }

    my $dataref = {};
    
    my @params = qw | c1_data c2_data c3_data |;
    my $data_tainted = 0;

    for (my $i=0; $i<scalar(@$criteria_list); $i++) { 
	my $data =  $c->req->params($params[$i]);
	if ($data !~ /^[\d,]+$/g && defined($data)) { 
	    print STDERR "Illegal chars in $data\n";
	    $data_tainted =1;
	}
	# items need to be quoted in sql
	#
	my $qdata = join ",", (map { "\'$_\'"; } (split ",", $data));

	$dataref->{$criteria_list->[-1]}->{$criteria_list->[$i]} = $qdata;
    }

    if ($data_tainted) { 
	$c->stash->{error} = "Illegal data.";
	return;
    }

    my $stocks = undef;
    my $error = "";

    foreach my $select (@$criteria_list) { 
	print STDERR "Checking $select\n";
	chomp($select);
	if (! any { $select eq $_ } ('project', 'location', 'year', 'trait', undef)) { 
	    $error = "Valid keys are project, year, trait and location";
	    $c->stash->{rest} = { error => $error };
	    return;
	}
    }

    my $dbh = $c->dbc->dbh();
    my $q = "";  # get the primary requested data
    my $sq = ""; # the associated query to get all the stocks




    my $item = $criteria_list->[-1];

    my $results_ref = get_union($criteria_list, $dataref); 

    $c->stash->{rest} = $results_ref;
}
    

1;


    


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
    my $j = JSON::Any->new;
    
    my @criteria_list = $c->req->param('categories[]');
	
    my $dataref = {};
    my $genotypes = $c->req->param('genotypes');
    my @retrieval_types = $c->req->param('retrieval_types');

    print STDERR "criteria list = " . Dumper(@criteria_list);

    my $intersect = $c->req->param("intersect");

    my $error = '';

    foreach my $select (@criteria_list) { 
     	print STDERR "Checking $select\n";
     	chomp($select);
     	if (! any { $select eq $_ } ('accessions', 'breeding_programs', 'locations', 'plots', 'traits', 'trials', 'years', 'genotypes', undef)) { 
     	    $error = "Valid keys are accessions, breeding_programs, locations, plots, traits, trials, years, and genotypes or undef";
     	    $c->stash->{rest} = { error => $error };
     	    return;
     	}
     }

    my $criteria_list = \@criteria_list;
    for (my $i=0; $i<scalar(@$criteria_list); $i++) { 
	my @data;
	my $param = $c->req->param("data[$i][]");
	print STDERR "PARAM: $param";
	if (defined($param) && ($param ne '')) { @data =  $c->req->param("data[$i][]"); }
	
	if (@data) { 
	    print STDERR "data=" . Dumper(@data);
	    my @cdata = map {"'$_'"} @data;
	    my $qdata = join ",", @cdata;	    
	    print STDERR "qdata=" . Dumper($qdata);
	    $dataref->{$criteria_list->[-1]}->{$criteria_list->[$i]} = $qdata;
	}
    }

     my $dbh = $c->dbc->dbh();

     my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );
    
     my $results_ref = $bs->get_intersect(\@criteria_list, $dataref, $genotypes, $intersect); 

    print STDERR "RESULTS: ".Data::Dumper::Dumper($results_ref);

    $c->stash->{rest} = {
	list => $results_ref->{results}
    };
}
    



    

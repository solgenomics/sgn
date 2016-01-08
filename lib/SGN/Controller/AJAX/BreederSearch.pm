
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
#    my @jdata = $c->req->param('data');
    my $data;
    my $dataref;
    my $genotypes = $c->req->param('genotypes');
    my @retrieval_types = $c->req->param('retrieval_types');

    print STDERR "criteria list = " . Dumper(@criteria_list);

    my $intersect = $c->req->param("intersect");

    print STDERR "DATA: " . Dumper($data);

 #   if ($c->req->param('data')) {
#	my @array = @$data; 
#	#my %dataref = $array[0];
#	my $dataref = $data;
 #   }

    if ($c->req->param('data')) {
	$data = $j->jsonToObj($c->req->param('data'));
	my @array = @$data;
	my $hashref = $array[0];
	my %hash = %$hashref;
	$dataref = \%hash;
	print STDERR "DATAREF: " . Dumper($dataref);
    }

    #foreach my $string (@data) {
#	print STDERR "thing =" . Dumper($string);
#	my $value = @$string[0];
#	print STDERR "thing =" . Dumper($value);
#	$dataref{$criteria_list[1]} => $string;
 #   }
    my $error = "";

     foreach my $select (@criteria_list) { 
     	print STDERR "Checking $select\n";
     	chomp($select);
     	if (! any { $select eq $_ } ('accessions', 'breeding_programs', 'locations', 'plots', 'traits', 'trials', 'years', 'genotypes', undef)) { 
     	    $error = "Valid keys are accessions, breeding_programs, locations, plots, traits, trials, years, and genotypes or undef";
     	    $c->stash->{rest} = { error => $error };
     	    return;
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
    



    

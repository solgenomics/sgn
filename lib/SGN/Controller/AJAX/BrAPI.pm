
package SGN::Controller::AJAX::BrAPI;

use Moose;
use JSON::Any;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $version = shift;
    $c->stash->{api_version} = $version;
    print STDERR "PROCESSING /...\n";
}

sub genotype : Chained('brapi') PathPart('genotype') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $id = shift;
    $c->stash->{genotype_id} = $id;
    
    


}

sub genotype_count : Chained('genotype') PathPart('count') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR "PROCESSING genotype/count...\n";

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $rs = $schema->resultset("Stock::Stock")->search( { 'me.stock_id' => $c->stash->{genotype_id} })->search_related('nd_experiment_stocks')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');


    my @runs;
    foreach my $row ($rs->all()) { 
	my $genotype_json = $row->value();
	my $genotype = JSON::Any->decode($genotype_json);
	
	push @runs, { 
	    runID => $row->genotypeprop_id(),
	    method => "null",
	    markerCount => scalar(keys(%$genotype)),
	};
    }
    my $response = {
	id => $c->stash->{genotype_id},
	data => \@runs
    };
    
    $c->stash->{rest} = $response;
	    
	
	
		
	    
	
}

sub genotype_fetch : Chained('genotype') PathPart('fetch') Args(0){ 
    my $self = shift;
    my $c = shift;
    

}




1;

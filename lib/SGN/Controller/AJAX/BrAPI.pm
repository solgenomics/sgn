
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
    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
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

    my $rs = $self->genotype_rs($c);

    my @runs;
    foreach my $row ($rs->all()) { 
	my $genotype_json = $row->value();
	my $genotype = JSON::Any->decode($genotype_json);
	
	push @runs, { 
	    runId => $row->genotypeprop_id(),
	    analysisMethod => "null",
	    resultCount => scalar(keys(%$genotype)),
	};
    }
    my $response = {
	id => $c->stash->{genotype_id},
	markerCounts => \@runs
    };
    
    $c->stash->{rest} = $response;	
}

sub genotype_fetch : Chained('genotype') PathPart('') Args(0){ 
    my $self = shift;
    my $c = shift;

    my $rs = $self->genotype_rs($c);

    my @runs = ();
    foreach my $row ($rs->all()) { 
	my $genotype_json = $row->value();
	my $genotype = JSON::Any->decode($genotype_json);
	my %encoded_genotype = ();
	foreach my $m (keys %$genotype) { 
	    if ($genotype->{$m} == 1) { 
		$encoded_genotype{$m} = "AA";
	    }
	    elsif ($genotype->{$m} == 0) { 
		$encoded_genotype{$m} = "BB";
	    }
	    elsif ($genotype->{$m} == 2) { 
		$encoded_genotype{$m} = "AB";
	    }
	    else { 
		$encoded_genotype{$m} = "NA";
	    }
	}
	push @runs, { genotype => \%encoded_genotype, runId => $row->genotypeprop_id() };
	
    }
    $c->stash->{rest} =  {
	gid => $c->stash->{genotype_id},
	genotypes => \@runs,

    };
}

sub genotype_rs { 
    my $self = shift;
    my $c = shift;

    my $rs = $c->stash->{schema}->resultset("Stock::Stock")->search( { 'me.stock_id' => $c->stash->{genotype_id} })->search_related('nd_experiment_stocks')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');

    return $rs;
}

1;

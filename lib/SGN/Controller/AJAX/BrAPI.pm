
package SGN::Controller::AJAX::BrAPI;

use Moose;
use JSON::Any;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    #default => 'text/javascript', # for jsonp
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    #map  => { 'text/javascript' => 'JSONP', 'text/html' => 'JSONP' },
   );

sub brapi : Chained('/') PathPart('brapi') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $version = shift;
    $c->stash->{api_version} = $version;
    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    print STDERR "PROCESSING /...\n";
}

sub genotype : Chained('brapi') PathPart('genotype') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $id = shift;
    $c->stash->{genotype_id} = $id;
}

sub germplasm : Chained('brapi') PathPart('germplasm') CaptureArgs(0) { 
    my $self = shift;
    my $c = shift;
    
}

sub germplasm_find : Chained('germplasm') PathPart('find') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();

    if (! $params->{q}) { 
	$c->stash->{rest} = { error => "No query provided" };
	return;
    }

    my $rs;

    if (! $params->{matchMethod} || $params->{matchMethod} eq "exact") { 
	$rs = $c->dbic_schema("Bio::Chado::Schema")
	->resultset("Stock::Stock")
	->search( { uniquename => { ilike => $params->{q} } });
    }
    elsif ($params->{matchMethod} eq "wildcard") { 
	$c->stash->{rest} = { error => "matchMethod 'wildcard' not yet implemented" };
	return;
    }
    else { 
	$c->stash->{rest} = { error => "matchMethod '$params->{matchMethod}' not recognized" };
	return;
    }

    my @results;

    foreach my $stock ($rs->all()) { 
	push @results, { queryName => $params->{q},
			 uniqueName => $stock->uniquename(),
			 germplasmId => $stock->stock_id(),
	};
    }

    $c->stash->{rest} = \@results;
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

    my $params = $c->req->params();

    my @runs = ();
    my $count = 0;
    foreach my $row ($rs->all()) { 
	my $genotype_json = $row->value();
	my $genotype = JSON::Any->decode($genotype_json);
	my %encoded_genotype = ();
	foreach my $m (sort keys %$genotype) { 
	    $count++;

	    if ($params->{page} && $params->{pageSize}) { 
		if ($count <= $params->{page} * $params->{pageSize} ||
		    $count > $params->{page} * $params->{pageSize} + $params->{pageSize}) { 
		    next;
		}
	    }
	    
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
	germplasmId => $c->stash->{genotype_id},
	data => \@runs,
    };

    if ($params->{page} && $params->{pageSize}) { 
	$c->stash->{rest}->{page} = $params->{page};
	$c->stash->{rest}->{pageSize} = $params->{pageSize};
    }
}

sub genotype_rs { 
    my $self = shift;
    my $c = shift;

    my $rs = $c->stash->{schema}->resultset("Stock::Stock")->search( { 'me.stock_id' => $c->stash->{genotype_id} })->search_related('nd_experiment_stocks')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops');

    return $rs;
}

1;



package SGN::Controller::AJAX::Phenome;

use Moose;

use JSON::Any;

BEGIN { extends 'Catalyst::Controller::REST'; }




sub generate_genotype_matrix : Path('/phenome/genotype/matrix/generate') :Args(1) { 
    my $self = shift;
    my $c = shift;
    my $group = shift;

    
    my $c->dbc->dbh->prepare("SELECT stock_id, genotypeprop.value FROM stock_genotype JOIN genotype USING (genotype_id)  JOIN genotypeprop ON (genotype.genotype_id = genotypeprop.genotype_id)");

    my %all_keys;
    my @genotypes; 

    while (my ($stock_id, $genotype_json) = $h->fetchrow_array()) { 
	my %genotype = JSON::Any->decode($genotype_json);
	
	push @genotypes, [$stock_id, \%genotype ];
	
	foreach my $k (keys %genotype) { 
	    $all_keys{$k}++;
	}
    }
    my $matrix = ""; 
    
    foreach my $k (keys %all_keys) { 
	# print header row
	$matrix = "\t".$k;
    }
    foreach my $g (@genotypes) { 

	$matrix = $g->[0];

	foreach my $k (keys %all_keys) { 
	    # print header row
	    $matrix = "\t".$s->[1]->{$k};
	}	

    }
	
    $c->stash->{rest} = [ matrix => $matrix ];

}

1;

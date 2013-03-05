

package SGN::Controller::AJAX::Phenome;

use Moose;

use JSON::Any;

BEGIN { extends 'Catalyst::Controller::REST'; }




sub generate_genotype_matrix : Path('/phenome/genotype/matrix/generate') :Args(1) { 
    my $self = shift;
    my $c = shift;
    my $group = shift;

    print STDERR $c->config->{dbname}."\n";
    my $h = $c->dbc->dbh->prepare("SELECT stock_id, genotypeprop.value FROM nd_experiment_stock join nd_experiment_genotype USING(nd_experiment_id) JOIN genotype USING (genotype_id)  JOIN genotypeprop ON (genotype.genotype_id=genotypeprop.genotype_id)");
    $h->execute();

    my %all_keys;
    my @genotypes; 

    print STDERR "dealing with SQL query...\n\n";

    while (my ($stock_id, $genotype_json) = $h->fetchrow_array()) { 

	print STDERR "STOCK $stock_id = $genotype_json\n";

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
	    $matrix = "\t".$g->[1]->{$k};
	}	

    }
	
   print STDERR "generating REST response\n";

    $c->stash->{rest} = [ matrix => $matrix ];

}

1;

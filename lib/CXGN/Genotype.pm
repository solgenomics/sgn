
package CXGN::Genotype;

use Moose;

use JSON::Any;
use Math::Round qw | :all |;

has 'genotypeprop_id' => ( isa => 'Int',
			   is => 'rw',
    );

has 'bcs_schema' => (isa => 'Ref',
		     is => 'rw',
    );

has 'marker_encoding' => (isa => 'Str',
			  is => 'rw',
			  default => 'DS',
    );

has 'id' => ( isa => 'Int',
	      is => 'rw',
    );

has 'name' => ( isa => 'Str',
		is => 'rw',
    );

has 'method' => (isa => 'Str',
		 is => 'rw',
    );

has 'markerscores' => ( isa => 'HashRef',
			is  => 'rw',
    );

#has 'rawscores' => (isa => 'HashRef',
#		    is => 'rw',
#    );

has 'markers' => (isa => 'ArrayRef',
		  is => 'rw',
    );

#has 'dosages' => (isa => 'HashRef',
#		  is => 'rw',
#    );



sub BUILD { 
    my $self = shift;

    my $genotypeprop_id = $self->genotypeprop_id();
    my $bcs_schema = $self->bcs_schema();



    if ( defined($genotypeprop_id) && defined($bcs_schema)) { 
	print STDERR "Creating CXGN::Genotype object from genotypeprop_id ".$self->genotypeprop_id()." and the schema object\n";

	my $row = $self->bcs_schema()->resultset("Genetic::Genotypeprop")->find( { genotypeprop_id=> $self->genotypeprop_id() });

	if ($row) { 
	    $self->from_json($row->value());
	}
	else { 
	    die "The CXGN::Genotype object could not be created with the genotypeprop_id ".$self->genotypeprop_id()." and the provided schema.";
	}
	print STDERR "Done!\n";
    }
}
	
sub from_json { 
    my $self = shift;
    my $json = shift;
    
    #print STDERR "JSON = $json\n";
    
    my $data = JSON::Any->decode($json);

    $self->markerscores($data);

    my @markers = keys(%{$data});
    $self->markers( \@markers );
    
}

sub to_json { 
    my $self = shift;
    
    my $json = JSON::Any->encode($self->markerscores());
    
    return $json;
}

    

sub calculate_consensus_scores { 
    my $self = shift;
    my $other_genotype = shift;

    my $other_scores = $other_genotype->markerscores();
    my $this_scores = $self->markerscores();
    my $consensus_scores = {};
    foreach my $m (@{$self->markers()}) { 
	if (! exists($other_scores->{$m}) ||
	    ! defined($other_scores->{$m}) ||
	    ! $other_scores->{$m} ||
	    $other_scores->{$m} eq "NA") { 
	    $consensus_scores->{$m} = $this_scores->{$m};
	}
    }
    return $consensus_scores;
}


sub calculate_distance { 
    my $self = shift;
    my $other_genotype = shift;

    my $total_matches = 0;
    my $total_mismatches = 0;
    my $other_genotype_score = $other_genotype->markerscores();
    my $this_genotype_score = $self->markerscores();

    foreach my $m (@{$self->markers()}) { 
	if ($self->good_score($other_genotype_score->{$m}->{$self->marker_encoding()}) && $self->good_score($this_genotype_score->{$m}->{$self->marker_encoding() })) { 
	    if ($self->scores_are_equal($other_genotype_score->{$m}->{$self->marker_encoding()}, $this_genotype_score->{$m}->{$self->marker_encoding()})) { 
		$total_matches++;
		#print STDERR "$m: $other_genotype_score->{$m} matches $this_genotype_score->{$m}\n";
	    }
	    else { 
		$total_mismatches++;
		#print STDERR "$m: $other_genotype_score->{$m} no match with $this_genotype_score->{$m}\n";
	    }
	    
	}
	else {    #print STDERR "$m has no valid scores\n"; 
	}
    }
    return $total_matches / ($total_matches + $total_mismatches);
}

sub read_counts { 
    my $self = shift;
    my $marker = shift;

    my $raw = $self->rawscores->{$marker};
    #print STDERR "RAW: $raw\n";
    my $counts = (split /\:/, $raw)[1];
    
    my ($c1, $c2) = split /\,/, $counts;

    return ($c1, $c2);

}

sub good_call { 
    my $self = shift;
    my $marker = shift;
    my ($c1, $c2) = $self->read_counts($marker);
    if ( ($c1 + $c2) < 2) { 
	return 0;
    }
    return 1;
}

sub percent_good_calls { 
    my $self = shift;
    
    my $good_calls = 0;
    foreach my $m (@{$self->markers()}) { 
	if ($self->good_call($m)) { 
	    $good_calls++;
	}
    }
    return $good_calls / scalar(@{$self->markers()});
}

sub good_score { 
    my $self = shift;
    my $score = shift;

    if (!defined($score)) { return 0; }

    if ($score =~ /0|1\/0|1/) { return 1; }

    if ($score =~ /^[A-Za-z?]+$/) { return 0; }
    
    $score = round($score);

    if ($score == 0 || $score == 1 || $score ==2 || $score == -1) { 
	return 1;
    }
    else { 
	return 0;
    }
}

sub scores_are_equal { 
    my $self = shift;
    my $score1 = shift;
    my $score2 = shift;

    if ($self->good_score($score1)
	&& $self->good_score($score2)) { 
	if (round($score1) == round($score2)) {
	    return 1;
	}
    }
    return 0;
}
    

sub calculate_encoding_type { 


}

__PACKAGE__->meta->make_immutable;

1;

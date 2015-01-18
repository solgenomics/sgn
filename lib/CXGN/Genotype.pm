
package CXGN::Genotype;

use Moose;

use JSON::Any;
use Math::Round qw | :all |;

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

has 'rawscores' => (isa => 'HashRef',
		    is => 'rw',
    );

has 'markers' => (isa => 'ArrayRef',
		  is => 'rw',
    );

has 'dosages' => (isa => 'HashRef',
		  is => 'rw',
    );


sub from_json { 
    my $self = shift;
    my $json = shift;
    
    my $data = JSON::Any->decode($json);

    $self->markerscores($data);

    my @markers = keys(%$data);
    $self->markers( \@markers );
    
}

sub to_json { 


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
	if ($self->good_score($other_genotype_score->{$m}) && $self->good_score($this_genotype_score->{$m})) { 
	    if ($self->scores_are_equal($other_genotype_score->{$m}, $this_genotype_score->{$m})) { 
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


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

=head2 from_json

 Usage:        $gt->from_json($json_string)
 Desc:         Use json string to populate the object. Format is identical to 
               jsonb storage format in the database.
 Ret:
 Args:
 Side Effects:
 Example:

=cut
	
sub from_json { 
    my $self = shift;
    my $json = shift;
    
    #print STDERR "JSON = $json\n";
    
    my $data = JSON::Any->decode($json);

    $self->markerscores($data);

    my @markers = keys(%{$data});
    $self->markers( \@markers );
    
}

=head2 to_json

 Usage:        my $json = $gt->to_json()
 Desc:         convert the data in this object to json notation
 Ret:
 Args:
 Side Effects:
 Example:

=cut


sub to_json { 
    my $self = shift;
    
    my $json = JSON::Any->encode($self->markerscores());
    
    return $json;
}

    
=head2 calculate_consensus_scores

 Usage:        my $score = $gt->calculate_consensus_scores($other_gt);
 Desc:         calculate a consensus score with another genotype
               returns a hashref containing markers with consensi.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

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

=head2 calculate_distance

 Usage:        my $distance = $gt->calculate_distance($another_genotype)
 Desc:         Calculate the distance to another genotype 
 Ret:          A value between 0 and 1, 0 being infinite distance, 1 being
               identical genotypes.
 Args:
 Side Effects:
 Example:

=cut

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

=head2 percent_good_calls

 Usage:        my $good_calls = $gt->percent_good_calls();
 Desc:         The number of good calls in this genotype
               Good call is defined as a numeric value
               Bad calls are undefined or alphanumeric values
               (so works only with dosage values for now).
 Ret:
 Args:
 Side Effects:
 Example:

=cut

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
    
=head2 check_parental _genotype_concordance

 Usage:        $concordance = $gt->
                 check_parental_genotype_concordance($female_parent, $male_parent);
 Desc:         the concordance of the parental genotypes with this genotype
 Ret:          a concordance score, between 0 and 1. 
               0 = zero concordance
               1 = complete concordance
               only observations on informative markers are returned
 Args:
 Side Effects:
 Example:

=cut

sub check_parental_genotype_concordance {
   my $self = shift;
   my $female_parent_genotype = shift;
   my $male_parent_genotype = shift;

   my $self_markers = $self->markerscores();
   my $mom_markers = $female_parent_genotype->markerscores();
   my $dad_markers = $male_parent_genotype->markerscores();

   my $non_informative =0;
   my $concordant =0;
   my $non_concordant =0;
   foreach my $m (keys %$self_markers) {
    
    my @matrix; #mom, dad, self, 1=possible 0=impossible
    $matrix[ 0 ][ 0 ][ 0 ] =1;
    $matrix[ 0 ][ 0 ][ 1 ] =0;
    $matrix[ 0 ][ 0 ][ 2 ] =0;
    $matrix[ 0 ][ 1 ][ 0 ] =1;
    $matrix[ 0 ][ 1 ][ 1 ] =1;
    $matrix[ 0 ][ 1 ][ 2 ] =0;
    $matrix[ 0 ][ 2 ][ 1 ] =1;
    $matrix[ 0 ][ 2 ][ 0 ] =1;
    $matrix[ 0 ][ 2 ][ 2 ] =0;

    $matrix[ 1 ][ 0 ][ 0 ] =1;
    $matrix[ 1 ][ 0 ][ 1 ] =1;
    $matrix[ 1 ][ 0 ][ 2 ] =0;
    $matrix[ 1 ][ 1 ][ 0 ] =-1;
    $matrix[ 1 ][ 1 ][ 1 ] =-1;
    $matrix[ 1 ][ 1 ][ 2 ] =0;
    $matrix[ 1 ][ 2 ][ 0 ] =0;
    $matrix[ 1 ][ 2 ][ 1 ] =1;
    $matrix[ 1 ][ 2 ][ 2 ] =1;
    
    $matrix[ 2 ][ 0 ][ 0 ] = 0;
    $matrix[ 2 ][ 0 ][ 1 ] = 1;
    $matrix[ 2 ][ 0 ][ 2 ] = 0;
    $matrix[ 2 ][ 1 ][ 0 ] = 1;
    $matrix[ 2 ][ 1 ][ 1 ] = 1;
    $matrix[ 2 ][ 1 ][ 2 ] = 1;
    $matrix[ 2 ][ 2 ][ 0 ] = 0;
    $matrix[ 2 ][ 2 ][ 1 ] = 0;
    $matrix[ 2 ][ 2 ][ 2 ] = 1;


    if (defined($mom_markers->{$m}) && defined($dad_markers->{$m}) && defined($self_markers->{$m})) {
        
        my $score = $matrix[ round($mom_markers->{$m})]->[ round($dad_markers->{$m})]->[ round($self_markers->{$m})];
        if ($score == 1) {
        $concordant++;

        }
        elsif ($score == -1)  {
        $non_informative++;
        }
        else {
        
        $non_concordant++;

        }
    }
   }
   return ($concordant, $non_concordant, $non_informative);
}



sub calculate_encoding_type { 


}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Bio::SecreTary::SecreTarySelect - an object to implement the SecreTary
secretion prediction algorithm. Parameters defining the algorithm are
stored, then can take array of SecreTaryAnalyse objects and categorize
each as grp1, grp2, fail.

=head1 DESCRIPTION

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

package Bio::SecreTary::SecreTarySelect;
use strict;
use warnings;
use Carp;
use Bio::SecreTary::SecreTaryAnalyse;
use Readonly;
Readonly my $FALSE => 0;
Readonly my $TRUE  => 1;

# set up defaults for SecreTary parameters:
Readonly my $def_min_tm_length => 17;
Readonly my $def_max_tm_length => 33;
Readonly my %defaults          => (
    'g1_min_tmpred_score' => 1500,
    'g1_min_tm_length'    => $def_min_tm_length,
    'g1_max_tm_length'    => $def_max_tm_length,
    'g1_tm_start_by'      => 30,

    'g2_min_tmpred_score' => 900,
    'g2_min_tm_length'    => $def_min_tm_length,
    'g2_max_tm_length'    => $def_max_tm_length,
    'g2_tm_start_by'      => 17,

    'min_AI22'        => 71.304,
    'min_Gravy22'     => 0.2636,
    'max_nDRQPEN22'   => 8,
    'max_nNitrogen22' => 34,
    'max_nOxygen22'   => 32,
    'max_tm_nGASDRQPEN' => 10 
);

=head2 function new()

Synopsis: my $STS_obj = Bio::SecreTary::SecreTarySelect->new({'g1_min_tmpred_score' => 1300, 'g1_min_tm_length => 16});
	Arguments: Default values of parameters my be overridden by supplying a hash ref with parameter names and values. min and max tm lengths for BOTH group1 and group2 may be specified as e.g.: {'min_tm_length' => 18, 'max_tm_length' => 35}
	Returns:	an instance of a SecreTarySelect object
	Side effects:	creates the object.
	Description:

=cut

sub new {
    my $class        = shift;
    my $self         = bless {}, $class;
    my $arg_hash_ref = shift;
    foreach my $param ( keys %defaults ) {    # set params to defaults
        $self->{$param} = $defaults{$param};
    }

    if ( defined $arg_hash_ref ) {
        if ( ref( $arg_hash_ref ) eq 'HASH' ) {
            foreach my $param ( keys %$arg_hash_ref ) {
                if ( exists $self->{$param} ) {
                    if ( defined $arg_hash_ref->{$param} ) {
                        $self->{$param} = $arg_hash_ref->{$param};
                    }
                }
                elsif ( $param eq 'min_tm_length' ) {
                    $self->{g1_min_tm_length} = $arg_hash_ref->{$param};
                    $self->{g2_min_tm_length} = $arg_hash_ref->{$param};
                }
                elsif ( $param eq 'max_tm_length' ) {
                    $self->{g1_max_tm_length} = $arg_hash_ref->{$param};
                    $self->{g2_max_tm_length} = $arg_hash_ref->{$param};
                }
		else{
  carp
"In SecreTarySelect constructor. Attempt to set unknown parameter $param.\n"
                      . "Known params are:  "
                      . join( " ", keys %defaults ), "\n";

		}
            }
        }
        else {
            carp "SecreTarySelect constructor called with non-hashref argument. "
              . "Ignoring argument and using defaults.\n";
        }
    }

    return $self;
}



=head2 function refine_TMpred_solutions()

Synopsis: my ($g1_cand_soln, $g2_cand_soln) = $STS_obj->refine_TMpred_solutions($STA_obj);
	Arguments: An SecreTaryAnalyse object.
	Returns: A list containing strings describing the best group1 candidate,
and the best group2 candidate (based on tmpred results only).
e.g. (2311,23,44)(1100,5,30)
	Description: Look at the good tmpred solutions of $STA_obj, finds the one with
best score which satisfies group1 requirements on tm length, starting position, and 
similarly for group2.

=cut


sub refine_TMpred_solutions
{    # take the STA object and choose the best solution with
        # length in correct range and beginning early enough
  my $self            = shift;
  my $good_solutions = shift;
  #  my $STA             = shift;
  #  my $good_solutions = shift; # $STA->get_tmpred_good_solutions();

  my @TMpred_good_solns  = ();
    while ($good_solutions =~ s/^ \s* ( \( [^,]+ , [^,]+ , [^)]+ \) ) //xms) {
      push @TMpred_good_solns, $1;
   }
  # } else {
  #   @TMpred_good_solns  = split( " ", $STA->get_tmpred_good_solutions() )
  # }
my $grp1_best_score = -1;
    my $grp1_best       = "(-1,0,0)";
    my $grp2_best_score = -1;
    my $grp2_best       = "(-1,0,0)";
    foreach (@TMpred_good_solns) {
        /\(([^,]+),([^,]+),([^,]+)\)/;
        my ( $score, $beg, $end ) = ( $1, $2, $3 );
        my $tmh_length = $end + 1 - $beg;
        if (    $self->{g1_min_tm_length} <= $tmh_length
            and $self->{g1_max_tm_length} >= $tmh_length
            and $self->{g1_tm_start_by} >= $beg
            and $score > $grp1_best_score )
        {    # this is best so far for group1
            $grp1_best       = $_;
            $grp1_best_score = $score;
        }

        if (    $self->{g2_min_tm_length} <= $tmh_length
            and $self->{g2_max_tm_length} >= $tmh_length
            and $self->{g2_tm_start_by} >= $beg
            and $score > $grp2_best_score )
        {    # this is best so far for group1
            $grp2_best       = $_;
            $grp2_best_score = $score;
        }
    }
    return ( $grp1_best, $grp2_best ); # e.g. (2311,23,44)(1100,5,30)
}

=head2 function Categorize1()

Synopsis: my ($g1_cand_soln, $g2_cand_soln) = $STS_obj->Categorize($STA_obj);
	Arguments: An SecreTaryAnalyse object.
	Returns: A string with the prediction and tmpred predictions, e.g.: 
'group1 (2311,23,44)(1100,5,30)'
	Description: Calls refine_TMpred_solutions, which returns the 2 best candidates for group1, group2. Make a prediction ('group1', 'group2' or 'fail').

=cut

sub Categorize1 {    # categorize a single SecreTaryAnalyse object as
                     # group1, group2 or fail.
    my $self = shift;
    my $STA  = shift;    # SecreTaryAnalyse object

    my ( $soln1, $soln2 ) = $self->refine_TMpred_solutions($STA->get_tmpred_good_solutions());

## print "in STS->Categorize1. soln1, soln2: [$soln1][$soln2] \n";
    $soln1 =~ /\(([^,]+),([^,]+),([^,]+)\)/;
    my ( $score, $beg, $end ) = ( $1, $2, $3 ); # $beg, $end unit based
    my $tmh_length = $end + 1 - $beg;

    if ( $score >= $self->{g1_min_tmpred_score} and
($STA->nGASDRQPEN($beg-1, $end+1-$beg) <= $self->{max_tm_nGASDRQPEN})
 ) {    # group1
        $self->set_best_score($score);
        return "group1 $soln1 $soln2";
    }
    else {
        $soln2 =~ /\(([^,]+),([^,]+),([^,]+)\)/;
        my ( $score2, $beg2, $end2 ) = ( $1, $2, $3 );
        my $tmh_length2 = $end2 + 1 - $beg2;

        if (    $score2 >= $self->{g2_min_tmpred_score}
		and $STA->get_AI22() >= $self->{min_AI22}
		and $STA->get_Gravy22() >= $self->{min_Gravy22}
		and $STA->get_nDRQPEN22() <= $self->{max_nDRQPEN22}
	and $STA->get_nNitrogen22() <= $self->{max_nNitrogen22}
            and $STA->get_nOxygen22() <= $self->{max_nOxygen22}
and ($STA->nGASDRQPEN($beg2-1, $end2+1-$beg2) <= $self->{max_tm_nGASDRQPEN})

)
        {    # group 2
            $self->set_best_score($score2);
            return "group2 $soln1 $soln2";
        }
        else {    # fail
            $self->set_best_score(0);
            return "fail $soln1 $soln2";
        }
    }
}

=head2 function Categorize()

Synopsis: my $STA_prediction_array_ref = $STS_obj->Categorize(\@STA_arrayj);
	Arguments: Reference to array of SecreTaryAnalyse objects.
	Returns: A reference to an array of references to arrays, each
containing a STA obj and the prediction for that STA.
	Description: Calls Categorize1 on each STA obj. Makes YES/NO prediction
for each, pushes STA obj and prediction onto result array.

=cut

sub Categorize {
    my $self           = shift;
    my $ref            = shift;    # reference to array of STA objects.
    my @STAarray       = @$ref;
    my @STA_prediction = ();

    my ( $count_grp1, $count_grp2, $count_fail ) = ( 0, 0, 0 );
    foreach my $STA (@STAarray) {
        my $prediction = $self->Categorize1($STA); # e.g.: 'group1 (2311,23,44)(1100,5,30)'
        $prediction =~ s/^fail/NO/;
        $prediction =~ s/^group1/YES/;
        $prediction =~ s/^group2/YES/; 
	push @STA_prediction, [ $STA, $prediction ];
         # [ $STA, $prediction, $self->get_best_score() ];

    }
    return \@STA_prediction;
}


sub set_min_tmpred_score1 {
    my $self = shift;
    return $self->{min_tmpred_score1} = shift;
}

sub get_min_tmpred_score1 {
    my $self = shift;
    return $self->{min_tmpred_score1};
}

sub set_min_tmh_length1 {
    my $self = shift;
    return $self->{min_tmh_length1} = shift;
}

sub get_min_tmh_length1 {
    my $self = shift;
    return $self->{min_tmh_length1};
}

sub set_max_tmh_length1 {
    my $self = shift;
    return $self->{max_tmh_length1} = shift;
}

sub get_max_tmh_length1 {
    my $self = shift;
    return $self->{max_tmh_length1};
}

sub set_max_tmh_beg1 {
    my $self = shift;
    return $self->{max_tmh_beg1} = shift;
}

sub get_max_tmh_beg1 {
    my $self = shift;
    return $self->{max_tmh_beg1};
}

sub set_min_tmpred_score2 {
    my $self = shift;
    return $self->{min_tmpred_score2} = shift;
}

sub get_min_tmpred_score2 {
    my $self = shift;
    return $self->{min_tmpred_score2};
}

sub set_min_tmh_length2 {
    my $self = shift;
    return $self->{min_tmh_length2} = shift;
}

sub get_min_tmh_length2 {
    my $self = shift;
    return $self->{min_tmh_length2};
}

sub set_max_tmh_length2 {
    my $self = shift;
    return $self->{max_tmh_length2} = shift;
}

sub get_max_tmh_length2 {
    my $self = shift;
    return $self->{max_tmh_length2};
}

sub set_max_tmh_beg2 {
    my $self = shift;
    return $self->{max_tmh_beg2} = shift;
}

sub get_max_tmh_beg2 {
    my $self = shift;
    return $self->{max_tmh_beg2};
}

sub set_min_AI22 {
    my $self = shift;
    return $self->{min_AI22} = shift;
}

sub get_min_AI22 {
    my $self = shift;
    return $self->{min_AI22};
}

sub set_min_Gravy22 {
    my $self = shift;
    return $self->{min_Gravy22} = shift;
}

sub get_min_Gravy22 {
    my $self = shift;
    return $self->{min_Gravy22};
}

sub set_max_nDRQPEN22 {
    my $self = shift;
    return $self->{max_nDRQPEN22} = shift;
}

sub get_max_nDRQPEN22 {
    my $self = shift;
    return $self->{max_nDRQPEN22};
}

sub set_max_nNitrogen22 {
    my $self = shift;
    return $self->{max_nNitrogen22} = shift;
}

sub get_max_nNitrogen22 {
    my $self = shift;
    return $self->{max_nNitrogen22};
}

sub set_max_nOxygen22 {
    my $self = shift;
    return $self->{max_nOxygen22} = shift;
}

sub get_max_nOxygen22 {
    my $self = shift;
    return $self->{max_nOxygen22};
}

sub set_best_score {
    my $self = shift;
    return $self->{best_score1} = shift;
}

sub get_best_score {
    my $self = shift;
    return $self->{best_score1};
}


1;

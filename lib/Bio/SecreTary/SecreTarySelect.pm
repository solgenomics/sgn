
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
    'max_nOxygen22'   => 32
);

=head2 function new()

Synopsis: my $S = SecreTarySelect($min_score1, min_tmh_length1, max_tmh_length1, $max_beg1
	Arguments: Parameters specifying algorithm: 
    min_score1, min_tmh_length1, max_tmh_length1, $max_beg1,
  min_score2, min_tmh_length2, max_tmh_length2, $max_beg2,
			 
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
            }
        }
        else {
            warn "SecreTarySelect constructor called with non-hashref argument."
              . " Ignoring argument and using defaults.\n";
        }
    }

    return $self;
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

sub refine_TMpred_solutions
{    # take the TMpred object and choose the best solution with
        # length in correct range and beginning early enough
    my $self            = shift;
    my $STA             = shift;
    my @TMpred_outs     = split( " ", $STA->get_tmpred_good_solutions() );
    my $grp1_best_score = -1;
    my $grp1_best       = "(-1,0,0)";
    my $grp2_best_score = -1;
    my $grp2_best       = "(-1,0,0)";
    foreach (@TMpred_outs) {
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
    return ( $grp1_best, $grp2_best );
}

sub Categorize1 {    # categorize a single SecreTaryAnalyse object as
                     # group1, group2 or fail.
    my $self = shift;
    my $STA  = shift;    # SecreTaryAnalyse object

    my ( $soln1, $soln2 ) = $self->refine_TMpred_solutions($STA);
    $soln1 =~ /\(([^,]+),([^,]+),([^,]+)\)/;
    my ( $score, $beg, $end ) = ( $1, $2, $3 );
    my $tmh_length = $end + 1 - $beg;

    if ( $score >= $self->{g1_min_tmpred_score} ) {    # group1
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
            and $STA->get_nOxygen22() <= $self->{max_nOxygen22} )
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

sub Categorize {
    my $self           = shift;
    my $ref            = shift;    # reference to array of STA objects.
    my @STAarray       = @$ref;
    my @STA_prediction = ();

    my ( $count_grp1, $count_grp2, $count_fail ) = ( 0, 0, 0 );
    foreach my $STA (@STAarray) {
        my $prediction = $self->Categorize1($STA);
        $prediction =~ s/^fail/NO/;
        $prediction =~ s/^group1/YES/;
        $prediction =~ s/^group2/YES/; 
	push @STA_prediction, [ $STA, $prediction ];
         # [ $STA, $prediction, $self->get_best_score() ];
    }
    return \@STA_prediction;
}

1;

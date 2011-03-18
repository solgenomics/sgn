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
Readonly my $bad_tm_score => 500; #
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

Readonly my %W => (
'W_score' => 1000,
'W_nGASDRQPEN' => 10,
'W_AI22' => 100,
'W_Gravy22' => 0.5,
'W_nDRQPEN22' => 10,
'W_nNitrogen22' => 40,
'W_nOxygen22' => 40
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

    # foreach (keys %{$self}){
    #   print "$_ ", $self->{$_}, "\n";
    # }
    return $self;
}



=head2 function refine_TMpred_solutions()

Synopsis: my ($g1_cand_soln, $g2_cand_soln) = $STS_obj->refine_TMpred_solutions($STA_obj);
	Arguments: An SecreTaryAnalyse object.
	Returns: A list containing strings describing the best group1 candidate,
and the best group2 candidate (based on tmpred results only).
e.g. (2311,23,44)(1100,5,30)
	Description: Look at the good tmpred solutions of $STA_obj, finds the one with
best tmpred score which satisfies group1 requirements on tm length, starting position, and 
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
my $grp1_best_score = -1; # tmpred score? or ST score?
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


=head2 function refine_solutions()

Synopsis: $STS_obj->refine_TMpred_solutions($STA_obj);
	Arguments: An SecreTaryAnalyse object.
	Returns: A list containing strings describing the best group1 candidate,
and the best group2 candidate (based on tmpred results only).
e.g. (2311,23,44)(1100,5,30)
	Description: Look at the good tmpred solutions of $STA_obj, finds the one with
best score which satisfies group1 requirements on tm length, starting position, and 
similarly for group2.

=cut


sub refine_solutions
{    # take the STA object and give each solution a score
# scores >= 1 -> pass
# choose the one with best score.
  my $self            = shift;
#  my $analysis_string = shift;
  my $STA             = shift;
  #  my $good_solutions = shift; # $STA->get_tmpred_good_solutions();
my $analysis_string = $STA->get_analysis_string();
$analysis_string =~ s/ ( [^)]* ) $//xms; # del everything after last ) and put in $1
my $AA22string = $1; # this has AI etc for first 22, also cleavage site prediction.
$analysis_string =~ s/\s//gxms; #del whitespace
$analysis_string =~ s/ ^[(] //xms;
$analysis_string =~ s/ [)]$ //xms; # delete init and final parentheses
my @solns  = split('\)\(', $analysis_string);
my $grp1_best_score = -1000;
    my $grp1_best       = "(-1,0,0,-1)";
    my $grp2_best_score = -1000;
    my $grp2_best       = "(-1,0,0,-1)";
  foreach my $soln (@solns){
# print "soln: $soln \n";
       $soln =~ /\(([^,]+),([^,]+),([^,]+)\)/;
        my ( $score, $beg, $end, $nGASDRQPENtm ) = split(',',$soln);
        my $tmh_length = $end + 1 - $beg;
        if (    $self->{g1_min_tm_length} <= $tmh_length
            and $self->{g1_max_tm_length} >= $tmh_length
            and $self->{g1_tm_start_by} >= $beg ) # group1  candidate
        {
	  my $g1_score = $self->_group1_score($score, $nGASDRQPENtm);
	  if($g1_score > $grp1_best_score){
            $grp1_best       = $soln;
            $grp1_best_score = $g1_score;
	  }
	}

        if (    $self->{g2_min_tm_length} <= $tmh_length
            and $self->{g2_max_tm_length} >= $tmh_length
            and $self->{g2_tm_start_by} >= $beg)
	  {
	    my $g2_score = $self->_group2_score($score, $nGASDRQPENtm, $STA);
	    if($g2_score > $grp2_best_score)
        {    # this is best so far for group2
            $grp2_best       = $soln;
            $grp2_best_score = $g2_score;
        }
	  }
      }
    return ( "$grp1_best,$grp1_best_score", "$grp2_best,$grp2_best_score"); # e.g. (2311,23,44)(1100,5,30)
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
    my ($g1_best_candidate, $g2_best_candidate) = $self->refine_solutions($STA);
my ($g1_tm_score, $g1_beg, $g1_end, $g1_tmGASetc, $g1_STscore) = split(",", $g1_best_candidate);
my ($g2_tm_score, $g2_beg, $g2_end, $g2_tmGASetc, $g2_STscore) = split(",", $g2_best_candidate);
my ($STscore, $best_candidate) = ($g1_STscore > $g2_STscore)? ($g1_STscore, $g1_best_candidate): ($g2_STscore, $g2_best_candidate);
$STscore = ($STscore < -2)? -2: $STscore;
#print "$g1_STscore  $g2_STscore  $STscore \n";
# print "$g1_tmGASetc  $g2_tmGASetc \n";
$g1_best_candidate =~ s/,/ /g;
$g2_best_candidate =~ s/,/ /g;
my $return_val = '';
my $alt_return_val = '';
   # print "$g1best    $g2best \n";
## print "in STS->Categorize1. soln1, soln2: [$soln1][$soln2] \n";
    $soln1 =~ /\(([^,]+),([^,]+),([^,]+)\)/;
    my ( $score, $beg, $end ) = ( $1, $2, $3 ); # $beg, $end unit based
    my $tmh_length = $end + 1 - $beg;

    if ( $score >= $self->{g1_min_tmpred_score} and
($STA->nGASDRQPEN($beg-1, $end+1-$beg) <= $self->{max_tm_nGASDRQPEN})
 ) {    # group1
        $self->set_best_score($score);
	
        $return_val = "group1 $soln1 $soln2";
	$alt_return_val = "group1 $STscore $g1_best_candidate";
warn "??? ", $STA->get_sequence_id(), " Group1 but g1_STscore negative: $g1_STscore.\n" if($g1_STscore < 0);
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
            $return_val = "group2 $soln1 $soln2";
	    $alt_return_val = "group2 $STscore $g2_best_candidate";
warn  "??? ",$STA->get_sequence_id(), " Group2 but g2_STscore negative: $g2_STscore.\n" if($g2_STscore < 0);
        }
        else {    # fail
	  $self->set_best_score(0);
            $return_val = "fail $soln1 $soln2";
	  $alt_return_val = "fail $STscore $best_candidate";
        }
    }
return ($return_val, $alt_return_val);
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


sub _group1_score{
my $self = shift;
my $score = shift;
my $nGASDRQPEN = shift;
if($score < 0){ $score = $bad_tm_score; }
my $d_score = ($score - $self->get_g1_min_tmpred_score())/$W{W_score};
my $d_GASDRQPEN = ($self->{max_tm_nGASDRQPEN} - $nGASDRQPEN)/$W{W_nGASDRQPEN};

my $g1_score = 0;
#print "dscore, dGAS...: $d_score, $d_GASDRQPEN \n";
	    if($d_score >= 0.0 and $d_GASDRQPEN >= 0){
$g1_score += ($d_score > $d_GASDRQPEN)? $d_GASDRQPEN: $d_score; # add the min of these two.
}else{
  if($d_score < 0){
    $g1_score += $d_score;
  }
  if($d_GASDRQPEN < 0){
$g1_score += $d_GASDRQPEN;
}
}
return $g1_score;
}

sub _group2_score{
my $self = shift;
my $score = shift;
my $nGASDRQPEN = shift;
my $STA = shift;
my $AI22 = $STA->get_AI22();
my $Gravy22 = $STA->get_Gravy22();
my $nDRQPEN22 = $STA->get_nDRQPEN22();
my $nNitrogen22 = $STA->get_nNitrogen22();
my $nOxygen22 = $STA->get_nOxygen22();
if($score < 0){ $score = $bad_tm_score; }
my $d_score = ($score - $self->{g2_min_tmpred_score})/$W{W_score};
my $d_GASDRQPEN = ($self->{max_tm_nGASDRQPEN} - $nGASDRQPEN)/$W{W_nGASDRQPEN};
my $d_AI22 = ($AI22 - $self->{min_AI22})/$W{W_AI22};
my $d_Gravy22 = ($Gravy22 - $self->{min_Gravy22})/$W{W_Gravy22};
my $d_nDRQPEN22 = ($self->{max_nDRQPEN22} - $nDRQPEN22)/$W{W_nDRQPEN22};
my $d_nNitrogen22 = ($self->{max_nNitrogen22} - $nNitrogen22)/$W{W_nNitrogen22};
my $d_nOxygen22 = ($self->{max_nOxygen22} - $nOxygen22)/$W{W_nOxygen22};
my @scores = ($d_score, $d_GASDRQPEN,
	      $d_AI22, $d_Gravy22, $d_nDRQPEN22, $d_nNitrogen22, $d_nOxygen22);

my $sum_negs = 0.0;
my $min_pos = 1000000.0;
foreach (@scores){

if($_ < 0.0){ # get the sum of the negative scores
    $sum_negs += $_;
  }
if($_ > 0.0 and $_ < $min_pos){ # get the min of the positive scores
  $min_pos = $_;
}
}
 return ($sum_negs < 0.0)? $sum_negs : $min_pos; # if any negatives, use $sum_negs
}


sub set_g1_min_tmpred_score {
    my $self = shift;
    return $self->{g1_min_tmpred_score} = shift;
}

sub get_g1_min_tmpred_score {
    my $self = shift;
    return $self->{g1_min_tmpred_score};
}

# sub set_g1_min_tmh_length1 {
#     my $self = shift;
#     return $self->{min_tmh_length1} = shift;
# }

# sub get_min_tmh_length1 {
#     my $self = shift;
#     return $self->{min_tmh_length1};
# }

# sub set_max_tmh_length1 {
#     my $self = shift;
#     return $self->{max_tmh_length1} = shift;
# }

# sub get_max_tmh_length1 {
#     my $self = shift;
#     return $self->{max_tmh_length1};
# }

# sub set_max_tmh_beg1 {
#     my $self = shift;
#     return $self->{max_tmh_beg1} = shift;
# }

# sub get_max_tmh_beg1 {
#     my $self = shift;
#     return $self->{max_tmh_beg1};
# }

sub set_g2_min_tmpred_score {
    my $self = shift;
    return $self->{g2_min_tmpred_score} = shift;
}

sub get_g2_min_tmpred_score {
    my $self = shift;
    return $self->{g2_min_tmpred_score};
}

# sub set_min_tmh_length2 {
#     my $self = shift;
#     return $self->{min_tmh_length2} = shift;
# }

# sub get_min_tmh_length2 {
#     my $self = shift;
#     return $self->{min_tmh_length2};
# }

# sub set_max_tmh_length2 {
#     my $self = shift;
#     return $self->{max_tmh_length2} = shift;
# }

# sub get_max_tmh_length2 {
#     my $self = shift;
#     return $self->{max_tmh_length2};
# }

# sub set_max_tmh_beg2 {
#     my $self = shift;
#     return $self->{max_tmh_beg2} = shift;
# }

# sub get_max_tmh_beg2 {
#     my $self = shift;
#     return $self->{max_tmh_beg2};
# }

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

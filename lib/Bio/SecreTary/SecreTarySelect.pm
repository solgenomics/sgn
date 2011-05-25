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
use Moose;
#use namespace::autoclean;
use Carp;
use Bio::SecreTary::SecreTaryAnalyse;
use List::Util qw / min max /;

use Readonly;
Readonly my $FALSE => 0;
Readonly my $TRUE  => 1;

# set up defaults for SecreTary parameters:
Readonly my $def_min_tm_length       => 17;
Readonly my $def_max_tm_length       => 33;
Readonly my $bad_tm_score            => 500;
Readonly my $min_STscore             => -3;
Readonly my $max_STscore             => 1;
Readonly my $ST_pred_threshold_score => ( 0 - $min_STscore ) /
  ( $max_STscore - $min_STscore );

has g1_min_tmpred_score => (
			    isa     => 'Num',
			    is      => 'ro',
			    default => 1500
			   );
has g1_min_tm_length => (
			 isa => 'Int',
			 is => 'ro',
			 default => $def_min_tm_length
			);
has g1_max_tm_length => (
			 isa => 'Int', 
			 is => 'ro',
			 default => $def_max_tm_length
			);
has g1_tm_start_by => (
		       isa => 'Int',
		       is => 'ro',
		       default => 30
		      );


has g2_min_tmpred_score => (
			    isa     => 'Num',
			    is      => 'ro',
			    default => 900
			   );
has g2_min_tm_length => (
			 isa => 'Int',
			 is => 'ro',
			 default => $def_min_tm_length
			);
has g2_max_tm_length => (
			 isa => 'Int', 
			 is => 'ro',
			 default => $def_max_tm_length
			);
has g2_tm_start_by => (
		       isa => 'Int',
		       is => 'ro',
		       default => 17
		      );

has min_AI22 => (
		 isa => 'Num',
		 is => 'ro',
		 default => 71.304
		);
has min_Gravy22 => (
		    isa => 'Num',
		    is => 'ro',
		    default => 0.2636
		   );
has max_nDRQPEN22 => (
		      isa => 'Int',
		      is => 'ro',
		      default => 8
		     );
has max_nNitrogen22 => (
			isa => 'Int',
			is => 'ro',
			default => 34
		       );
has max_nOxygen22 => (
		      isa => 'Int',
		      is => 'ro',
		      default => 32
		     );
has max_tm_nGASDRQPEN => (
			  isa => 'Int',
			  is => 'ro',
			  default => 10
			 );

# Readonly my %defaults => (
#     'g1_min_tmpred_score' => 1500,
#     'g1_min_tm_length'    => $def_min_tm_length,
#     'g1_max_tm_length'    => $def_max_tm_length,
#     'g1_tm_start_by'      => 30,

#     'g2_min_tmpred_score' => 900,
#     'g2_min_tm_length'    => $def_min_tm_length,
#     'g2_max_tm_length'    => $def_max_tm_length,
#     'g2_tm_start_by'      => 17,

#     'min_AI22'          => 71.304,
#     'min_Gravy22'       => 0.2636,
#     'max_nDRQPEN22'     => 8,
#     'max_nNitrogen22'   => 34,
#     'max_nOxygen22'     => 32,
#     'max_tm_nGASDRQPEN' => 10
# );

Readonly my %W => (
		   'W_tm_score'    => 1000,
		   'W_nGASDRQPEN'  => 10,
		   'W_AI22'        => 100,
		   'W_Gravy22'     => 0.5,
		   'W_nDRQPEN22'   => 10,
		   'W_nNitrogen22' => 40,
		   'W_nOxygen22'   => 40
		  );


=head2 function refine_solutions()

Synopsis: $STS_obj->refine_solutions($STA_obj);
	Arguments: An SecreTaryAnalyse object.
	Returns: A list containing strings describing the best group1 candidate,
and the best group2 candidate, based on the SecreTary score.
	Description: Look at the good tmpred solutions of $STA_obj, finds the one with
best ST score which satisfies group1 requirements on tm length, starting position, and similarly for group2.

=cut

sub refine_solutions { # take the STA object and give each solution a score
		       # scores >= 0 -> pass
		       # choose the one with best score.
  my $self  = shift;
  my $STA   = shift;
  my $solns = $STA->candidate_solutions(); # array ref
  my $AA22string = $STA->aa22string(); # this has AI etc for first 22

  my $grp1_best_STscore = 0;
  my $grp1_best         = "-1,0,0,-1";
  my $grp2_best_STscore = 0;
  my $grp2_best         = "-1,0,0,-1";
  foreach my $soln ( @{$solns} ) {
    my ( $tm_score, $beg, $end, $nGASDRQPENtm ) = split( ',', $soln );
    my $tmh_length = $end + 1 - $beg;

    # check if length, start_by are OK for group1.
    if (    $tmh_length >= $self->{g1_min_tm_length}
            and $tmh_length <= $self->{g1_max_tm_length}
            and $beg <= $self->{g1_tm_start_by} ) # group1  candidate
      {	#if so, give it a ST score, and keep track of best grp1 STscore.
	my $g1_STscore = $self->_group1_STscore( $tm_score, $nGASDRQPENtm );
	if ( $g1_STscore > $grp1_best_STscore ) {
	  $grp1_best         = $soln;
	  $grp1_best_STscore = $g1_STscore;
	}
      }

    # check if length, start_by are OK for group2.
    if (    $tmh_length >= $self->{g2_min_tm_length}
            and $tmh_length <= $self->{g2_max_tm_length}
            and $beg <= $self->{g2_tm_start_by} ) { # if so, give a ST score, and keep track of best grp2 STscore.
      my $g2_STscore =
	$self->_group2_STscore( $tm_score, $nGASDRQPENtm, $STA );
      if ( $g2_STscore > $grp2_best_STscore ) {	# this is best so far for group2
	$grp2_best         = $soln;
	$grp2_best_STscore = $g2_STscore;
      }
    }
  }
  return ( "$grp1_best,$grp1_best_STscore", "$grp2_best,$grp2_best_STscore" )
    ;				# e.g. (2311,23,44)(1100,5,30)
}

=head2 function categorize1()

Synopsis: my ($g1_cand_soln, $g2_cand_soln) = $STS_obj->categorize1($STA_obj);
	Arguments: An SecreTaryAnalyse object.
	Returns: A string with the prediction and tmpred predictions, e.g.: 
'group1 (2311,23,44)(1100,5,30)'
	Description: Calls refine_TMpred_solutions, which returns the 2 best candidates for group1, group2. Make a prediction ('group1', 'group2' or 'fail').

=cut

sub categorize1 {     # categorize a single SecreTaryAnalyse object as
		      # group1, group2 or fail.
  my $self = shift;
  my $STA  = shift;		# SecreTaryAnalyse object

  my $return_val = '';
  my ( $g1_best_candidate, $g2_best_candidate ) =
    $self->refine_solutions($STA);
  my ( $g1_tm_score, $g1_beg, $g1_end, $g1_tmGASetc, $g1_STscore ) =
    split( ",", $g1_best_candidate );
  my ( $g2_tm_score, $g2_beg, $g2_end, $g2_tmGASetc, $g2_STscore ) =
    split( ",", $g2_best_candidate );
  my ( $STscore, $best_candidate, $best_group ) =
    ( $g1_STscore > $g2_STscore )
      ? ( $g1_STscore, $g1_best_candidate, 'group1' )
	: ( $g2_STscore, $g2_best_candidate, 'group2' );
  $best_candidate =~ s/,/ /g;

  $STscore = max( $STscore, $min_STscore ); 
  if ( $STscore >= $ST_pred_threshold_score ) {	# ST+
    $return_val =
      "$best_group $STscore $best_candidate"; # e.g. group1 0.821
  } else {
    $return_val = "fail $STscore $best_candidate";
  }
  return $return_val;
}

=head2 function categorize()

Synopsis: my $STA_prediction_array_ref = $STS_obj->categorize(\@STA_arrayj);
	Arguments: Reference to array of SecreTaryAnalyse objects.
	Returns: A reference to an array of references to arrays, each
containing a STA obj and the prediction for that STA.
	Description: Calls categorize1 on each STA obj. Makes YES/NO prediction
for each, pushes STA obj and prediction onto result array.

=cut

sub categorize {
    my $self           = shift;
    my $ref            = shift;    # reference to array of STA objects.
    my @STAarray       = @$ref;
    my @STA_prediction = ();

    my ( $count_grp1, $count_grp2, $count_fail ) = ( 0, 0, 0 );
    foreach my $STA (@STAarray) {
        my $prediction =
          $self->categorize1($STA);    # e.g.: 'group1 (2311,23,44)(1100,5,30)'
        $prediction =~ s/^fail/NO/;
        $prediction =~ s/^group1/YES/;
        $prediction =~ s/^group2/YES/;
        push @STA_prediction, [ $STA, $prediction ];

        # [ $STA, $prediction, $self->get_best_score() ];

    }
    return
      \@STA_prediction; # return ref to array of [$STA, $prediction] array refs.
}


sub _group1_STscore {
  my $self       = shift;
  my $tm_score   = shift;
  my $nGASDRQPEN = shift;
$tm_score = max( $tm_score, $bad_tm_score );
  my $d_tm_score =
    ( $tm_score - $self->g1_min_tmpred_score() ) / $W{W_tm_score};
  my $d_GASDRQPEN =
    ( 0.5 + $self->{max_tm_nGASDRQPEN} - $nGASDRQPEN ) / $W{W_nGASDRQPEN};

  my $g1_STscore = 0;
  if ( $d_tm_score >= 0.0 and $d_GASDRQPEN >= 0 ) {
    $g1_STscore +=
      ( $d_tm_score > $d_GASDRQPEN )
	? $d_GASDRQPEN
          : $d_tm_score;	# add the min of these two.
  } else {
    if ( $d_tm_score < 0 ) {
      $g1_STscore += $d_tm_score;
    }
    if ( $d_GASDRQPEN < 0 ) {
      $g1_STscore += $d_GASDRQPEN;
    }
  }

  if ( $g1_STscore > $max_STscore ) {
    $g1_STscore = $max_STscore;
  }
  if ( $g1_STscore < $min_STscore ) {
    $g1_STscore = $min_STscore;
  }
  $g1_STscore =
    ( $g1_STscore - $min_STscore ) / ( $max_STscore - $min_STscore );
  return $g1_STscore;		# scaled to lie in range [0,1]
}

sub _group2_STscore {
  my $self        = shift;
  my $tm_score    = shift;
  my $nGASDRQPEN  = shift;
  my $STA         = shift;
  my $AI22        = $STA->AI22();
  my $Gravy22     = $STA->Gravy22();
  my $nDRQPEN22   = $STA->nDRQPEN22();
  my $nNitrogen22 = $STA->nNitrogen22();
  my $nOxygen22   = $STA->nOxygen22();

$tm_score = max($tm_score, $bad_tm_score); 

  my $d_tm_score =
    ( $tm_score - $self->{g2_min_tmpred_score} ) / $W{W_tm_score};
  my $d_GASDRQPEN =
    ( 0.5 + $self->{max_tm_nGASDRQPEN} - $nGASDRQPEN ) / $W{W_nGASDRQPEN};
  my $d_AI22      = ( $AI22 - $self->{min_AI22} ) / $W{W_AI22};
  my $d_Gravy22   = ( $Gravy22 - $self->{min_Gravy22} ) / $W{W_Gravy22};
  my $d_nDRQPEN22 = ( $self->{max_nDRQPEN22} - $nDRQPEN22 ) / $W{W_nDRQPEN22};
  my $d_nNitrogen22 =
    ( $self->{max_nNitrogen22} - $nNitrogen22 ) / $W{W_nNitrogen22};
  my $d_nOxygen22 = ( $self->{max_nOxygen22} - $nOxygen22 ) / $W{W_nOxygen22};
  my @STscore_pieces = (
			$d_tm_score,  $d_GASDRQPEN,   $d_AI22, $d_Gravy22,
			$d_nDRQPEN22, $d_nNitrogen22, $d_nOxygen22
		       );

  my $sum_negs = 0.0;
  my $min_pos  = 1000000.0;
  foreach (@STscore_pieces) {
    if ( $_ < 0.0 ) { # get the sum of the negative pieces (or add in quadrature?)
      $sum_negs += $_;
    }
    if ( $_ >= 0.0 and $_ < $min_pos ) { # get the min of the positive scores
      $min_pos = $_;
    }
  }
  my $g2_STscore =
    ( $sum_negs < 0.0 )
      ? $sum_negs
	: $min_pos;		# if any negatives, use $sum_negs
$g2_STscore = min ($g2_STscore, $max_STscore);
$g2_STscore = max($g2_STscore, $min_STscore); 
  $g2_STscore =
    ( $g2_STscore - $min_STscore ) / ( $max_STscore - $min_STscore );
  return $g2_STscore;
}

__PACKAGE__->meta->make_immutable;

1;

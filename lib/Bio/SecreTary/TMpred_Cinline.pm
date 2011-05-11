
=head1 NAME

Bio::SecreTary::TMpred_Cinline

=head1 DESCRIPTION

An object to run the trans-membrane helix prediction program tmpred.

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

package Bio::SecreTary::TMpred_Cinline;
use strict;
use warnings;
use base qw / Bio::SecreTary::TMpred /;
use List::Util qw / min max /;

use Inline C => <<'END_C';

double max_index_in_range( SV * terms, int start, int stop ) {
        I32 numterms = 0;
        /* Make sure we have an array ref with values */
        if ((!SvROK(terms))
                        || (SvTYPE(SvRV(terms)) != SVt_PVAV)
                        || ((numterms = av_len((AV *)SvRV(terms))) < 0)) {
                return -10000;
        }
        /* Set result to first value in array */
        if(start < 0) { start = 0; }
        if(stop > numterms){ stop = numterms; }
        double max = SvNV(* av_fetch((AV *)SvRV(terms), start, 0));
        long max_index = start;
        long i;
        for (i = start+1; i <= stop; i++) {
                double thisval = SvNV(* av_fetch((AV *)SvRV(terms), i, 0));
                if(thisval > max){
                        max = thisval;
                        max_index = i;
                }
        }
       return max_index;
}

double max_in_range( SV * terms, int start, int stop ) {
        I32 numterms = 0;
        /* Make sure we have an array ref with values */
        if ((!SvROK(terms))
                        || (SvTYPE(SvRV(terms)) != SVt_PVAV)
                        || ((numterms = av_len((AV *)SvRV(terms))) < 0)) {
                return -10000;
        }
        /* Set result to first value in array */
        if(start < 0) { start = 0; }
        if(stop > numterms){ stop = numterms; }
        double max = SvNV(* av_fetch((AV *)SvRV(terms), start, 0));
        long i;
        for (i = start+1; i <= stop; i++) {
                double thisval = SvNV(* av_fetch((AV *)SvRV(terms), i, 0));
                if(thisval > max){
                        max = thisval;
                }
        }
       return max;
}

double make_profile_inner_loop(SV* m, SV* seq_nums, I32 kmrf){
   if ((!SvROK(m))
                        || (SvTYPE(SvRV(m)) != SVt_PVAV)
                        || ((av_len((AV *)SvRV(m)) + 1) < 0)) {
                return -10000;
        }
     double result = 0;
I32 length = av_len((AV *)SvRV(seq_nums)) + 1;
I32 ncols = av_len((AV *)SvRV(* av_fetch((AV*) SvRV(m), 0, 0 ))) + 1;

I32 plo  = (kmrf > 0)? kmrf: 0; //max($kmrf, 0);	# $kmrf = $k - $ref_position;
 I32  pup = (ncols + kmrf < length)? ncols + kmrf: length;  //min($ncols + $kmrf, $length);

I32 p = plo;
I32 i = plo - kmrf;
for(; p < pup; p++, i++){
I32 aanum = SvIV(* av_fetch((AV*) SvRV(seq_nums), p, 0 ));
SV* a = (* av_fetch((AV*) SvRV(m), aanum, 0 ));
result += SvNV(* av_fetch((AV*) SvRV(a), i, 0 ));
}
result = (result < 0)? (int) (result * 100 - 0.5): (int) (result * 100 + 0.5);
return result;
}

END_C

use Readonly;
Readonly my $FALSE    => 0;
Readonly my $TRUE     => 1;
Readonly my %defaults => (

			  #  'version'                     => 'perl',
			  'min_score'                   => 500,
			  'min_tm_length'               => 17,
			  'max_tm_length'               => 33,
			  'min_beg'                     => 0,
			  'max_beg'                     => 35,
			  'lo_orientational_threshold'  => 80,
			  'hi_orientational_threshold'  => 200,
			  'avg_orientational_threshold' => 80
			 );

Readonly my $IMITATE_PASCAL_CODE =>
  $TRUE;      # if this is true, does the same as the old pascal code.
Readonly my $TMHLOFFSET => ($IMITATE_PASCAL_CODE)
  ? 1
  : 0;

# TMHLOFFSET gets added to the max_tmh_length,
# and (1 - TMHLOFFSET) gets subtracted from min_tmh_length
# TMHLOFFSET => 1  makes it agree with pascal code.
# finds helices with length as large as next bigger odd number, e.g. if
# $max_tmh_length is 33, will find some helices of lengths 34 and 35.
# with TMHLOFFSET => 0, 33->33, 32->33, 31->31, etc. i.e. goes up to
# next greater OR EQUAL odd number, rather than to next STRICTLY greater odd.
# similarly the min length is affected. with TMHLOFFSET => 1, 17->17, 16->17, 15->15
# i.e. if you specify min length of 16 you will never see helices shorter than 17
# but with TMHLOFFSET => 0, 17->17, 16->15, 15->15, etc. now you find
# the length 16 ones, (as well as length 15 ones which are discarded in good_solutions).
# set up defaults for tmpred parameters:

=head2 function new

  Synopsis : my $tmpred_obj = Bio::SecreTary::TMpred->new();    # using defaults
  or my $tmpred_obj = Bio::SecreTary::TMpred->new( { min_score => 600 } );
  Arguments: $arg_hash_ref holds some parameters describing which 
      solutions will be found by tmpred :
      min_score, min_tm_length, max_tm_length, min_beg, max_beg . 
  Returns: an instance of a TMpred object 
  Side effects: Creates the object . 
  Description: Creates a TMpred object with certain parameters which 
      determine which trans-membrane helices to find.

=cut

sub new {
  my $class        = shift;
  my $self  = $class->SUPER::new(@_); #         = bless {}, $class;
  return $self;
}

sub make_profile {    # makes a profile, i.e. a certain array
  my $self = shift;
  my $seq_aanumber_array = shift; # ref to array of numbers
  my $table              = shift;
  my $ref_position       = $table->marked_position();
  my $matrix             = $table->table();
 # my $ncols   = scalar @{ $matrix->[0] }; # ncols is # elements in first row
  my $length = scalar @$seq_aanumber_array; #length $sequence;
  my @profile = ();
  for ( my $kmrf = 0 - $ref_position ; $kmrf < $length - $ref_position ; $kmrf++ ) {
    push @profile, make_profile_inner_loop( $matrix, $seq_aanumber_array, $kmrf);
  }
  return \@profile;
}

sub make_curve {
  my $self      = shift;
  my $m_profile = shift;
  my $n_profile = shift;
  my $c_profile = shift;
  my $min_halfw =
    $self->{min_halfw};	# int( ( (shift) - ( 1 - $TMHLOFFSET ) ) / 2 );
  my $max_halfw = $self->{max_halfw}; # int( ( (shift) + $TMHLOFFSET ) / 2 );
  my $length    = scalar @$m_profile;
  my @score = ((0) x $length);

  for(my $i = $min_halfw; $i < $length - $min_halfw; $i++){
	$score[$i] = $m_profile->[$i] +
	  max_in_range($n_profile, $i - $max_halfw, $i - $min_halfw) +
	  max_in_range($c_profile, $i + $min_halfw, $i + $max_halfw);
  }
  return \@score;
}

sub find_helix {
  my $self = shift;
  my ( $length, $start, $s, $m, $n, $c ) = @_;

  # $s, $m, $n, $c are refs to arrays
  # $io_score, $io_center_prof, $io_nterm_prof, $io_cterm_prof
  # or $oi_score, $oi_center_prof, ...
  my $min_halfw = $self->{min_halfw};
  my $max_halfw = $self->{max_halfw};

  for(my $i = max($start, $min_halfw); $i < $length - $min_halfw; $i++){

#    my $pos = max_index_in_range( $s, $i - $min_halfw, $i + $max_halfw );
#    my $test = (($i==$pos) and ($s->[$i] > 0));

    my $scr = max_in_range( $s, $i - $min_halfw, $i + $max_halfw );
    my $test = (( $s->[$i] == $scr ) and ( $s->[$i] > 0 ));

if($test) { # helix found
 #   if( ($i == $pos) and ($s->[$i] > 0) ) { #helix found

      my $beg = max($i - $max_halfw, 0);

      my $nt_position = max_index_in_range( $n, $beg, $i - $min_halfw );
      my $nt_score = $n->[$nt_position];

      my $end = min($i + $max_halfw, $length - 1);

      my $ct_position = max_index_in_range( $c, $i + $min_halfw, $end );
      my $ct_score = $c->[$ct_position];

      my $j_n = $i - $min_halfw;	# determine nearest N-terminus
      while (
	     $j_n - 1 >= 0	#  0 not 1 because 0-based
	     and $j_n - 1 >= $i - $max_halfw 
	    ) {
	if ( $n->[ $j_n - 1 ] > $n->[$j_n] ) {
	  $j_n--;
	} else {
	  last;
	}
      }

      my $j_c    = $i + $min_halfw;
      while ( $j_c + 1 < $length
	      and $j_c + 1 <= $i + $max_halfw
) {
	if ( defined $c->[ $j_c + 1 ] and defined $c->[$j_c] ) {
	  if ( $c->[ $j_c + 1 ] > $c->[$j_c] ) {
	    $j_c++;
	  } else {
	    last;
	  }
	} else {
	  print "j, c[j_c], c[j_c+1]: ", $j_c, " ", $c->[$j_c], " ",
	    $c->[ $j_c + 1 ], " ", $length, "\n";
	  exit;
	}
      }

      my $helix = Bio::SecreTary::Helix->new(center => [ $i, $m->[$i] ],
					   nterm => [ $nt_position, $nt_score ],
					   cterm => [ $ct_position, $ct_score ],
					   sh_nterm => [ $j_n, $n->[$j_n] ],
					   sh_cterm => [ $j_c, $c->[$j_c] ]
					  );
      $helix->score(
		    $helix->center()->[1]
		    + $helix->nterm()->[1]
		    + $helix->cterm()->[1]
		   );

      return ($TRUE, $helix->sh_cterm()->[0] + 1, $helix);
    }				# end of if helix found block

  }				# end of for loop

  return ($FALSE, $length, undef); # no helix found
}				# end of sub find_helix

1;

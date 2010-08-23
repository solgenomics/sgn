
=head1 NAME

SecreTarySelect 
    - an object to implement the SecreTary secretion prediction algorithm
	 parameters defining the algorithm are stored, then
    can take array of SecreTaryAnalyse objects and categorize each as grp1, grp2, fail.

=head1 DESCRIPTION

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

use strict;
#use CXGN::Secretome::SecreTaryAnalyse;
use SecreTaryAnalyse;

package SecreTarySelect;

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
    my $class = shift;
    my $self = bless {}, $class;

    $self->set_min_tmpred_score1(shift);
    $self->set_min_tmh_length1(shift);
    $self->set_max_tmh_length1(shift);
    $self->set_max_tmh_beg1(shift);

    $self->set_min_tmpred_score2(shift);
    $self->set_min_tmh_length2(shift);
    $self->set_max_tmh_length2(shift);
    $self->set_max_tmh_beg2(shift);

    $self->set_min_AI22(shift);
    $self->set_min_Gravy22(shift);
    $self->set_max_nDRQPEN22(shift);
    $self->set_max_nNitrogen22(shift);
    $self->set_max_nOxygen22(shift);

    return $self;
}

sub set_min_tmpred_score1 {
    my $self = shift;
    $self->{min_tmpred_score1} = shift;
}

sub get_min_tmpred_score1 {
    my $self = shift;
    return $self->{min_tmpred_score1};
}

sub set_min_tmh_length1 {
    my $self = shift;
    $self->{min_tmh_length1} = shift;
}

sub get_min_tmh_length1 {
    my $self = shift;
    return $self->{min_tmh_length1};
}

sub set_max_tmh_length1 {
    my $self = shift;
    $self->{max_tmh_length1} = shift;
}

sub get_max_tmh_length1 {
    my $self = shift;
    return $self->{max_tmh_length1};
}

sub set_max_tmh_beg1 {
    my $self = shift;
    $self->{max_tmh_beg1} = shift;
}

sub get_max_tmh_beg1 {
    my $self = shift;
    return $self->{max_tmh_beg1};
}

sub set_min_tmpred_score2 {
    my $self = shift;
    $self->{min_tmpred_score2} = shift;
}

sub get_min_tmpred_score2 {
    my $self = shift;
    return $self->{min_tmpred_score2};
}

sub set_min_tmh_length2 {
    my $self = shift;
    $self->{min_tmh_length2} = shift;
}

sub get_min_tmh_length2 {
    my $self = shift;
    return $self->{min_tmh_length2};
}

sub set_max_tmh_length2 {
    my $self = shift;
    $self->{max_tmh_length2} = shift;
}

sub get_max_tmh_length2 {
    my $self = shift;
    return $self->{max_tmh_length2};
}

sub set_max_tmh_beg2 {
    my $self = shift;
    $self->{max_tmh_beg2} = shift;
}

sub get_max_tmh_beg2 {
    my $self = shift;
    return $self->{max_tmh_beg2};
}

sub set_min_AI22 {
    my $self = shift;
    $self->{min_AI22} = shift;
}

sub get_min_AI22 {
    my $self = shift;
    return $self->{min_AI22};
}

sub set_min_Gravy22 {
    my $self = shift;
    $self->{min_Gravy22} = shift;
}

sub get_min_Gravy22 {
    my $self = shift;
    return $self->{min_Gravy22};
}

sub set_max_nDRQPEN22 {
    my $self = shift;
    $self->{max_nDRQPEN22} = shift;
}

sub get_max_nDRQPEN22 {
    my $self = shift;
    return $self->{max_nDRQPEN22};
}

sub set_max_nNitrogen22 {
    my $self = shift;
    $self->{max_nNitrogen22} = shift;
}

sub get_max_nNitrogen22 {
    my $self = shift;
    return $self->{max_nNitrogen22};
}

sub set_max_nOxygen22 {
    my $self = shift;
    $self->{max_nOxygen22} = shift;
}

sub get_max_nOxygen22 {
    my $self = shift;
    return $self->{max_nOxygen22};
}

sub set_best_solution1 {
    my $self = shift;
    $self->{best_solution1} = shift;
}

sub get_best_solution1 {
    my $self = shift;
    return $self->{best_solution1};
}

sub set_best_solution2 {
    my $self = shift;
    $self->{best_solution2} = shift;
}

sub get_best_solution2 {
    my $self = shift;
    return $self->{best_solution2};
}

sub set_best_score1 {
    my $self = shift;
    $self->{best_score1} = shift;
}

sub get_best_score1 {
    my $self = shift;
    return $self->{best_score1};
}

sub set_best_score2 {
    my $self = shift;
    $self->{best_score2} = shift;
}

sub get_best_score2 {
    my $self = shift;
    return $self->{best_score2};
}

sub refine_TMpred_solutions
{ # take the TMpred object and choose the best solution with length in correct range
        # and beginning early enough
    my $self            = shift;
    my $STA             = shift;
    my @TMpred_outs     = split( " ", $STA->get_TMpred()->get_solutions() );
    my $grp1_best_score = -1;
    my $grp1_best       = "(-1,0,0)";
    my $grp2_best_score = -1;
    my $grp2_best       = "(-1,0,0)";
    foreach (@TMpred_outs) {

        /\(([^,]+),([^,]+),([^,]+)\)/;
        my ( $score, $beg, $end ) = ( $1, $2, $3 );
        my $tmh_length = $end + 1 - $beg;
        if (    $self->get_min_tmh_length1() <= $tmh_length
            and $self->get_max_tmh_length1() >= $tmh_length
            and $self->get_max_tmh_beg1() >= $beg
            and $score > $grp1_best_score )
        {    # this is best so far for group1
            $grp1_best       = $_;
            $grp1_best_score = $score;
        }

        if (    $self->get_min_tmh_length2() <= $tmh_length
            and $self->get_max_tmh_length2() >= $tmh_length
            and $self->get_max_tmh_beg2() >= $beg
            and $score > $grp2_best_score )
        {    # this is best so far for group1
            $grp2_best       = $_;
            $grp2_best_score = $score;
        }
    }
    return ( $grp1_best, $grp2_best );
}

sub Categorize1 { # categorize a single SecreTaryAnalyse object as 
# group1, group2 or fail.
    my $self = shift;
    my $STA  = shift;    # SecreTaryAnalyse object

    my ( $soln1, $soln2 ) = $self->refine_TMpred_solutions($STA);
    $soln1 =~ /\(([^,]+),([^,]+),([^,]+)\)/;
    my ( $score, $beg, $end ) = ( $1, $2, $3 );
    my $tmh_length = $end + 1 - $beg;

    if ( $score >= $self->get_min_tmpred_score1() ) {
        return "group1";
    }
    else {
        $soln2 =~ /\(([^,]+),([^,]+),([^,]+)\)/;
        my ( $score2, $beg2, $end2 ) = ( $1, $2, $3 );
        my $tmh_length2 = $end2 + 1 - $beg2;

        if (
                $score2 >= $self->get_min_tmpred_score2()
            and $STA->get_AI22() >= $self->get_min_AI22()
            and    # 71.304 and
            $STA->get_Gravy22() >= $self->get_min_Gravy22() and     # 0.2636 and
            $STA->get_nDRQPEN22() <= $self->get_max_nDRQPEN22() and # 8 and
            $STA->get_nNitrogen22() <= $self->get_max_nNitrogen22()
            and                                                     # 34 and
            $STA->get_nOxygen22() <= $self->get_max_nOxygen22()
          )                                                         # 32)
        {                                                           # group 2
            return "group2";
        }
        else {                                                      # fail
            return "fail";
        }
    }
}

sub Categorize{
    my $self = shift;
    my $ref = shift; # reference to array of STA objects.
    my @STAarray = @$ref;
    my @STA_prediction = ();

    my ($count_grp1, $count_grp2, $count_fail) = (0,0,0);
    foreach my $STA (@STAarray){
	my $category = $self->Categorize1($STA);
	my $prediction = ($category eq 'fail')? "NO": "YES";
	push @STA_prediction, [$STA, $prediction]; # array of array refs
    }
    return \@STA_prediction;
}

1;

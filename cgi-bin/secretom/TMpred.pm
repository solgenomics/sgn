
=head1 NAME

TMpred 

=head1 DESCRIPTION

An object to run the trans-membrane helix prediction program tmpred, 
and to summarize and store its output.

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

use strict;
use IO::File;

#	use lib '/data/local/cxgn/core/sgn-tools/secretom';

package TMpred;

=head2 function new()

Synopsis:
   my $limits = [$min_score, $min_tmh_length, $max_tmh_length, $min_beg, $max_beg];      	my $t = TMpred->new($limits, $sequence, $sequence_id)
	Arguments: $limits is an array ref holding some parameters describing which solutions will be found by tmpred ($min_tmh_length, $max_tmh_length), and which will be kept in the TMpred object. Also an amino acid sequence and (optionally) a sequence id.
	Returns:	an instance of a TMpred object
	Side effects:	Runs tmpred, creates the object.
	Description:	Runs the tmpred (trans-membrane helix (tmh) prediction) 
program with parameters $min_tmh_length, $max_tmh_length, and summarizes the output.
Only keeps solutions with score, begin and end positions consistent with values in limits array.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    $self->set_limits(shift);    # array ref; specifies which tmhs to keep.
    $self->set_sequence(shift);
    $self->set_sequence_id( shift || ">A_protein_sequence" );
  #  print( $self->get_sequence_id(), $self->get_sequence(), "\n" );

    #		$self->set_tmpred_out($self->run_tmpred());

 # process tmpred output to get summary, i.e. score, begin and end positions
 # for tmh's satisfying limits.
 #		$self->set_solutions($self->good_solutions());
 #		$self->set_tmpred_out(""); # discard full tmpred output - keep only summary.
    return $self;
}

sub setup {
    my $self = shift;
    $self->set_tmpred_out( $self->run_tmpred() );

    # process tmpred output to get summary, i.e. score, begin and end positions
    # for tmh's satisfying limits.
    $self->set_solutions( $self->good_solutions() );
    $self->set_tmpred_out("");    # discard full tmpred output
}

sub set_tmpred_out {
    my $self = shift;
    $self->{tmpred_out} = shift;
}

sub get_tmpred_out {
    my $self = shift;
    return $self->{tmpred_out};
}


sub run_tmpred {
    my $self = shift;

    my $sequence_id = $self->get_sequence_id();
    my $sequence    = $self->get_sequence();
    my $limits      = $self->get_limits();
    my ( $min_score, $min_tmh_length, $max_tmh_length, $min_beg, $max_beg ) =
      @$limits;

 #   my $wd = `pwd`;
 #   my $xxx = `cat /home/tomfy/cxgn/sgn/cgi-bin/secretom/zgzgz`;
 #   print "zgzgz: $xxx \n";
    my $tmpred_out = ' '
      . 'Sequence: TMP...PLP   length:     204'
      . 'Prediction parameters: TM-helix length between 17 and 40' . ' ' . ' '
      . '1.) Possible transmembrane helices'
      . '=================================='
      . 'The sequence positions in brackets denominate the core region.'
      . 'Only scores above  500 are considered significant.' . ' '
      . 'Inside to outside helices :   5 found'
      . '      from        to    score center'
      . '  26 (  26)  43 (  43)    707     35'
      . '  89 (  89) 106 ( 106)   1604     97'
      . ' 115 ( 115) 131 ( 131)   1440    123'
      . ' 143 ( 143) 163 ( 159)   1486    151'
      . ' 169 ( 169) 187 ( 185)   2105    177' . ''
      . 'Outside to inside helices :   5 found'
      . '      from        to    score center'
      . '  25 (  25)  43 (  43)    814     33'
      . '  89 (  89) 107 ( 105)   1934     97'
      . ' 113 ( 113) 131 ( 131)   1485    121'
      . ' 143 ( 143) 161 ( 161)   1634    153'
      . ' 167 ( 169) 187 ( 185)   1964    177' . '' . '' . ' '
      . '2.) Table of correspondences'
      . '============================'
      . 'Here is shown, which of the inside->outside helices correspond'
      . 'to which of the outside->inside helices.'
      . '  Helices shown in brackets are considered insignificant.'
      . '  A "+"  symbol indicates a preference of this orientation.'
      . '  A "++" symbol indicates a strong preference of this orientation.'
      . ' '
      . '           inside->outside | outside->inside'
      . '    26-  43 (18)  707      |    25-  43 (19)  814  +   '
      . '    89- 106 (18) 1604      |    89- 107 (19) 1934 ++   '
      . '   115- 131 (17) 1440      |   113- 131 (19) 1485      '
      . '   143- 163 (21) 1486      |   143- 161 (19) 1634  +   '
      . '   169- 187 (19) 2105  +   |   167- 187 (21) 1964      ' . '' . ''
      . '3.) Suggested models for transmembrane topology'
      . '==============================================='
      . 'These suggestions are purely speculative and should be used with'
      . 'EXTREME CAUTION since they are based on the assumption that'
      . 'all transmembrane helices have been found.'
      . 'In most cases, the Correspondence Table shown above or the'
      . 'prediction plot that is also created should be used for the'
      . 'topology assignment of unknown proteins.' . ''
      . '2 possible models considered, only significant TM-segments used' . ''
      . '-----> STRONGLY prefered model: N-terminus inside'
      . ' 5 strong transmembrane helices, total score : 7820'
      . ' # from   to length score orientation'
      . ' 1   26   43 (18)     707 i-o'
      . ' 2   89  107 (19)    1934 o-i'
      . ' 3  115  131 (17)    1440 i-o'
      . ' 4  143  161 (19)    1634 o-i'
      . ' 5  169  187 (19)    2105 i-o' . ''
      . '------> alternative model'
      . ' 5 strong transmembrane helices, total score : 7353'
      . ' # from   to length score orientation'
      . ' 1   25   43 (19)     814 o-i'
      . ' 2   89  106 (18)    1604 i-o'
      . ' 3  113  131 (19)    1485 o-i'
      . ' 4  143  163 (21)    1486 i-o'
      . ' 5  167  187 (21)    1964 o-i' . '' . '';

    open FH, ">tmpred_temp.fasta";
        print FH ">", $sequence_id, "\n", $sequence, "\n";
    close FH;

    my $tmpred_dir = `which tmpred`;
    chomp $tmpred_dir;    
    $tmpred_dir =~ s/tmpred$//; chop $tmpred_dir; 
  #  print "tmpred_dir: $tmpred_dir\n";
      
        my $in_file     = -f "tmpred_temp.fasta";
        my $tmpred_file = -f "$tmpred_dir/tmpred";
        my $matrix_file = -f "$tmpred_dir/matrix.tab";
      #  print "tmpred, matrix file tests: [", $in_file, "]  ", $tmpred_file, " ", $matrix_file, "\n";

      $tmpred_out = `$tmpred_dir/tmpred  -def -in=tmpred_temp.fasta  -out=-  -par=$tmpred_dir/matrix.tab -max=$max_tmh_length  -min=$min_tmh_length`;

    return $tmpred_out;
}

sub set_sequence {
    my $self = shift;
      $self->{sequence} = shift;
  }

  sub get_sequence {
    my $self = shift;
    return $self->{sequence};
}

sub set_sequence_id {
    my $self = shift;
    $self->{sequence_id} = shift;
}

sub get_sequence_id {
    my $self = shift;
    return $self->{sequence_id};
}

sub set_limits {
    my $self = shift;
    $self->{limits} = shift;
}

sub get_limits {
    my $self = shift;
    return $self->{limits};
}

sub set_solutions {
    my $self = shift;
    $self->{solutions} = shift;
}

sub get_solutions {
    my $self = shift;
    return $self->{solutions};
}

=head2 function good_solutions()
	Synopsis: my $solution_string = $tmpred->good_solutions(); 
Arguments: none.
Returns: String of "good" solutions' (score,beg,end) info.
Description: Parses tmpred output; finds the tmhs which
are consistent with limits, and store them in a string,
    e.g.: "(2000,17,34)  (1500,12,36)".

=cut

sub good_solutions {
    my $self       = shift;
    my $tmpred_out = $self->get_tmpred_out();
    my $limits     = $self->get_limits();
    my ( $min_score, $min_tmh_length, $max_tmh_length, $min_beg, $max_beg ) =
      @$limits;
    my $solutions = "";
    my $ok        = 0;
    while ( $tmpred_out =~ /(.*?\n)/ ) {
        my $line = $1;
        $tmpred_out = substr( $tmpred_out, length $line );    #
        last  if ( $line =~ /Table of correspondences/ );
        $ok++ if ( $line =~ /Possible transmembrane helices/ );
        $ok++ if ( $line =~ /Inside to outside helices/ );
        if ( $ok == 2 ) {

            if ( $line =~
                /(\d+)\s*\(\s*(\d+)\)\s*(\d+)\s*\(\s*(\d+)\)\s*(\d+)\s*(\d+)/ )
            {
                my ( $begin, $begcore, $end, $endcore, $score, $center ) =
                  ( $1, $2, $3, $4, $5, $6 );
                my $length = $end + 1 - $begin;
                if (    $score >= $min_score
                    and $begin <= $max_beg
                    and $begin >= $min_beg
                    and $length <= $max_tmh_length
                    and $length >= $min_tmh_length )
                {
                    $solutions .= "($score,$begin,$end)  ";
                }
            }
        }
    }
    if ( $solutions eq "" ) { $solutions = "(-10000,0,0)"; }
    else                    { $solutions =~ s/(\s+)$//; }
    return $solutions;
}
1;

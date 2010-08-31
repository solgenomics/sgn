
=head1 NAME

TMpred 

=head1 DESCRIPTION

An object to run the trans-membrane helix prediction program tmpred, 
and to summarize its output.

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

use strict;
use IO::File;
use File::Temp;
use CGI ();

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
    		$self->set_tmpred_out($self->run_tmpred());
  #  print $self->get_sequence_id(), "  ", $self->get_sequence(), "\n";
 # process tmpred output to get summary, i.e. score, begin and end positions
 # for tmh's satisfying limits.

 		$self->set_solutions($self->good_solutions());
 	#	$self->set_tmpred_out(""); # discard full tmpred output - keep only summary.
    return $self;
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
    my $temp_file_dir = '/home/tomfy/tempfiles';
    my $temp_file_handle = File::Temp->new(
    TEMPLATE => 'tmpred_input_XXXXXX',
    DIR      => $temp_file_dir,
    UNLINK => 0
);
    my $temp_file = $temp_file_handle->filename;   
    print $temp_file_handle ">$sequence_id\n$sequence\n";
    $temp_file_handle->close();

    my   $tmpred_dir = "/home/tomfy/tmpred"; 
    my $tmpred_out = `$tmpred_dir/tmpred  -def -in=$temp_file  -out=-  -par=$tmpred_dir/matrix.tab -max=$max_tmh_length  -min=$min_tmh_length`;

  #  print "$tmpred_out", "\n";
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
 #   print "$min_score, $min_tmh_length, $max_tmh_length, $min_beg, $max_beg \n";
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
#    print "solutions: $solutions \n";
    if ( $solutions eq "" ) { $solutions = "(-10000,0,0)"; }
    else                    { $solutions =~ s/(\s+)$//; }
    return $solutions;
}

1;

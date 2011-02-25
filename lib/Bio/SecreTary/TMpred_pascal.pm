
=head1 NAME

Bio::SecreTary::TMpred_pascal

=head1 DESCRIPTION

This is derived from TMpred and does the same thing but uses the
old pascal code instead of perl version. Shouldn't be needed, just
exists in case we ever want to compare with the old pascal code results.

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut


package Bio::SecreTary::TMpred_pascal;


use base qw/ Bio::SecreTary::TMpred /;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	return $self;
}

sub run_tmpred { # 
my $self = shift;

# rest of arguments just get passed through to run_tmpred_setup.
my ($sequence_id, $sequence, $do_long_output) = $self->run_tmpred_setup(@_);

    my $good_solns;
    my $tmpred_raw_out = undef;

        $tmpred_raw_out = $self->run_tmpred_pascal( $sequence_id, $sequence );

        # process tmpred output to get summary,
        # i.e. score, begin and end positions for tmh's satisfying limits.
        $good_solns = ( $self->good_solutions_pascal($tmpred_raw_out) );

    return ( $good_solns, $tmpred_raw_out );
}

sub run_tmpred_pascal {    # this uses pascal code.
    my $self        = shift;
    my $sequence_id = shift;
    my $sequence    = shift;

# pascal just puts in A for X everywhere ...
#  $sequence =~ s/X/A/g;

    my $temp_file_dir    = '/home/tomfy/tempfiles';
    my $temp_file_handle = File::Temp->new(
        TEMPLATE => 'tmpred_input_XXXXXX',
        DIR      => $temp_file_dir,
        UNLINK   => 0
    );

    my $temp_file = $temp_file_handle->filename;
    print $temp_file_handle ">$sequence_id\n$sequence\n";
    $temp_file_handle->close();

    my $max_tm_length = $self->{max_tm_length};
    my $min_tm_length = $self->{min_tm_length};
    my $tmpred_dir    = "/home/tomfy/tmpred";
    my $tmpred_pascal_out =
`$tmpred_dir/tmpred  -def -in=$temp_file  -out=-  -par=$tmpred_dir/matrix.tab -max=$max_tm_length  -min=$min_tm_length`;

    return $tmpred_pascal_out;
}

=head2 function good_solutions_pascal()
	Synopsis: my $solution_string = $tmpred->good_solutions_pascal(); 
Arguments: none.
Returns: String of "good" solutions' (score,beg,end) info.
Description: Parses tmpred output; finds the tmhs which
are consistent with limits, and store them in a string,
    e.g.: "(2000,17,34)  (1500,12,36)".

=cut

sub good_solutions_pascal {
    my $self       = shift;
    my $tmpred_out = shift;

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

                if (   $length > $self->{max_tm_length}
                    or $length < $self->{min_tm_length} )
                {
                    warn "length out of allowed range: $length \n";
                }
                if (    $score >= $self->{min_score}
                    and $begin <= $self->{max_beg}
                    and $begin >= $self->{min_beg}
                    and $length <= $self->{max_tm_length}
                    and $length >= $self->{min_tm_length} )
                {
                    $solutions .= "($score,$begin,$end)  ";
                }
                else {
                  #  warn "Solution rejected in good_solutions_pascal.\n($score,$begin,$length)";
                }
            }
        }
    }

    if ( $solutions eq "" ) {
        $solutions = "(-10000,0,0)";
    }
    else {
        $solutions =~ s/(\s+)$//;
    }    # eliminate whitespace at end.
    return $solutions;
}



1;

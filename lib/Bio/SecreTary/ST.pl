#!/usr/bin/perl -w
use strict;

use Bio::SeqIO;
use Bio::SecreTary::SecreTarySelect;
use Bio::SecreTary::SecreTaryAnalyse;
use Bio::SecreTary::TMpred;

my $infile = shift;

my $cl_min_score = shift; 

my $in_method = shift || 'BioPerl';

my $trunc_length = 100;

# my $min_tm_length = 17;
# my $max_tm_length = 33;
#my ( $g1_min_score,   $g2_min_score )   = ( 1500, 900 );
my $score_threshold_diff12 = 600;    # 1500 - 900
my ( $g1_tm_start_by, $g2_tm_start_by ) = ( 30, 17 );
my ( $min_AI22, $min_Gravy22, $max_nDRQPEN22, $max_nNitrogen22, $max_nOxygen22 )
  = ( 71.304, 0.2636, 8, 34, 32 );

my ( $min_score, $min_tm_length, $max_tm_length, $min_beg, $max_beg ) =
  ( $cl_min_score || 500, 17, 33, 0, 35 );
print "# min score: $min_score \n";
# construct the TMpred object. Should be able to use defaults.
my $tmpred_obj = Bio::SecreTary::TMpred->new(
    {
        'min_score'     => $min_score,
        'min_tm_length' => $min_tm_length,
        'max_tm_length' => $max_tm_length,
        'min_beg'       => $min_beg,
        'max_beg'       => $max_beg
    }
);

# TMpred object constructed.

# get input sequences and construct a SecreTaryAnalyse object for each.
my @STAs = ();
my $STS  = Bio::SecreTary::SecreTarySelect->new(
    {
        'g1_min_tmpred_score' => 1500,
        'g2_min_tmpred_score' => 900
    }
);

if ( $in_method eq 'BioPerl' ) {
    my $input_sequences = Bio::SeqIO->new(
        -file   => "<$infile",
        -format => 'fasta'
    );
    while ( my $seqobj = $input_sequences->next_seq ) {
        my $seq_id   = $seqobj->display_id();
        my $sequence = $seqobj->seq();
        $sequence = substr( $sequence, 0, $trunc_length );
        my $STA = Bio::SecreTary::SecreTaryAnalyse->new( $seq_id, $sequence,
            $tmpred_obj );
        print $STA->get_sequence_id(), "  ", $STS->Categorize1($STA), "\n";
        push @STAs, $STA;
    }
}
else {
    open FH, "<$infile";
    my $input = '';
    while (<FH>) {
        $input .= $_;
    }

    my $id_seq_array_ref = process_input1($input);
    foreach (@$id_seq_array_ref) {
        s/\A (\S+) \s*//xms;
        my $id       = $1;
        my $sequence = $_;

        my $STA =
          Bio::SecreTary::SecreTaryAnalyse->new( $id, $sequence, $tmpred_obj );
        push @STAs, $STA;
    }
}
# exit;

# array @STAs holds STA objects for all sequences.

my $outfile = $infile . "_STpass_vs_threshold";
open FHout, ">$outfile";

# loop over score thresholds
for (
    my $g2_min_score = $min_score ;
    $g2_min_score <= 2000 ;
    $g2_min_score += 100
  )
{
    my $g1_min_score = $g2_min_score + $score_threshold_diff12;

    # Construct SecreTarySelect object, categorize all sequences.
    my $STS = Bio::SecreTary::SecreTarySelect->new(
        {
            'g1_min_tmpred_score' => $g1_min_score,
            'g2_min_tmpred_score' => $g2_min_score
        }
    );

    my $STA_predictions_ref = $STS->Categorize( \@STAs );

    my $N_sequences = scalar @$STA_predictions_ref;

    # Now sort and display results.
    my $sort_it       = 1;
    my $show_only_sp  = 0;
    my $count_pass    = 0;
    my @sort_STApreds = ($sort_it)
      ? sort {
        $b->[1] =~ / \( (-?\d+), /xms;
        my $score_b = $1;
        $a->[1] =~ / \( (-?\d+), /xms;
        my $score_a = $1;

        return $score_b <=> $score_a;
      } @$STA_predictions_ref
      : @$STA_predictions_ref;

    foreach (@sort_STApreds) {
        my $STA            = $_->[0];    # SecreTaryAnalyse object
        my $pred_sol1_sol2 = $_->[1];
        $pred_sol1_sol2 =~ /(YES|NO) \s* \( (-?\d+), /xms;

        #  print "[$pred_sol1_sol2] 1,2: [$1],[$2] \n";

        $pred_sol1_sol2 =~ / (NO|YES) \s* \( (.*) \) \s* \( (.*) \) /xms;
        my ( $prediction, $soln1, $soln2 ) = ( $1, $2, $3 );
        # if ( $g2_min_score == 900 ) {
        #     print $STA->get_sequence_id(), "  ", $prediction, "\n";
        # }
        if ( $prediction eq 'NO' ) {
            $prediction = 'NO ';
            next if ($show_only_sp);
        }
        $count_pass++ if ( $prediction eq "YES" );

        my $solution = $soln1;
        if ( $soln1 =~ /^ \s* \( (\S+) , (\S+) , (\S+) \) /xms ) {
            if ( $1 < $g1_min_score ) {
                $solution = $soln2;
            }
        }

        # print "solution: [$solution] \n";
        my ( $score, $start, $end ) = ( '        ', '      ', '      ' );
        if ( $solution =~ /^ \s* \( (\S+) , (\S+) , (\S+) \) /xms )
        {    ##   /^(.*),(.*),(.*)/ ) {
            ( $score, $start, $end ) = ( $1, $2, $3 );

            #  print $STA->get_sequence_id, "  $score  $start  $end \n";
        }
    }
    print FHout "$g2_min_score   $count_pass  ", $N_sequences - $count_pass,
      "  $N_sequences  ", $count_pass / $N_sequences, "\n";
}
exit;

# foreach (@$STA_predictions_ref) {
#     my $sta = shift @{$_};
#     print $sta->get_sequence_id(), "  ", join( "  ", @{$_} ), "\n";
# }

sub process_input {
    my $input                    = shift;
    my @fastas                   = ();
    my @id_sequence_array        = ();
    my $max_sequences_to_analyze = 3000;
    my $wscount                  = 0;
    while ( $input =~ s/(>?[^>]+)//
      ) # capture and delete an initial > (optionally) and then everything up to next >.
    {
        push @fastas, $1;
    }

    foreach my $fasta (@fastas) {
        next if ( $fasta =~ /^$/ );

        #	print "fasta $wscount: [", $fasta, "]\n";
        my $id;
        $fasta =~ s/\A \s+ //xms;    # delete initial whitespace
        if ( $fasta =~ s/\A > (\S+) [^\n]* \n //xms ) {    # line starts with >
            $id = $1;
        }
        else {
            $id = 'sequence_' . $wscount;
            $wscount++;
        }
        $fasta =~ s/\s//xmsg;      # remove whitespace from sequence;
        $fasta =~ s/\* \z//xms;    # remove final * if present.

        push @id_sequence_array, "$id $fasta";
        return \@id_sequence_array
          if ( scalar @id_sequence_array == $max_sequences_to_analyze );
    }

    return \@id_sequence_array;

}

sub process_input1 {

# process fasta input to get hash with ids for keys, sequences for values.
# expects fasta format, but can handle just sequence with no >id line, for first
# sequence only.

    my $max_sequences_to_do = 10000;
    my $input               = shift;
    my @id_sequence_array;
    my @fastas  = ();
    my $wscount = 0;

    $input =~ s/\r//g;           #remove weird line endings.
    $input =~ s/\A \s*//xms;     # remove initial whitespace
    $input =~ s/ \s* \z//xms;    # remove final whitespace
    if ( $input =~ s/\A ([^>]+) //xms )
    {                            # if >= 1 chars before first > capture them.
        my $fasta = uc $1;
        if ( $fasta =~ /\A [A-Z]+ \s* \n/xms )
        {                        # looks like sequence with no identifier
            $fasta = '>sequence_' . $wscount . "\n" . $fasta . "\n";
            push @fastas, $fasta;
            $wscount++;
        }

        # otherwise stuff ahead of first > is considered junk, discarded
    }
    while ( $input =~ s/ ( > [^>]+ )//xms
      )    # capture and delete initial > and everything up to next >.
    {
        push @fastas, $1;
        last if ( scalar @fastas >= $max_sequences_to_do );
    }

    foreach my $fasta (@fastas) {
        next if ( $fasta =~ /\A\z/xms );

        my $id;
        $fasta =~ s/\A \s+ //xms;    # delete initial whitespace
        if ( $fasta =~ s/\A > (\S+) [^\n]* \n //xms ) {    # line starts with >
            $id = $1;
        }
        else {
            $fasta =~ s/\A > \s*//xms;   # handles case of > not followed by id.
            $id = 'sequence_' . $wscount;
            $wscount++;
        }
        $fasta =~ s/\s//xmsg;            # remove whitespace from sequence;
        $fasta =~ s/\* \z//xms;          # remove final * if present.
        $fasta = uc $fasta;

        #        print " id: [$id]\n sequence: [$fasta]\n";
        push @id_sequence_array, "$id $fasta";
    }

    return \@id_sequence_array;

}

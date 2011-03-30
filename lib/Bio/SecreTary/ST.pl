#!/usr/bin/perl -w
use strict;

use Getopt::Long;
use Bio::SeqIO;
use Bio::SecreTary::SecreTarySelect;
use Bio::SecreTary::SecreTaryAnalyse;
use Bio::SecreTary::TMpred;
my $sort = '';
my $min_tmpred_score = 500;
my $in_method = 'BioPerl';
GetOptions ('sort' => \$sort, 
	    'min_tmpred_score:f' => \$min_tmpred_score,
	    'in_method:s' => \$in_method);

my $infile = shift || die "No input file specified";;

my $trunc_length = 100;
my $score_threshold_diff12 = 600; # 1500 - 900
my ( $g1_tm_start_by, $g2_tm_start_by ) = ( 30, 17 );
my ( $min_AI22, $min_Gravy22, $max_nDRQPEN22, $max_nNitrogen22, $max_nOxygen22 )
  = ( 71.304, 0.2636, 8, 34, 32 );

my ( $min_score, $min_tm_length, $max_tm_length, $min_beg, $max_beg ) =
  ( $min_tmpred_score, 17, 33, 0, 35 );
# $min_score is an argument to tmpred. tmpred outputs only solutions with
# a score at least this big. See SecreTarySelect.pm for the min tm score 
# required for a positive prediction, (presently 900 for group2, 1500 for group1
# by default.)

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
    $seq_id =~ s/\|.*//;	# delete from first pipe to end.
    my $sequence = $seqobj->seq();
    $sequence = substr( $sequence, 0, $trunc_length );
    my $STA = Bio::SecreTary::SecreTaryAnalyse->new( $seq_id, $sequence,
						     $tmpred_obj );
    my $s2 = $STS->Categorize1($STA);
    print $STA->get_sequence_id(), "  ", $s2, "\n";
    push @STAs, $STA;
  }
} else {
  open FH, "<$infile";
  my $input = '';
  while (<FH>) {
    $input .= $_;
  }
  {
    my $id_seq_array_ref = process_input1($input);
    foreach (@$id_seq_array_ref) {
      s/\A (\S+) \s*//xms;
      my $id       = $1;
      my $sequence = $_;

      my $STA =
	Bio::SecreTary::SecreTaryAnalyse->new( $id, $sequence, $tmpred_obj );
      my $s2 = $STS->Categorize1($STA);
      print $STA->get_sequence_id(), "  ", $s2, "\n";
      push @STAs, $STA;
    }
  }
}
my $STApreds = $STS->Categorize(\@STAs);
if($sort){
my @sort_STApreds = (1)
  ? sort {
    $b->[1] =~ /^ \s* (\S+) \s+ (-?[0-9.]+) /xms; # 
    my $score_b = $2;
    $a->[1] =~ /^ \s* (\S+) \s+ (-?[0-9.]+) /xms;
    my $score_a = $2;
    return $score_b <=> $score_a;
  } @$STApreds
  : @$STApreds;

foreach (@sort_STApreds) {
  print  $_->[0]->get_sequence_id(), "  ", $_->[1], "\n";
}
}



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
    $fasta =~ s/\A \s+ //xms;	# delete initial whitespace
    if ( $fasta =~ s/\A > (\S+) [^\n]* \n //xms ) { # line starts with >
      $id = $1;
    } else {
      $id = 'sequence_' . $wscount;
      $wscount++;
    }
    $fasta =~ s/\s//xmsg;	# remove whitespace from sequence;
    $fasta =~ s/\* \z//xms;	# remove final * if present.

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

  $input =~ s/\r//g;		#remove weird line endings.
  $input =~ s/\A \s*//xms;	# remove initial whitespace
  $input =~ s/ \s* \z//xms;	# remove final whitespace
  if ( $input =~ s/\A ([^>]+) //xms ) { # if >= 1 chars before first > capture them.
    my $fasta = uc $1;
    if ( $fasta =~ /\A [A-Z]+ \s* \n/xms ) { # looks like sequence with no identifier
      $fasta = '>sequence_' . $wscount . "\n" . $fasta . "\n";
      push @fastas, $fasta;
      $wscount++;
    }

    # otherwise stuff ahead of first > is considered junk, discarded
  }
  while ( $input =~ s/ ( > [^>]+ )//xms
	)  # capture and delete initial > and everything up to next >.
    {
      push @fastas, $1;
      last if ( scalar @fastas >= $max_sequences_to_do );
    }

  foreach my $fasta (@fastas) {
    next if ( $fasta =~ /\A\z/xms );

    my $id;
    $fasta =~ s/\A \s+ //xms;	# delete initial whitespace
    if ( $fasta =~ s/\A > (\S+) [^\n]* \n //xms ) { # line starts with >
      $id = $1;
    } else {
      $fasta =~ s/\A > \s*//xms; # handles case of > not followed by id.
      $id = 'sequence_' . $wscount;
      $wscount++;
    }
    $fasta =~ s/\s//xmsg;	# remove whitespace from sequence;
    $fasta =~ s/\* \z//xms;	# remove final * if present.
    $fasta = uc $fasta;

    #        print " id: [$id]\n sequence: [$fasta]\n";
    push @id_sequence_array, "$id $fasta";
  }

  return \@id_sequence_array;

}

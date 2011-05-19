#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';

# tests for Cleavage Module
use Test::More tests=> 3;
use Bio::SecreTary::Cleavage;
use Bio::SeqIO;
use File::Spec::Functions 'catfile';

$ENV{PATH} .= ':programs';	#< XXX TODO: obviate the need for this

my $id = "AT1G50920.1";
my $sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

my $cleavage_predictor_obj = Bio::SecreTary::Cleavage->new();
ok( defined $cleavage_predictor_obj, 'new() returned something.');
isa_ok( $cleavage_predictor_obj, 'Bio::SecreTary::Cleavage' );



my $predicted_sp_length = $cleavage_predictor_obj->cleavage($sequence);


# test of 115 sequences from various species.

my $fasta_infile = catfile( 't', 'data', 'AtBrRiceTomPopYST_115.fasta');


# get input sequences and get predicted signal peptide length for each
my $trunc_length = 80;
my $count_sequences_analyzed = 0;
my @cleavage_result_now = ();
my $input_sequences = Bio::SeqIO->new(
				      -file   => "<$fasta_infile",
				      -format => 'fasta'
				     );
while ( my $seqobj = $input_sequences->next_seq ) {
  my $seq_id   = $seqobj->display_id();
  $seq_id =~ s/\|.*//;		# delete from first pipe to end.
  my $sequence = $seqobj->seq();
  $sequence = substr( $sequence, 0, $trunc_length );

  my $predicted_signalpeptide_length = $cleavage_predictor_obj->cleavage($sequence);
  # print "$seq_id $predicted_signalpeptide_length\n";
	      
  push @cleavage_result_now, "$seq_id $predicted_signalpeptide_length";
}

my $cleavageout_infile = catfile( 't', 'data', 'AtBrRiceTomPopYST_115.cleavageout');

#my @cleavage_result_standard = ();
my @cleavage_result_standard = ();
if ( open my $fh, "<", $cleavageout_infile) {
  while (<$fh>) {
	chomp $_;
    push @cleavage_result_standard, $_;
  }
} else {
  die "couldn't open file $cleavageout_infile \n";
}

my $msg = 'OK';
my $OK = 1;
while (@cleavage_result_now and @cleavage_result_standard) {
  my $crn = shift @cleavage_result_now;
  my $crs = shift @cleavage_result_standard;
  if ($crn ne $crs) {
    $msg = "expected [$crs], got [$crn].";
    $OK = 0;
    last;
  }
}

ok($OK, "Check cleavage prediction for 115 sequences. Result: $msg\n");

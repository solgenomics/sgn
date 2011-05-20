#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';

# tests for Cleavage Module
use Test::More tests=> 4;
use Bio::SecreTary::Cleavage;
use Bio::SeqIO;
use File::Spec::Functions 'catfile';

$ENV{PATH} .= ':programs';	#< XXX TODO: obviate the need for this

my $id = "AT1G50920.1";
my $sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

my $cleavage_predictor_obj = Bio::SecreTary::Cleavage->new();
ok( defined $cleavage_predictor_obj, 'new() returned something.');
isa_ok( $cleavage_predictor_obj, 'Bio::SecreTary::Cleavage' );



# my $predicted_sp_length = $cleavage_predictor_obj->cleavage($sequence);


# test of 115 sequences from various species.

my $fasta_infile = catfile( 't', 'data', 'AtBrRiceTomPopYST_115.fasta');


# get input sequences and get predicted signal peptide length for each
my $trunc_length = 80;
my $count_sequences_analyzed = 0;
my @cleavage_result_now = ();
my @subdomain_result_now = ();
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

my $subdomain = join("  ", $cleavage_predictor_obj->subdomain($sequence));
push @subdomain_result_now, $subdomain; 
# print $subdomain, "\n";
}

# test cleavage site.
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
if(scalar @cleavage_result_now eq scalar @cleavage_result_standard){
while (@cleavage_result_now and @cleavage_result_standard) {
  my $crn = shift @cleavage_result_now;
  my $crs = shift @cleavage_result_standard;
  if ($crn ne $crs) {
    $msg = "expected [$crs], got [$crn].";
    $OK = 0;
    last;
  }
}
}else{
$OK = 0;
$msg = "Expected results for " . scalar @cleavage_result_standard . " sequences, got " . scalar @cleavage_result_now . ".";
}
#print "[$msg]\n";
ok($OK, "Check cleavage prediction for 115 sequences. Result: $msg\n");

# test subdomain prediction.
my $subdomainout_infile = catfile( 't', 'data', 'AtBrRiceTomPopYST_115.domainout');
my @subdomain_result_standard = ();
if ( open my $fh, "<", $subdomainout_infile) {
  while (<$fh>) {
        chomp $_;
    push @subdomain_result_standard, $_;
  }
} else {
  die "couldn't open file $subdomainout_infile \n";
}


$msg = 'OK';
$OK = 1;
if(scalar @subdomain_result_now eq scalar @subdomain_result_standard){
while(@subdomain_result_now and @subdomain_result_standard){
	my $sdrn = shift @subdomain_result_now;
my $sdrs = shift @subdomain_result_standard;

if($sdrn ne $sdrs){
	$msg = "expected [$sdrs], got [$sdrn].";
	$OK = 0;
	last;
}
}
}else{
$OK = 0;
$msg = "Expected results for " . scalar @subdomain_result_standard . " sequences, got " . scalar @subdomain_result_now . ".";
}

ok($OK, "Check subdomain prediction for 115 sequences. Result: $msg\n");


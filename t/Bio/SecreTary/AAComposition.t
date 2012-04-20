#!/usr/bin/perl -w
use strict;
use List::Util qw /min max sum/;
use warnings FATAL => 'all';

# tests for AAComposition Module
use Test::More tests=> 9;
use Bio::SecreTary::AAComposition;

$ENV{PATH} .= ':programs'; #< XXX TODO: obviate the need for this


my @aas =    ("A", "C", "D", "E", "F",
	      "G", "H", "I", "K", "L",
	      "M", "N", "P", "Q", "R",
	      "S", "T", "V", "W", "Y", "X");

my $sequence = 'MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS';

#my ($tbs_array_ref, $min_tbs, $max_tbs) = Bio::SecreTary::AAComposition::total_beta_strand($sequence, 11);
#print"tbs min, max, array: $min_tbs  $max_tbs  \n"; # , join(" ", @$tbs_array_ref), "\n";
#my ($bs_array_ref, $min_bs, $max_bs) = Bio::SecreTary::AAComposition::beta_sheet($sequence, 11);
#print"bs min, max, array: $min_bs  $max_bs  \n"; # , join(" ", @$bs_array_ref), "\n";
#my ($bt_array_ref, $min_bt, $max_bt) = Bio::SecreTary::AAComposition::beta_turn($sequence, 11);
#print"bt min, max, array: $min_bt  $max_bt \n"; # , join(" ", @$bt_array_ref), "\n";

my $aa_frequency_hashref = Bio::SecreTary::AAComposition::aa_frequencies($sequence);

my $aa_counts = aa_count_string($aa_frequency_hashref);
ok( $aa_counts eq 'A:17 C:6 D:14 E:6 F:13 G:12 H:9 I:20 K:20 L:28 M:6 N:11 P:11 Q:13 R:19 S:14 T:18 V:20 W:0 Y:17 X:0', 'aa_frequencies gives correct amino acid counts');

my $pI_tolerance = 0.001;
my @pIs = ();
foreach ( (0..13) ){
my $pI_guess = $_ + 0.5;
push @pIs, Bio::SecreTary::AAComposition::isoelectric_point($aa_frequency_hashref, $pI_guess);
}
my $avg_pI = sum(@pIs)/(scalar @pIs);
my ($min_pI, $max_pI) = (min(@pIs), max(@pIs));
ok(abs($avg_pI - 10.2429504394531) < $pI_tolerance, 'Check pI gives good value.');
ok($max_pI - $min_pI < $pI_tolerance, 'Check dependence of pI result on initial guess.');

my $AI = Bio::SecreTary::AAComposition::aliphatic_index($sequence);
my $Gravy =  Bio::SecreTary::AAComposition::gravy($sequence);
my ($AI_tol, $Gravy_tol) = (0.01, 0.001);
ok(abs($AI - 95.69) < $AI_tol, 'Check aliphatic index value.');
ok(abs($Gravy - (-0.149)) < $Gravy_tol, 'Check gravy value.');

my $nDRQPEN = Bio::SecreTary::AAComposition::nDRQPEN($sequence);
my $nGASDRQPEN = Bio::SecreTary::AAComposition::nGASDRQPEN($sequence);
my $nNitrogen = Bio::SecreTary::AAComposition::nNitrogen($sequence);
my $nOxygen = Bio::SecreTary::AAComposition::nOxygen($sequence);

ok($nDRQPEN == 74, 'Check DRQPEN count');
ok($nGASDRQPEN == 117, 'Check GASDRQPEN count');
ok($nNitrogen == 393, 'check Nitrogen count.');
ok($nOxygen == 387, 'Check Oxygen count.'); # only includes 1 Oxygen in C-terminal COOH (because we use it for counting O in an n-terminal partial sequence, which includes no C-terminus.
sub aa_count_string{ # return a string with counts of various amino acids
#  my $sequence = shift;
  my $aa_frequency_hashref = shift; #Bio::SecreTary::AAComposition::aa_frequencies($sequence);
  my $aa_counts = '';
  foreach (@aas) {
    my $count = (defined $aa_frequency_hashref->{$_})? $aa_frequency_hashref->{$_}: 0;
    $aa_counts .=  $_ . ":" . $count . " "; 
  }
  $aa_counts =~ s/\s+$//;
  return $aa_counts;
}

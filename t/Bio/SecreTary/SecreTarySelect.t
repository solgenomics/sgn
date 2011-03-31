#!/usr/bin/perl -w 
use strict;
use warnings FATAL => 'all';

# tests for TMpred Module
use Test::More tests=> 20;
use Bio::SecreTary::TMpred;
use Bio::SecreTary::Helix;
use Bio::SecreTary::SecreTaryAnalyse;
use Bio::SecreTary::SecreTarySelect;

$ENV{PATH} .= ':programs'; #< XXX TODO: obviate the need for this

my $TMpred_obj = Bio::SecreTary::TMpred->new();

### case 1 a sequence which is predicted to have a signal peptide (group 1).

my $id = "AT1G75120.1";
my $sequence = "MAVRKEKVQPFRECGIAIAVLVGIFIGCVCTILIPNDFVNFRSSKVASASCESPERVKMFKAEFAIISEKNGELRKQVS
DLTEKVRLAEQKEVIKAGPFGTVTGLQTNPTVAPDESANPRLAKLLEKVAVNKEIIVVLANNNVKPMLEVQIASVKRVG
IQNYLVVPLDDSLESFCKSNEVAYYKRDPDNAIDVVGKSRRSSDVSGLKFRVLREFLQLGYGVLLSDVDIVFLQNPFGH
LYRDSDVESMSDGHDNNT";

my $STA_obj = Bio::SecreTary::SecreTaryAnalyse->new($id, $sequence, $TMpred_obj);

my $STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

my ($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

#  print "$g1_best, $g2_best \n";
ok($g1_best eq '2479,17,35,5,0.8875', 'Check group1 best solution (case 2).');
ok($g2_best eq '2479,17,35,5,0.76875', 'Check group2 best solution (case 2).');

my $categorize1_output = $STS_obj->Categorize1($STA_obj);

ok($categorize1_output eq 'group1 0.8875 2479 17 35 5 0.8875', 'Check categorize1 output (case 2).');
# print $categorize1_output, "\n";




### case 2 - a sequence which is predicted to have a signal peptide, group 2.

$id = 'SlTFR12';
$sequence = 'MEMSSKIACFIVLCMIVVAPHGEALSCGQVESGLAPCLPYPQGKGPLGGCCRGVKGLLGAAK';

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new($id, $sequence, $TMpred_obj);

$STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

ok($g1_best eq '1453,3,25,8,0.73825', 'Check group1 best solution (case 2).');
ok($g2_best eq '1453,3,25,8,0.7875', 'Check group2 best solution (case 2).');

$categorize1_output = $STS_obj->Categorize1($STA_obj);

ok($categorize1_output eq 'group2 0.7875 1453 3 25 8 0.7875', 'Check categorize1 output (case 2).');


### case 3 - a sequence which is predicted to have no signal peptide, but close

$id = 'SlTFR80';
$sequence = 'MLDRFLSARRAWQVRRIMRNGKLTFLCLFLTVIVLRGNLGAGRFGTPGQDLKEIRETFSYYR';

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new($id, $sequence, $TMpred_obj);

$STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

ok($g1_best eq '1279,20,41,7,0.69475', 'Check group1 best solution (case 2).');
ok($g2_best eq '-1,0,0,-1,0', 'Check group2 best solution (case 2).');

$categorize1_output = $STS_obj->Categorize1($STA_obj);

ok($categorize1_output eq 'fail 0.69475 1279 20 41 7 0.69475', 'Check categorize1 output (case 2).');





### case 4  - a sequence which is predicted to have no signal peptide, not close (no tmh found)

$id = "AT1G50920.1";
$sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new($id, $sequence, $TMpred_obj);

$STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

ok($g1_best eq '-1,0,0,-1,0', 'Check group1 best solution (case 2).');
ok($g2_best eq '-1,0,0,-1,0', 'Check group2 best solution (case 2).');

$categorize1_output = $STS_obj->Categorize1($STA_obj);

ok($categorize1_output eq 'fail 0 -1 0 0 -1 0', 'Check categorize1 output (case 2).');




#!/usr/bin/perl -w 
use strict;
use warnings FATAL => 'all';

# tests for TMpred Module
use Test::More tests=> 8;
use Bio::SecreTary::TMpred;
use Bio::SecreTary::Helix;
use Bio::SecreTary::SecreTaryAnalyse;

$ENV{PATH} .= ':programs'; #< XXX TODO: obviate the need for this

my $TMpred_obj = Bio::SecreTary::TMpred->new();

my $id = "AT1G75120.1";
my $sequence = "MAVRKEKVQPFRECGIAIAVLVGIFIGCVCTILIPNDFVNFRSSKVASASCESPERVKMFKAEFAIISEKNGELRKQVS
DLTEKVRLAEQKEVIKAGPFGTVTGLQTNPTVAPDESANPRLAKLLEKVAVNKEIIVVLANNNVKPMLEVQIASVKRVG
IQNYLVVPLDDSLESFCKSNEVAYYKRDPDNAIDVVGKSRRSSDVSGLKFRVLREFLQLGYGVLLSDVDIVFLQNPFGH
LYRDSDVESMSDGHDNNT";

my $STA_obj = Bio::SecreTary::SecreTaryAnalyse->new($id, $sequence, $TMpred_obj);
ok( defined $STA_obj, 'new() returned something.');

isa_ok( $STA_obj, 'Bio::SecreTary::SecreTaryAnalyse' );

my $solns = $STA_obj->get_candidate_solutions();
my $solns_string = '';
foreach (@$solns){
	 $solns_string .= "$_; ";
}

ok($solns_string eq '2479,17,35,5; 2512,15,33,5; ', 'Check transmembrane solutions (case 1).');
my $AA22str = $STA_obj->AA22string();
ok($AA22str eq '119.545454545455 0.586363636363637 6 31 27', 'Check N-terminal amino-acid composition parameters (case 1).');



$id = "AT1G50920.1";
$sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new($id, $sequence, $TMpred_obj);
ok( defined $STA_obj, 'new() returned something.');
isa_ok( $STA_obj, 'Bio::SecreTary::SecreTaryAnalyse' );

$solns = $STA_obj->get_candidate_solutions();
$solns_string = '';
foreach (@$solns){
         $solns_string .= "$_; ";
}

ok($solns_string eq '-10000,0,0,1; ', 'Check transmembrane solutions (case 2).');
$AA22str = $STA_obj->AA22string();
ok($AA22str eq '105.909090909091 0.181818181818182 7 30 31', 'Check N-terminal amino-acid composition parameters (case 2).');


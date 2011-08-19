#!/usr/bin/perl -w 
use strict;
use warnings FATAL => 'all';

# tests for SecreTaryAnalyse Module
use Test::More tests=> 13;
use Bio::SecreTary::TMpred;
use Bio::SecreTary::Helix;
use Bio::SecreTary::SecreTaryAnalyse;
use Bio::SecreTary::Cleavage;

$ENV{PATH} .= ':programs'; #< XXX TODO: obviate the need for this

my ($AI_tol, $Gravy_tol) = (0.01, 0.001);

my $TMpred_obj = Bio::SecreTary::TMpred->new();
my $cleavage_predictor_obj = Bio::SecreTary::Cleavage->new();
my $id = "AT1G75120.1";
my $sequence = "MAVRKEKVQPFRECGIAIAVLVGIFIGCVCTILIPNDFVNFRSSKVASASCESPERVKMFKAEFAIISEKNGELRKQVS
DLTEKVRLAEQKEVIKAGPFGTVTGLQTNPTVAPDESANPRLAKLLEKVAVNKEIIVVLANNNVKPMLEVQIASVKRVG
IQNYLVVPLDDSLESFCKSNEVAYYKRDPDNAIDVVGKSRRSSDVSGLKFRVLREFLQLGYGVLLSDVDIVFLQNPFGH
LYRDSDVESMSDGHDNNT";

my $STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({
		sequence_id => $id, 
		sequence => $sequence, 
		tmpred_obj => $TMpred_obj,
		cleavage_predictor => $cleavage_predictor_obj
		});
ok( defined $STA_obj, 'new() returned something.');

isa_ok( $STA_obj, 'Bio::SecreTary::SecreTaryAnalyse' );

my $solns = $STA_obj->candidate_solutions();
my $solns_string = '';
foreach (@$solns){
	$solns_string .= "$_; ";
}

ok($solns_string eq '2479,17,35,5; 2512,15,33,5; ', 'Check transmembrane solutions (case 1).');
my $AA22str = $STA_obj->aa22string();
ok($AA22str =~ /^ [-0-9.]+ \s+ [-0-9.]+ \s+ [0-9]+ \s+ [0-9]+ \s+ [0-9]+ $/xms, 'Check form of string returned by aa22string.');
my ($AI, $Gravy, $nDRQPEN, $nN, $nO) = split(" ", $AA22str);
ok(abs($AI - 119.545454545455) < $AI_tol, 'Check aliphatic index value.');
ok(abs($Gravy - 0.586363636363637) < $Gravy_tol, 'Check Gravy value.');
ok($nDRQPEN == 6, 'Check nDRQPEN value');
ok($nN == 31, 'Check Nitrogen count.');
ok($nO == 27,'Check Oxygen count.');




$id = "AT1G50920.1";
$sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({
		sequence_id => $id, 
		sequence => $sequence, 
		tmpred_obj => $TMpred_obj,
		cleavage_predictor => $cleavage_predictor_obj
		});
ok( defined $STA_obj, 'new() returned something.');
isa_ok( $STA_obj, 'Bio::SecreTary::SecreTaryAnalyse' );

$solns = $STA_obj->candidate_solutions();
$solns_string = '';
foreach (@$solns){
	$solns_string .= "$_; ";
}

ok($solns_string eq '-10000,0,0,1; ', 'Check transmembrane solutions (case 2).');
$AA22str = $STA_obj->aa22string();
ok($AA22str =~ /^105.9090909090[0-9]* 0.1818181818181[0-9]* 7 30 31$/, 'Check N-terminal amino-acid composition parameters (case 2).');


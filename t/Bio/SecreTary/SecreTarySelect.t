#!/usr/bin/perl -w 
use strict;
use warnings FATAL => 'all';

# tests for TMpred Module
use Test::More tests=> 21;
use Bio::SeqIO;
use Bio::SecreTary::TMpred;
# use Bio::SecreTary::Helix;
use Bio::SecreTary::Cleavage;
use Bio::SecreTary::SecreTaryAnalyse;
use Bio::SecreTary::SecreTarySelect;
use File::Spec::Functions 'catfile';

$ENV{PATH} .= ':programs'; #< XXX TODO: obviate the need for this

my $TMpred_obj = Bio::SecreTary::TMpred->new();
my $cleavage_predictor_obj = Bio::SecreTary::Cleavage->new(); # _Cinline->new();
### case 1 a sequence which is predicted to have a signal peptide (group 1).

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

my $STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

my ($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

#  print "$g1_best, $g2_best \n";
ok($g1_best =~ /^2479,17,35,5,0.887[456][0-9]*$/, 'Check group1 best solution (case 1).');
ok($g2_best =~ /^2479,17,35,5,0.7687[456][0-9]*$/, 'Check group2 best solution (case 1).');

my $categorize1_output = $STS_obj->categorize1($STA_obj);

ok($categorize1_output =~ /^group1 0.887[456][0-9]* 2479 17 35 5 0.887[456][0-9]*$/, 'Check categorize1 output (case 1).');
# print $categorize1_output, "\n";




### case 2 - a sequence which is predicted to have a signal peptide, group 2.

$id = 'SlTFR12';
$sequence = 'MEMSSKIACFIVLCMIVVAPHGEALSCGQVESGLAPCLPYPQGKGPLGGCCRGVKGLLGAAK';

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({
		sequence_id => $id,
		sequence => $sequence,
		tmpred_obj => $TMpred_obj,
		cleavage_predictor => $cleavage_predictor_obj
		});

#$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({sequence_id => $id, sequence => $sequence, tmpred_obj => $TMpred_obj});

$STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

ok($g1_best =~ /^1453,3,25,8,0.7382[456][0-9]*$/, 'Check group1 best solution (case 2).');
ok($g2_best =~ /^1453,3,25,8,0.787[456][0-9]*$/, 'Check group2 best solution (case 2).');

$categorize1_output = $STS_obj->categorize1($STA_obj);

ok($categorize1_output =~ /^group2 0.787[456][0-9]* 1453 3 25 8 0.787[456][0-9]*$/, 'Check categorize1 output (case 2).');


### case 3 - a sequence which is predicted to have no signal peptide, but close

$id = 'SlTFR80';
$sequence = 'MLDRFLSARRAWQVRRIMRNGKLTFLCLFLTVIVLRGNLGAGRFGTPGQDLKEIRETFSYYR';

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({
		sequence_id => $id,
		sequence => $sequence,
		tmpred_obj => $TMpred_obj,
		cleavage_predictor => $cleavage_predictor_obj
		});

#$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({ sequence_id => $id, sequence => $sequence, tmpred_obj => $TMpred_obj});

$STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

ok($g1_best =~ /^1279,20,41,7,0.6947[456][0-9]*$/, 'Check group1 best solution (case 3).');
ok($g2_best =~ /^-1,0,0,-1,0$/, 'Check group2 best solution (case 3).');

$categorize1_output = $STS_obj->categorize1($STA_obj);

ok($categorize1_output =~ /^fail 0.6947[456][0-9]* 1279 20 41 7 0.6947[456][0-9]*$/, 'Check categorize1 output (case 3).');





### case 4  - a sequence which is predicted to have no signal peptide, not close (no tmh found)

$id = "AT1G50920.1";
$sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({
		sequence_id => $id,
		sequence => $sequence,
		tmpred_obj => $TMpred_obj,
		cleavage_predictor => $cleavage_predictor_obj
		});

#$STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({ sequence_id => $id, sequence => $sequence, tmpred_obj => $TMpred_obj});

$STS_obj = Bio::SecreTary::SecreTarySelect->new(); # using defaults
ok( defined $STS_obj, 'new() returned something.');

isa_ok( $STS_obj, 'Bio::SecreTary::SecreTarySelect' );

($g1_best, $g2_best) = $STS_obj->refine_solutions($STA_obj);

ok($g1_best =~ /^-1,0,0,-1,0$/, 'Check group1 best solution (case 4).');
ok($g2_best =~ /^-1,0,0,-1,0$/, 'Check group2 best solution (case 4).');

$categorize1_output = $STS_obj->categorize1($STA_obj);

ok($categorize1_output =~ /^fail 0 -1 0 0 -1 0$/, 'Check categorize1 output (case 4).');


# test of 115 sequences from various species.

my $fasta_infile = catfile( 't', 'data', 'AtBrRiceTomPopYST_115.fasta');
my $stout_infile = catfile( 't', 'data', 'AtBrRiceTomPopYST_115.stout');

my @category_result_standard = ();

if( open my $fh, "<", $stout_infile){
	while(<$fh>){
		push @category_result_standard, $_;
	}
}else{
	die "couldn't open file $stout_infile \n";
}

# get input sequences and construct a SecreTaryAnalyse object for each.

$STS_obj  = Bio::SecreTary::SecreTarySelect->new();

my $trunc_length = 80;
my $count_sequences_analyzed = 0;
my @category_result_now = ();
{
	my $input_sequences = Bio::SeqIO->new(
			-file   => "<$fasta_infile",
			-format => 'fasta'
			);
	while ( my $seqobj = $input_sequences->next_seq ) {
		my $seq_id   = $seqobj->display_id();
		$seq_id =~ s/\|.*//;	# delete from first pipe to end.
			my $sequence = $seqobj->seq();
		$sequence = substr( $sequence, 0, $trunc_length );

		my $STA = Bio::SecreTary::SecreTaryAnalyse->new({
				sequence_id => $seq_id,
				sequence => $sequence,
				tmpred_obj => $TMpred_obj,
				cleavage_predictor => $cleavage_predictor_obj
				});

#	my $STA = Bio::SecreTary::SecreTaryAnalyse->new( {sequence_id => $seq_id, sequence => $sequence, tmpred_obj => $TMpred_obj} );
		my $cat_result = $STS_obj->categorize1($STA);

# print $STA->sequence_id(), "  ", $cat_result, "\n";
		push @category_result_now, $STA->sequence_id() . "  " . $cat_result . "\n";

		$count_sequences_analyzed++;
	}
}

my ($count_exact, $count_good_enough, $count_bad) = (0, 0, 0);
my $size_diff = abs( scalar @category_result_now - scalar @category_result_standard);
while(@category_result_now and @category_result_standard){
	my $line_now = shift @category_result_now ;
	my $line_std = shift @category_result_standard ;
	$line_now =~ s/\s+$//; # remove final whitespace
		$line_std =~ s/\s+$//; # remove final whitespace
		if( $line_now eq $line_std ){
			$count_exact++;
		}
	elsif (compare_categorize1_results($line_now, $line_std) == 0) {
#	print "categorize output string agreement is close but not exact.\n";
#	print "this line: [$line_now]\n", "std_line : [$line_std]\n";	
		$count_good_enough++;
	}else{
		$count_bad++;
	}
}
# print "$count_exact, $count_good_enough, $count_sequences_analyzed \n";
my $OK = (($count_sequences_analyzed == ($count_exact + $count_good_enough)) and ($count_bad == 0));
ok($OK, 'Check SecreTarySelect::categorize1 results for 115 sequences.');

#ok($count_bad == 0, 'Check SecreTarySelect::categorize1 results for 115 sequences.');


sub compare_categorize1_results{
	my @r1 = split(" ", shift);
	my @r2 = split(" ", shift);
	my $STscore_tolerance = 0.001;
	if ( join("", @r1[0,1,3,4,5,6]) ne join("", @r2[0,1,3,4,5,6])){ return 1; } # 
		if( ( abs($r1[2] - $r2[2]) > $STscore_tolerance ) or ( abs($r1[7] - $r2[7]) > $STscore_tolerance) ){ return 2; }
	return 0; # they are the same (close enough in the case of the STscores.
			}



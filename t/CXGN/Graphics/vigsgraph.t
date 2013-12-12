
use strict;

use Test::More qw | no_plan |;
use Data::Dumper;
use CXGN::Graphics::VigsGraph;

my $vg = CXGN::Graphics::VigsGraph->new();

# 1. check VigsGraph is defined
ok( defined($vg), "VigsGraphs defined test" );
# 2. check VigsGraph object
ok( $vg->isa('CXGN::Graphics::VigsGraph'), "VigsGraph object test" );

# get bowtie2 test file
$vg->bwafile('t/data/vigstool/bt2_test');

$vg->query_seq(<<SEQ);
ATGGAGGAAGTAACCAATGTCATGGAGTATGAGGCCATTGCCAAGAAAAAGTTGCCAAAGATGGTTTTTGACTACTATGCCTCTGGTGCTGAAGACCAGTGGACTCTGGCTGAGAACAGAAATGCCTTCTCAAGAATTCTGTTTAGGCCCCGTATTCTAATTGATGTGAGCAAAATTGACATGAGCACCACTGTGCTAGGATTCAAGATTTCAATGCCTATCATGATTGCACCAACAGCCATGCAGAAAATGGCACATCCTGAAGGGGAGTATGCTACAGCAAGAGCAGCATCAGCAGCAGGGACAATCATGACATTGTCATCTTGGGCCACTTCCAGTGTCGAGGAGGTTGCTTCAACAGGACCTGGCATCCGTTTCTTCCAGCTTTATGTCTACAAGGACAGGAATGTTGTTGCTCAGCTTGTGCGAAGAGCTGAAAGAGCAGGTTTCAAGGCTATAGCCCTCACTGTTGATACCCCAAGGCTGGGACGTAGAGAAGCTGATATTAAGAACAGATTTGTTTTGCCACCATTTTTGACGTTGAAAAACTTTGAAGGATTGGACCTTGGCAAGATGGACCAAGCAAGTGACTCTGGATTAGCTTCATATGTTGCTGGTCAAATTGATCGCACTCTGAGTTGGAAGGATGTTCAGTGGCTCCAGACTATCACTTCATTGCCAATCCTGGTAAAGGGTGTACTTACGGCTGAGGATGCTAGGCTTGCAGTTCAGGCTGGAGCAGCTGGTATCATTGTGTCAAACCATGGTGCTCGCCAACTCGATTATGTCCCTTCGACAATCATGGCTCTTGAAGAGGTTGTGAAAGCTGCACAAGGCCGGATTCCTGTATTCTTGGATGGAGGTGTCCGCCGTGGAACAGATGTCTTCAAAGCTTTGGCACTTGGAGCTTCAGGCATTTTCATTGGAAGGCCAGTAGTTTTCTCATTAGCTGCTGAAGGAGAAGCTGGAATCAAAAAAGTGTTGCAAATGTTGCGCGATGAGTTTGAGCTAACTATGGCATTGAGTGGCTGCCGCTCACTGAACGAGATTACCCGCAACCATATTGTCACTGAGTGGGATGCTCCACGTGCTGCTCTTCCAGCCCCAAGGTTGTGA
SEQ

# 3. check parse bowtie2 file
ok( ref($vg->parse()), "parse result test");

my $matches = $vg->matches();

# 4. check matches found in parse (number of subjects)
is(scalar(keys(%$matches)), 7, "all subjects count");

#$vg->seq_window_size(200);
##my @seqs = $vg->get_best_vigs_seqs(1);

#my ($best, $regions) = $vg->get_best_coverage();
my $coverage = $vg->get_best_coverage();
# 5. check coverage value
is($coverage, 2, "coverage test (target subjects)");

# check target_graph
my @targets = $vg->target_graph(1);

# 6. check a mapped target position with coverage=1 
is($targets[100], 1, "targets, test a one target position");
# 7. check a not mapped target position with coverage=1 
is($targets[1000], undef, "targets, test a not covered region");

@targets = $vg->target_graph(2);

# 8. check a mapped position with 2 targets and coverage=2 
is($targets[500], 2, "targets, test a two target position");
# 9. check a mapped position with 1 target and coverage=2 
is($targets[200], 1, "targets, test a one target position with a coverage velue=2");

# check off_target_graph
my @off_targets = $vg->off_target_graph(2);
#print STDERR join ",", @off_targets;

# 10. check a position without off_targets
is($off_targets[100], undef, "off targets, in a position without off targets");
# 11. check a position with 3 off targets
is($off_targets[360], 3, "off targets, in a position with 3 off targets");

@off_targets = $vg->off_target_graph(1);
# 12. check a position with off targets and coverage=1
is($off_targets[360], 4, "off targets, in a position with coverage=1");

#print STDERR "\n";

# check longest_vigs_sequence
my @regions = $vg ->longest_vigs_sequence(2,1116);
#print Dumper(\@regions);

# 13. check best region start
is($regions[4], 377, "best region start coord test");
# 14. check best region end
is($regions[5], 676, "best region end coord test");

# 15. check score value
is($regions[1], 366, "score test");

# only one target match
@regions = $vg ->longest_vigs_sequence(3,1116);

# 16. check best region start when coverage=3
is($regions[4], 587, "three target best region start test");
# 17. check best region end when coverage=3
is($regions[5], 886, "three target best region end test");



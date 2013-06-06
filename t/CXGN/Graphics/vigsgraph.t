
use strict;

use Test::More qw | no_plan |;
use Data::Dumper;
use CXGN::Graphics::VigsGraph;

my $vg = CXGN::Graphics::VigsGraph->new();
ok( defined($vg), "VigsGraphs defined test" );
ok( $vg->isa('CXGN::Graphics::VigsGraph'), "VigsGraph object test" );

# get bowtie2 test file
$vg->bwafile('t/data/vigstool/bt2_test');

$vg->query_seq(<<SEQ);
ATGGAGGAAGTAACCAATGTCATGGAGTATGAGGCCATTGCCAAGAAAAAGTTGCCAAAGATGGTTTTTGACTACTATGCCTCTGGTGCTGAAGACCAGTGGACTCTGGCTGAGAACAGAAATGCCTTCTCAAGAATTCTGTTTAGGCCCCGTATTCTAATTGATGTGAGCAAAATTGACATGAGCACCACTGTGCTAGGATTCAAGATTTCAATGCCTATCATGATTGCACCAACAGCCATGCAGAAAATGGCACATCCTGAAGGGGAGTATGCTACAGCAAGAGCAGCATCAGCAGCAGGGACAATCATGACATTGTCATCTTGGGCCACTTCCAGTGTCGAGGAGGTTGCTTCAACAGGACCTGGCATCCGTTTCTTCCAGCTTTATGTCTACAAGGACAGGAATGTTGTTGCTCAGCTTGTGCGAAGAGCTGAAAGAGCAGGTTTCAAGGCTATAGCCCTCACTGTTGATACCCCAAGGCTGGGACGTAGAGAAGCTGATATTAAGAACAGATTTGTTTTGCCACCATTTTTGACGTTGAAAAACTTTGAAGGATTGGACCTTGGCAAGATGGACCAAGCAAGTGACTCTGGATTAGCTTCATATGTTGCTGGTCAAATTGATCGCACTCTGAGTTGGAAGGATGTTCAGTGGCTCCAGACTATCACTTCATTGCCAATCCTGGTAAAGGGTGTACTTACGGCTGAGGATGCTAGGCTTGCAGTTCAGGCTGGAGCAGCTGGTATCATTGTGTCAAACCATGGTGCTCGCCAACTCGATTATGTCCCTTCGACAATCATGGCTCTTGAAGAGGTTGTGAAAGCTGCACAAGGCCGGATTCCTGTATTCTTGGATGGAGGTGTCCGCCGTGGAACAGATGTCTTCAAAGCTTTGGCACTTGGAGCTTCAGGCATTTTCATTGGAAGGCCAGTAGTTTTCTCATTAGCTGCTGAAGGAGAAGCTGGAATCAAAAAAGTGTTGCAAATGTTGCGCGATGAGTTTGAGCTAACTATGGCATTGAGTGGCTGCCGCTCACTGAACGAGATTACCCGCAACCATATTGTCACTGAGTGGGATGCTCCACGTGCTGCTCTTCCAGCCCCAAGGTTGTGA
SEQ

# check parse bowtie2 file
ok( ref($vg->parse()), "parse result test");

my $matches = $vg->matches();

# check matches found in parse
is(scalar(keys(%$matches)), 7, "all subjects count");

#$vg->seq_window_size(200);
##my @seqs = $vg->get_best_vigs_seqs(1);

my ($best, $regions) = $vg->get_best_coverage();

is($best, 2, "coverage test (target subjects)");

$vg->render("/tmp/vigs_test.png", 1);

ok(-s "/tmp/vigs_test.png" > 0, "image file size");

# check target_graph
my @targets = $vg->target_graph(1);
#print STDERR join ",", @targets;
is($targets[1], 1, "target array test 1");
is($targets[22], 21, "target array test 2");
is($targets[-1], 1, "target array test 3");

# check off_target_graph
my @off_targets = $vg->off_target_graph(1);
#print STDERR join ",", @off_targets;
is($off_targets[0], undef, "off target array test 1");
is($off_targets[500], 23, "off target array test 2");
is($off_targets[-1], 1, "off target array test 3");

#print STDERR "\n";

# check longest_vigs_sequence
my @regions = $vg ->longest_vigs_sequence(2);
#print Dumper(\@regions);

is($regions[0]->[4], 1026, "best region start coord test");
is($regions[0]->[5], 1115, "best region end coord test");

# only one target match
my @regions = $vg ->longest_vigs_sequence(1);

is($regions[0]->[4], 159, "one target best region start test");
is($regions[0]->[5], 214, "one target best region end test");









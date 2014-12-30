
use strict;
use Test::More;

use CXGN::Genotype;

my $gt = CXGN::Genotype->new();

$gt->from_json(' { "marker1" : "0", "marker2" : "0", "marker3" : "1", "marker4" :"2", "marker5" :"0.9" } ');

my $markers = $gt->markers();

is(scalar(@$markers), 5, "marker number test");

my $gt2 = CXGN::Genotype->new();

$gt2->from_json(' { "marker1" : "0", "marker3" : "1", "marker4" :"1", "marker5" :"0.9", "marker6": "0" } ');

is($gt->calculate_distance($gt2), 0.75, "distance calculation test");
is($gt->good_score('0.0'), 1, "good score test 1");
is($gt->good_score('1.1'), 1, "good score test 2");
is($gt->good_score('2'), 1, "good score test 3");
is($gt->good_score(-2), 0, "good score test 4");
is($gt->good_score(3), 0, "good score test 5");
is($gt->good_score('NA'), 0, "good score test 3");
is($gt->good_score(undef), 0, "good score test 4");
is($gt->good_score('?'), 0, "good score test 5");
is($gt->scores_are_equal('0', '0'), 1, "scores are equal test 1");
is($gt->scores_are_equal('1.1', '1.2'), 1, "scores are equal test 2");
is($gt->scores_are_equal(undef, '0'), 0, "scores are equal test 3");
is($gt->scores_are_equal(undef, undef), 0, "scores are equal test 4");
is($gt->scores_are_equal('NA', 'NA'), 0, "scores are equal test 5");
is($gt->scores_are_equal('?', '?'), 0, "scores are equal test 6");


done_testing();

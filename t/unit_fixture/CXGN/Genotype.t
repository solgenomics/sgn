
use strict;
use Test::More;
use Data::Dumper;

use lib 't/lib';
use SGN::Test::Fixture;

use Storable 'dclone'; # create deep copy of a hash

use CXGN::Genotype;

my $f = SGN::Test::Fixture->new();

my $schema = $f->bcs_schema();

my $gt1 = CXGN::Genotype->new( { genotypeprop_id=> 1708, bcs_schema=>$schema});

my $gt2 = CXGN::Genotype->new( { genotypeprop_id=> 1709, bcs_schema=>$schema});

my $dist2 = $gt1->calculate_distance($gt1);

print STDERR "Self distance is $dist2\n";



my $gt1_markers = $gt1->markerscores();



my $gt3_markers = dclone($gt1_markers);

print STDERR "BEFORE GT3 MARKERS=".Dumper(\%$gt3_markers);

my $zeroes;
my $ones;
my $twos;
my $undefs;

foreach my $m (keys(%$gt3_markers)) { 
    print STDERR "Changing marker $m ... ".$gt3_markers->{$m}->{DS}."\n";
    if ($gt3_markers->{$m}->{DS} == 0) { 
	$gt3_markers->{$m}->{DS} = 2;
	$zeroes++;
    }
    elsif ($gt3_markers->{$m}->{DS} == 1) { 
	$gt3_markers->{$m}->{DS} = 2;
	$ones++;
    }
    elsif ($gt3_markers->{$m}->{DS} == 2) { 
	$gt3_markers->{$m}->{DS} = 0;
	$twos++;
    }
    elsif ($gt3_markers->{$m}->{DS} == undef) { 
	$gt3_markers->{$m}->{DS} = 1;
	$undefs++;
    }
    print STDERR "Changed marker $m ... ".$gt3_markers->{$m}->{DS}."\n";
}


print STDERR "0s: $zeroes. 1s: $ones. 2s: $twos. undef: $undefs\n";

print STDERR "AFTER GT3 MARKERS=".Dumper(\%$gt3_markers);
my $gt3 = CXGN::Genotype->new();
$gt3->markerscores($gt3_markers);

if (is_deeply($gt3_markers, $gt1_markers)) { 
    print STDERR "They are the same!\n";
}


my $dist3 = $gt1->calculate_distance($gt3);

print STDERR "Distance with changes: $dist3\n";




my $dist = $gt1->calculate_distance($gt2);

print STDERR  "The distance is $dist\n";



#print STDERR join(",", @{$gt1->markers});

print STDERR "Done!\n";
exit();



my $rs = $schema->resultset("Genetic::Genotypeprop")->search( { genotypeprop_id=> { -in => [ 1708, 1709 ] } });

my @gt;

@gt = map { $_->value } $rs->all();
#foreach my $gt ($rs->all()) { 
#    push @gt, $gt->value();
#}

print STDERR Dumper(\@gt);




    
    



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

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/ajax/search/trials?nd_geolocation=not_provided' );
$response = decode_json $mech->content;
#print STDERR Dumper $response;

my $data = $response->{data};
my @removed_last_val;
foreach (@$data){
    pop @$_;
    push @removed_last_val, $_;
}
print STDERR Dumper \@removed_last_val;

#is_deeply(\@removed_last_val, [['<a href="/breeders_toolbox/trial/165">CASS_6Genotypes_Sampling_2015</a>','Copy of trial with postcomposed phenotypes from cassbase.','<a href="/breeders/program/134">test</a>','','2017','test_location','Preliminary Yield Trial','RCBD','',''],['<a href="/breeders_toolbox/trial/140">Ibadan_Crosses_2018 - 2</a>','Crosses germplasm X and Y','<a href="/breeders/program/134">test</a>','','2015','test_location',undef,undef,'',''],['<a href="/breeders_toolbox/trial/139">Kasese solgs trial</a>','This is a yield study for Spring 2018','<a href="/breeders/program/134">test</a>','<a href="/folder/168">Peru Yield Trial 2020-1</a>','2014','test_location','phenotyping_trial','CO_715:0000145','2018-January-01','2018-January-01'],['<a href="/breeders_toolbox/trial/135">new_test_cross</a>','new_test_cross','<a href="/breeders/program/134">test</a>','',undef,'',undef,undef,'',''],['<a href="/breeders_toolbox/trial/169">Observation at Kenya 1</a>','This is a yield study for Spring 2018','<a href="/breeders/program/134">test</a>','<a href="/folder/168">Peru Yield Trial 2020-1</a>','2018','test_location','phenotyping_trial','RCBD','',''],['<a href="/breeders_toolbox/trial/144">test_t</a>','test tets','<a href="/breeders/program/134">test</a>','','2016','test_location',undef,'CRD','',''],['<a href="/breeders_toolbox/trial/137">test_trial</a>','test trial','<a href="/breeders/program/134">test</a>','','2014','test_location',undef,'CRD','2017-July-04','2017-July-21'],['<a href="/breeders_toolbox/trial/141">trial2 NaCRRI</a>','another trial for solGS','<a href="/breeders/program/134">test</a>','','2014','test_location',undef,'CRD','','']], 'trial ajax search');

is_deeply(\@removed_last_val, [['<a href="/breeders_toolbox/trial/165">CASS_6Genotypes_Sampling_2015</a>','Copy of trial with postcomposed phenotypes from cassbase.','<a href="/breeders/program/134">test</a>','','2017','test_location','Preliminary Yield Trial','RCBD','',''],['<a href="/breeders_toolbox/trial/139">Kasese solgs trial</a>','This trial was loaded into the fixture to test solgs.','<a href="/breeders/program/134">test</a>','','2014','test_location','Clonal Evaluation','Alpha','',''],['<a href="/breeders_toolbox/trial/135">new_test_cross</a>','new_test_cross','<a href="/breeders/program/134">test</a>','',undef,'',undef,undef,'',''],['<a href="/breeders_toolbox/trial/144">test_t</a>','test tets','<a href="/breeders/program/134">test</a>','','2016','test_location',undef,'CRD','',''],['<a href="/breeders_toolbox/trial/137">test_trial</a>','test trial','<a href="/breeders/program/134">test</a>','','2014','test_location',undef,'CRD','2017-July-04','2017-July-21'],['<a href="/breeders_toolbox/trial/141">trial2 NaCRRI</a>','another trial for solGS','<a href="/breeders/program/134">test</a>','','2014','test_location',undef,'CRD','','']], "check trial list" );

sub search_trials {
    my $query = shift;
    $mech->get("http://localhost:3010/ajax/search/trials$query");
    my $rows = eval { decode_json($mech->content)->{data} };
    return ($mech->status, $rows);
}

sub trial_names {
    my $rows = shift;
    return [ sort map { $_->[0] =~ /<a [^>]+>([^<]+)<\/a>/ ? $1 : $_->[0] } @{$rows || []} ];
}

my ($status, $rows) = search_trials('');
my $all_trials = trial_names($rows);

($status, $rows) = search_trials('?trial_design=CRD');
is($status, 200, "search by trial design");
is_deeply(trial_names($rows), ['test_t', 'test_trial', 'trial2 NaCRRI'], "trial design filter");

# a quote in a filter value is matched as data, not as SQL
($status, $rows) = search_trials("?trial_design=CRD&trial_design=farmer's%20design");
is($status, 200, "search by trial design containing a quote");
is_deeply(trial_names($rows), ['test_t', 'test_trial', 'trial2 NaCRRI'], "quote in trial design is matched as a value");

($status, $rows) = search_trials('?location_id=23');
is($status, 200, "search by location");
ok($rows && scalar(@$rows) > 0, "location filter returns trials");
is_deeply([ grep { $_->[5] ne 'test_location' } @{$rows || []} ], [], "location filter returns only trials at that location");

# a location_id that is not a number is ignored
($status, $rows) = search_trials('?location_id=23x');
is($status, 200, "search with a non-numeric location_id");
is_deeply(trial_names($rows), $all_trials, "non-numeric location_id is ignored");

# a location_id made of Unicode digits is also ignored: Perl's \d matches
# them, but only an ASCII integer is safe to use, so the check must use
# [0-9] (or /a), not \d
($status, $rows) = search_trials('?location_id=%D9%A2%D9%A3');
is($status, 200, "search with a Unicode-digit location_id");
is_deeply(trial_names($rows), $all_trials, "Unicode-digit location_id is ignored");

# the search page writes location_id into inline javascript
$mech->get_ok("http://localhost:3010/search/trials/?location_id=23'x");
$mech->content_lacks("location_id=23'x", "non-numeric location_id is not written into the page");
$mech->content_contains("/ajax/search/trials?location_id=not_provided'", "non-numeric location_id is replaced");

$mech->get_ok('http://localhost:3010/search/trials/?location_id=23');
$mech->content_contains("/ajax/search/trials?location_id=23'", "numeric location_id is kept");

done_testing();

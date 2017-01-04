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

$mech->post_ok('http://localhost:3010/ajax/search/trials' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'data' => [
['<a href="/breeders_toolbox/trial/139">Kasese solgs trial</a>','This trial was loaded into the fixture to test solgs.','test',undef,'2014','test_location','Clonal Evaluation','Alpha'],
['<a href="/breeders_toolbox/trial/135">new_test_cross</a>','new_test_cross','test',undef,undef,undef,undef,undef],
['<a href="/breeders_toolbox/trial/143">selection_population</a>','selection_population',undef,undef,'2015',undef,undef,undef],
['<a href="/breeders_toolbox/trial/140">test_genotyping_project</a>','test_genotyping_project',undef,undef,'2015',undef,undef,undef],
['<a href="/breeders_toolbox/trial/142">test_population2</a>','test_population2',undef,undef,'2015',undef,undef,undef],
['<a href="/breeders_toolbox/trial/144">test_t</a>','test tets','test',undef,'2016','test_location',undef,'CRD'],
['<a href="/breeders_toolbox/trial/137">test_trial</a>','test trial','test',undef,'2014','test_location',undef,'CRD'],
['<a href="/breeders_toolbox/trial/141">trial2 NaCRRI</a>','another trial for solGS','test',undef,'2014','test_location',undef,'CRD']
]}, 'trial ajax search');


done_testing();

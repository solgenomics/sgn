
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

#$mech->post_ok('http://localhost:3010/ajax/search/male_parents?female_parent=UG120001');
$mech->post_ok('http://localhost:3010/ajax/search/male_parents',["female_parent" => "TestAccession1"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['TestAccession1'],
['TestAccession2'],
['TestAccession3'],
['TestAccession4'],
['TestPopulation1'],
['TestPopulation2']
]},'male parent search');

$mech->post_ok('http://localhost:3010/ajax/search/cross_info',["female_parent" => "TestAccession1","male_parent" => "TestAccession2"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['<a href="/stock/41254/view">TestAccession1</a','<a href="/stock/41255/view">TestAccession2</a','<a href="/cross/41264">TestCross1</a', 'biparental']
]}, 'cross info search');

$mech->post_ok('http://localhost:3010/ajax/search/all_crosses',["female_parent" => "TestAccession1"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['<a href="/stock/41254/view">TestAccession1</a','<a href="/stock/41255/view">TestAccession2</a','<a href="/cross/41264">TestCross1</a', 'biparental'],
['<a href="/stock/41254/view">TestAccession1</a','<a href="/stock/41256/view">TestAccession3</a','<a href="/cross/41265">TestCross2</a', 'biparental'],
['<a href="/stock/41254/view">TestAccession1</a','<a href="/stock/41257/view">TestAccession4</a','<a href="/cross/41266">TestCross3</a', 'biparental'],
['<a href="/stock/41254/view">TestAccession1</a','<a href="/stock/41259/view">TestPopulation1</a','<a href="/cross/41268">TestCross5</a', 'open'],
['<a href="/stock/41254/view">TestAccession1</a','<a href="/stock/41260/view">TestPopulation2</a','<a href="/cross/41269">TestCross6</a', 'open'],
['<a href="/stock/41254/view">TestAccession1</a','<a href="/stock/41254/view">TestAccession1</a','<a href="/cross/41267">TestCross4</a', 'self']
]}, 'all crosses search');

done_testing();

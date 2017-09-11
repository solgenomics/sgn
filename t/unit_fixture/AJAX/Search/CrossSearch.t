
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


$mech->post_ok('http://localhost:3010/ajax/search/pedigree_male_parents',["pedigree_female_parent" => "test_accession4"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['test_accession5']
]},'male parent search');

$mech->post_ok('http://localhost:3010/ajax/search/progenies',["pedigree_female_parent" => "test_accession4","pedigree_male_parent" => "test_accession5"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38846/view">new_test_crossP001</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38847/view">new_test_crossP002</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38848/view">new_test_crossP003</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38849/view">new_test_crossP004</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38850/view">new_test_crossP005</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38851/view">new_test_crossP006</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38852/view">new_test_crossP007</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38853/view">new_test_crossP008</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38854/view">new_test_crossP009</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38855/view">new_test_crossP010</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38873/view">test5P001</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38874/view">test5P002</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38875/view">test5P003</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38876/view">test5P004</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38877/view">test5P005</a>','']]}, 'progeny search');

$mech->post_ok('http://localhost:3010/ajax/search/all_progenies',["female_parent" => "test_accession4"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38840/view">test_accession1</a>','<a href="/stock/38841/view">test_accession2</a>','<a href="/stock/38843/view">test_accession4</a>','biparental'],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38846/view">new_test_crossP001</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38847/view">new_test_crossP002</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38848/view">new_test_crossP003</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38849/view">new_test_crossP004</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38850/view">new_test_crossP005</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38851/view">new_test_crossP006</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38852/view">new_test_crossP007</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38853/view">new_test_crossP008</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38854/view">new_test_crossP009</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38855/view">new_test_crossP010</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38873/view">test5P001</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38874/view">test5P002</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38875/view">test5P003</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38876/view">test5P004</a>',''],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38877/view">test5P005</a>',''],['<a href="/stock/38842/view">test_accession3</a>','<a href="/stock//view"></a>','<a href="/stock/38844/view">test_accession5</a>','open']]}, 'all progeny search');


$mech->post_ok('http://localhost:3010/ajax/search/cross_male_parents',["female_parent" => "TestAccession1"] );
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
['<a href="/stock/41254/view">TestAccession1</a>','<a href="/stock/41255/view">TestAccession2</a>','<a href="/cross/41264">TestCross1</a>', 'biparental']
]}, 'cross info search');

$mech->post_ok('http://localhost:3010/ajax/search/all_crosses',["female_parent" => "TestAccession1"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['<a href="/stock/41254/view">TestAccession1</a>','<a href="/stock/41255/view">TestAccession2</a>','<a href="/cross/41264">TestCross1</a>', 'biparental'],
['<a href="/stock/41254/view">TestAccession1</a>','<a href="/stock/41256/view">TestAccession3</a>','<a href="/cross/41265">TestCross2</a>', 'biparental'],
['<a href="/stock/41254/view">TestAccession1</a>','<a href="/stock/41257/view">TestAccession4</a>','<a href="/cross/41266">TestCross3</a>', 'biparental'],
['<a href="/stock/41254/view">TestAccession1</a>','<a href="/stock/41259/view">TestPopulation1</a>','<a href="/cross/41268">TestCross5</a>', 'open'],
['<a href="/stock/41254/view">TestAccession1</a>','<a href="/stock/41260/view">TestPopulation2</a>','<a href="/cross/41269">TestCross6</a>', 'open'],
['<a href="/stock/41254/view">TestAccession1</a>','<a href="/stock/41254/view">TestAccession1</a>','<a href="/cross/41267">TestCross4</a>', 'self']
]}, 'all crosses search');

done_testing();

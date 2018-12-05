
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

$mech->get_ok('http://localhost:3010/stock/38843/datatables/trial_related_stock');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data'=> [
['<a href = "/stock/38857/view">test_trial21</a>', 'plot', 'test_trial21'],
['<a href = "/stock/38862/view">test_trial26</a>', 'plot', 'test_trial26'],
['<a href = "/stock/38870/view">test_trial214</a>', 'plot', 'test_trial214'],
['<a href = "/breeders/seedlot/41303">test_accession4_001</a>','seedlot','test_accession4_001']
]}, 'trial_related_stock');

$mech->get_ok('http://localhost:3010/stock/38843/datatables/progenies');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data'=> [
['female_parent', '<a href = "/stock/38846/view">new_test_crossP001</a>', 'new_test_crossP001'],
['female_parent', '<a href = "/stock/38847/view">new_test_crossP002</a>', 'new_test_crossP002'],
['female_parent', '<a href = "/stock/38848/view">new_test_crossP003</a>', 'new_test_crossP003'],
['female_parent', '<a href = "/stock/38849/view">new_test_crossP004</a>', 'new_test_crossP004'],
['female_parent', '<a href = "/stock/38850/view">new_test_crossP005</a>', 'new_test_crossP005'],
['female_parent', '<a href = "/stock/38851/view">new_test_crossP006</a>', 'new_test_crossP006'],
['female_parent', '<a href = "/stock/38852/view">new_test_crossP007</a>', 'new_test_crossP007'],
['female_parent', '<a href = "/stock/38853/view">new_test_crossP008</a>', 'new_test_crossP008'],
['female_parent', '<a href = "/stock/38854/view">new_test_crossP009</a>', 'new_test_crossP009'],
['female_parent', '<a href = "/stock/38855/view">new_test_crossP010</a>', 'new_test_crossP010'],
['female_parent', '<a href = "/stock/38873/view">test5P001</a>', 'test5P001'],
['female_parent', '<a href = "/stock/38874/view">test5P002</a>', 'test5P002'],
['female_parent', '<a href = "/stock/38875/view">test5P003</a>', 'test5P003'],
['female_parent', '<a href = "/stock/38876/view">test5P004</a>', 'test5P004'],
['female_parent', '<a href = "/stock/38877/view">test5P005</a>', 'test5P005']
]}, 'progenies');

$mech->get_ok('http://localhost:3010/stock/38846/datatables/group_and_member');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data'=> [
['<a href = "/stock/38845/view">new_test_cross</a>', 'cross', 'new_test_cross']
]}, 'offspring_of');


done_testing();

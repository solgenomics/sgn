
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

my $accession_1_rs = $schema->resultset('Stock::Stock')->find({name =>'test_accession4'});
my $accession_1_id = $accession_1_rs->stock_id();

my $accession_2_rs = $schema->resultset('Stock::Stock')->find({name =>'new_test_crossP001'});
my $accession_2_id = $accession_2_rs->stock_id();

$mech->get_ok("http://localhost:3010/stock/$accession_1_id/datatables/trial_related_stock");
$response = decode_json $mech->content;
#print STDERR Dumper $response;

is_deeply($response, {'data'=> [
['plot', '<a href = "/stock/38857/view">test_trial21</a>', 'test_trial21'],
['plot', '<a href = "/stock/38862/view">test_trial26</a>', 'test_trial26'],
['plot', '<a href = "/stock/38870/view">test_trial214</a>', 'test_trial214']
]}, 'trial_related_stock');

$mech->get_ok("http://localhost:3010/stock/$accession_1_id/datatables/progenies");
$response = decode_json $mech->content;
print STDERR "PROGENIES RESPONSE: ".Dumper $response;

is_deeply($response, {'data'=> [
['female_parent', 'unspecified', '<a href = "/stock/38846/view">new_test_crossP001</a>',  'new_test_crossP001'],
['female_parent', 'unspecified', '<a href = "/stock/38847/view">new_test_crossP002</a>', 'new_test_crossP002'],
['female_parent', 'unspecified', '<a href = "/stock/38848/view">new_test_crossP003</a>', 'new_test_crossP003'],
['female_parent', 'unspecified', '<a href = "/stock/38849/view">new_test_crossP004</a>', 'new_test_crossP004'],
['female_parent', 'unspecified', '<a href = "/stock/38850/view">new_test_crossP005</a>', 'new_test_crossP005'],
['female_parent', 'unspecified', '<a href = "/stock/38851/view">new_test_crossP006</a>', 'new_test_crossP006'],
['female_parent', 'unspecified', '<a href = "/stock/38852/view">new_test_crossP007</a>', 'new_test_crossP007'],
['female_parent', 'unspecified', '<a href = "/stock/38853/view">new_test_crossP008</a>', 'new_test_crossP008'],
['female_parent', 'unspecified', '<a href = "/stock/38854/view">new_test_crossP009</a>', 'new_test_crossP009'],
['female_parent', 'unspecified', '<a href = "/stock/38855/view">new_test_crossP010</a>', 'new_test_crossP010'],
['female_parent', 'unspecified', '<a href = "/stock/38873/view">test5P001</a>', 'test5P001'],
['female_parent', 'unspecified', '<a href = "/stock/38874/view">test5P002</a>', 'test5P002'],
['female_parent', 'unspecified', '<a href = "/stock/38875/view">test5P003</a>', 'test5P003'],
['female_parent', 'unspecified', '<a href = "/stock/38876/view">test5P004</a>', 'test5P004'],
['female_parent', 'unspecified', '<a href = "/stock/38877/view">test5P005</a>', 'test5P005']
]}, 'progenies');

$mech->get_ok("http://localhost:3010/stock/$accession_2_id/datatables/group_and_member");
$response = decode_json $mech->content;
#print STDERR Dumper $response;

is_deeply($response, {'data'=> [
['<a href="/cross/38845">new_test_cross</a>', 'cross', 'new_test_cross']
]}, 'group_and_member');


#test retrieving siblings
$mech->get_ok("http://localhost:3010/stock/$accession_2_id/datatables/siblings");
$response = decode_json $mech->content;
#print STDERR Dumper $response;

my $results = $response->{'data'};
my @siblings = @$results;
my $number_of_siblings = scalar(@siblings);
is($number_of_siblings, 14);

done_testing();


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

$mech->get_ok('http://localhost:3010/ajax/accession_usage_trials');
$response = decode_json $mech->content;
print STDERR Dumper $response;
my $data = $response->{data};
ok(scalar(@$data) == 432);

print STDERR Dumper $data->[0];
print STDERR "\n";
is_deeply($data->[0],
['<a href="/stock/38878/view">UG120001</a',3,6]
, 'first row');


print STDERR Dumper $data->[100];
print STDERR "\n";
is_deeply($data->[100],
['<a href="/stock/38978/view">UG120115</a',3,6]
, '101th row');


$mech->get_ok('http://localhost:3010/ajax/accession_usage_female');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response,{'data' =>[
['<a href="/stock/41259/view">TestPopulation1</a', 7],
['<a href="/stock/41254/view">TestAccession1</a', 6],
['<a href="/stock/38878/view">UG120001</a', 4],
['<a href="/stock/38843/view">test_accession4</a', 1],
['<a href="/stock/38880/view">UG120003</a', 1],
['<a href="/stock/38882/view">UG120005</a', 1],
['<a href="/stock/41258/view">TestAccession5</a', 1]
]}, 'female usage');


$mech->get_ok('http://localhost:3010/ajax/accession_usage_male');
$response = decode_json $mech->content;
print STDERR Dumper $response;
my $data = $response->{data};
ok(scalar(@$data) == 16);

print STDERR Dumper $data->[0];
print STDERR "\n";
is_deeply($data->[0],
['<a href="/stock/41254/view">TestAccession1</a', 2]
, 'first row');


print STDERR Dumper $data->[5];
print STDERR "\n";
is_deeply($data->[5],
['<a href="/stock/38844/view">test_accession5</a', 1]
, '6th row');

done_testing();


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
print STDERR Dumper scalar(@$data);
ok(scalar(@$data) == 439);

print STDERR Dumper $data->[0];
print STDERR "\n";
is_deeply($data->[0],
['<a href="/stock/38878/view">UG120001</a>',3,6]
, 'first row');


print STDERR Dumper $data->[100];
print STDERR "\n";
is_deeply($data->[100],
['<a href="/stock/38978/view">UG120115</a>',3,6]
, '101th row');


$mech->get_ok('http://localhost:3010/ajax/accession_usage_female');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response,{'data' => [['<a href="/stock/38843/view">test_accession4</a>',15],['<a href="/stock/38840/view">test_accession1</a>',1],['<a href="/stock/38842/view">test_accession3</a>',1]]}, 'female usage');


$mech->get_ok('http://localhost:3010/ajax/accession_usage_male');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38844/view">test_accession5</a>',15],['<a href="/stock/38841/view">test_accession2</a>',1]]}, 'male usage');

$mech->get_ok('http://localhost:3010/ajax/accession_usage_phenotypes?display=plots_accession');
$response = decode_json $mech->content;
print STDERR Dumper $response;
print STDERR Dumper scalar(@{$response->{data}});

is(scalar(@{$response->{data}}), 1563, 'accession phenotypes usage');


done_testing();

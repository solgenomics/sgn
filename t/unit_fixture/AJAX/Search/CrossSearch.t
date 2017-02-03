
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
$mech->post_ok('http://localhost:3010/ajax/search/male_parents',["female_parent" => "UG120001"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['UG120002'],
['UG120007'],
['UG120008'],
['UG120009']
]},'male parent search');

$mech->post_ok('http://localhost:3010/ajax/search/cross_info',["female_parent" => "UG120001","male_parent" => "UG120002"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [
['<a href="/stock/38878/view">UG120001</a','<a href="/stock/38879/view">UG120002</a','<a href="/stock/41248/view">cross_test1</a']
]}, 'cross info search');

done_testing();

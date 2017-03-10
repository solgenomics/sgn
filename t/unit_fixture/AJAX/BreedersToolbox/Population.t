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

$mech->post_ok('http://localhost:3010/ajax/population/new', [ "population_name"=> "ajax_test_pop_1", "accessions[]"=> ['test_accession1', 'test_accession2', 'test_accession3'] ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'message'}, 'Success! Population created');

#Remove added population so tests downstream do not fail
my $population = $schema->resultset("Stock::Stock")->find({uniquename => 'ajax_test_pop_1'});
$population->delete();

done_testing();

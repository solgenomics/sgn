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
my $population_name = "ajax_test_pop_1";

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
is($response->{'userDisplayName'}, 'Jane Doe');
is($response->{'expires_in'}, '7200');

$mech->post_ok('http://localhost:3010/ajax/population/new', [ "population_name"=> $population_name, "accessions[]"=> ['test_accession1', 'test_accession2', 'test_accession3'] ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, "Success! Population $population_name created");

my $new_population_id = $response->{'population_id'};

$mech->post_ok('http://localhost:3010/ajax/population/delete', [ "population_name"=> $population_name, "population_id" => $new_population_id ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, "Population $population_name deleted successfully!");


done_testing();

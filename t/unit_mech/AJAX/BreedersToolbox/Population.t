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
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
my $population_name = "ajax_test_pop_1";

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
is($response->{'userDisplayName'}, 'Jane Doe');
is($response->{'expires_in'}, '7200');

$mech->post_ok('http://localhost:3010/ajax/population/new', [ "population_name"=> $population_name, "accessions[]"=> ['test_accession1', 'test_accession2', 'test_accession3'], "member_type" => 'accessions']);
$response = decode_json $mech->content;
is($response->{'success'}, "Success! Population $population_name created");

my $new_population_id = $response->{'population_id'};

$mech->post_ok('http://localhost:3010/ajax/population/delete', [ "population_name"=> $population_name, "population_id" => $new_population_id ]);
$response = decode_json $mech->content;
is($response->{'success'}, "Population $population_name deleted successfully!");

#test deleting a population used in a cross
$mech->post_ok('http://localhost:3010/ajax/population/new', [ "population_name"=> 'test_population_2', "accessions[]"=> ['test_accession1', 'test_accession2', 'test_accession3'], "member_type" => 'accessions' ]);
$response = decode_json $mech->content;
is($response->{'success'}, "Success! Population test_population_2 created");
my $new_population2_id = $response->{'population_id'};

$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => '2024_crossing_experiment', 'crossingtrial_program_id' => 134, 'crossingtrial_location' => 'test_location', 'year' => '2024', 'project_description' => 'test description' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $crossing_experiment_rs = $schema->resultset('Project::Project')->find({ name => '2024_crossing_experiment' });
my $crossing_experiment_id = $crossing_experiment_rs->project_id();

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'test_add_cross_with_population', 'cross_combination' => '', 'cross_type' => 'open', 'maternal' => 'UG120001', 'paternal' => 'test_population_2']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

#couldn't delete population associated with cross
$mech->post_ok('http://localhost:3010/ajax/population/delete', [ "population_name"=> 'test_population_2', "population_id" => $new_population2_id ]);
$response = decode_json $mech->content;
is($response->{'error'}, "Error deleting population test_population_2: Population has associated cross or pedigree: Cannot delete.\n");

#deleting cross and crossing experiment
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $crossing_experiment_id . '/delete_all_crosses_in_crossingtrial');
my $project_owner_row_1 = $phenome_schema->resultset('ProjectOwner')->find({ project_id => $crossing_experiment_id });
$project_owner_row_1->delete();
$crossing_experiment_rs->delete();


$mech->post_ok('http://localhost:3010/ajax/population/delete', [ "population_name"=> 'test_population_2', "population_id" => $new_population2_id ]);
$response = decode_json $mech->content;
is($response->{'success'}, "Population test_population_2 deleted successfully!");


done_testing();

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use DateTime;
use JSON;
use SGN::Model::Cvterm;
use Sort::Key::Natural qw(natkeysort);

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;
my $json = JSON->new->allow_nonref;
my @all_new_stocks;
my $time = DateTime->now();
my $upload_date = $time->ymd();

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

#adding propagation project
$mech->post_ok('http://localhost:3010/ajax/propagation/add_propagation_project', [ 'project_name' => 'propagation_project_1', 'propagation_type' => 'propagation', 'project_program_id' => $breeding_program_id,
    'project_location' => 'test_location', 'year' => '2026', 'project_description' => 'test propagation tool' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $project_rs = $schema->resultset('Project::Project')->find({ name => 'propagation_project_1' });
my $project_id = $project_rs->project_id();

#adding propagation group
$mech->post_ok('http://localhost:3010/ajax/propagation/add_propagation_group_identifier', [ 'propagation_group_identifier' => 'G1', "propagation_project_id" => $project_id, 'purpose' => 'CVC Backup', 'accession_name' => 'UG120001', 'material_type' => 'Plant', 'date' => '2026-01-14', 'operator_name' => 'Jane Doe', 'breeding_program_name' => 'test', 'description' => 'test'  ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $propagation_group_rs = $schema->resultset('Stock::Stock')->find({ name => 'G1' });
my $propagation_group_stock_id = $propagation_group_rs->stock_id();

#adding propagation identifier
$mech->post_ok('http://localhost:3010/ajax/propagation/add_propagation_identifier', [ 'propagation_identifier' => 'G1_1', "propagation_group_stock_id" => $propagation_group_stock_id, 'rootstock_name' => 'UG120002']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $propagation_identifier_rs = $schema->resultset('Stock::Stock')->find({ name => 'G1_1' });
my $propagation_stock_id = $propagation_identifier_rs->stock_id();

#update status
$mech->post_ok('http://localhost:3010/ajax/propagation/update_status', [ 'propagation_stock_id' => $propagation_stock_id, 'propagation_status' => 'Inventoried', 'propagation_status_notes' => 'test', 'inventory_identifier' => 'inventory_1']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');


$f->clean_up_db();


done_testing();

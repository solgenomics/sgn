use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;
use CXGN::List;
use CXGN::People::Person;
use DateTime;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;
my $json = JSON->new->allow_nonref;
my @all_new_stocks;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

#test adding project
$mech->post_ok('http://localhost:3010/ajax/tracking_activity/create_tracking_activity_project', [ 'project_name' => 'tracking_project_1', 'activity_type' => 'tissue_culture', 'breeding_program' => 134,
    'project_location' => 'test_location', 'year' => '2024', 'project_description' => 'test tracking project' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $project_rs = $schema->resultset('Project::Project')->find({ name => 'tracking_project_1' });
my $project_id = $project_rs->project_id();

#test creating transcking IDs
my $janedoe_id = CXGN::People::Person->get_person_by_username($dbh, 'janedoe');

my $list_id = CXGN::List::create_list($dbh, 'accessions_for_tracking_ids', 'test', $janedoe_id );
my $list = CXGN::List->new( { dbh => $dbh, list_id => $list_id });
$list->type('accessions');
$list->add_bulk( [ 'UG120001', 'UG120002', 'UG120003']);

$mech->post_ok('http://localhost:3010/ajax/tracking_activity/generate_tracking_identifiers', [ 'project_name' => 'tracking_project_1', 'list_id' => $list_id ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

#checking identifiers in the project
$mech->post_ok("http://localhost:3010/ajax/tracking_activity/project_active_identifier_names/$project_id");

$response = decode_json $mech->content;
my $identifiers = $response->{'data'};
my $identifiers_count = scalar(@$identifiers);
is($identifiers_count, '3');
my @sorted_ids = sort(@$identifiers);

is_deeply(\@sorted_ids, [
    'tracking_project_1:UG120001_T1',
    'tracking_project_1:UG120002_T2',
    'tracking_project_1:UG120003_T3'
    ], "check ids");

#test saving activity

my $identifier_stock_id_1 = $schema->resultset("Stock::Stock")->find({ uniquename => 'tracking_project_1:UG120001_T1' })->stock_id();
my $identifier_stock_id_2 = $schema->resultset("Stock::Stock")->find({ uniquename => 'tracking_project_1:UG120002_T2' })->stock_id();
my $identifier_stock_id_3 = $schema->resultset("Stock::Stock")->find({ uniquename => 'tracking_project_1:UG120003_T3' })->stock_id();

my $time = DateTime->now();
my $timestamp_1 = $time->ymd() . "_" . $time->hms();
$mech->post_ok('http://localhost:3010/ajax/tracking_activity/save', [ 'program_name' => 'test','tracking_identifier_name' => 'tracking_project_1:UG120001_T1', 'tracking_identifier_id' => $identifier_stock_id_1, 'activity_type' => 'tissue_culture', 'selected_type' => 'subculture_count', 'input' => '4', 'notes' => 'test', 'record_timestamp' => $timestamp_1, 'source_info' => undef, ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $timestamp_2 = $time->ymd();
$mech->post_ok('http://localhost:3010/ajax/tracking_activity/save', [ 'program_name' => 'test', 'tracking_identifier_name' => 'tracking_project_1:UG120001_T1', 'tracking_identifier_id' => $identifier_stock_id_1, 'activity_type' => 'tissue_culture','selected_type' => 'subculture_count', 'input' => '10', 'notes' => 'test 2', 'record_timestamp' => $timestamp_2, 'source_info' => undef ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/tracking_activity/save', [ 'program_name' => 'test', 'tracking_identifier_name' => 'tracking_project_1:UG120002_T2', 'tracking_identifier_id' => $identifier_stock_id_2, 'activity_type' => 'tissue_culture', 'selected_type' => 'subculture_count', 'input' => '7', 'notes' => 'test', 'record_timestamp' => $timestamp_1, 'source_info' => undef ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/tracking_activity/save', [ 'program_name' => 'test', 'tracking_identifier_name' => 'tracking_project_1:UG120002_T2', 'tracking_identifier_id' => $identifier_stock_id_2, 'activity_type' => 'tissue_culture','selected_type' => 'rooted_count', 'input' => '3', 'notes' => 'test', 'record_timestamp' => $timestamp_2, 'source_info' => undef ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

#test summary
$mech->post_ok("http://localhost:3010/ajax/tracking_activity/summary/$identifier_stock_id_1");
$response = decode_json $mech->content;
my $summary_1 = $response->{'data'};
my $summary_data_1 = $summary_1->[0];
is_deeply($summary_data_1, [
    14,
    '',
    ''
    ], "check summary 1");


$mech->post_ok("http://localhost:3010/ajax/tracking_activity/summary/$identifier_stock_id_2");
$response = decode_json $mech->content;
my $summary_2 = $response->{'data'};
my $summary_data_2 = $summary_2->[0];
is_deeply($summary_data_2, [
    7,
    3,
    ''
    ], "check summary 2");

#deleting project and tracking identifiers
@all_new_stocks = ($identifier_stock_id_1, $identifier_stock_id_2, $identifier_stock_id_3);
my $project_owner = $phenome_schema->resultset('ProjectOwner')->find({ project_id => $project_id });
$project_owner->delete();
$project_rs->delete();

my $id1_prop = $schema->resultset("Stock::Stockprop")->find( {stock_id => $identifier_stock_id_1});
$id1_prop->delete();

my $id2_prop = $schema->resultset("Stock::Stockprop")->find( {stock_id => $identifier_stock_id_2});
$id2_prop->delete();

my $q = "delete from phenome.stock_owner where stock_id=?";
my $h = $dbh->prepare($q);

foreach (@all_new_stocks){
    my $row  = $schema->resultset('Stock::Stock')->find({stock_id=>$_});
    $h->execute($_);
    $row->delete();
}

$f->clean_up_db();

done_testing();

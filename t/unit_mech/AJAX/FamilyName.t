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
use CXGN::Pedigree::AddCrossingtrial;
use CXGN::Pedigree::AddCrosses;


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

#adding crossing experiment
$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'BB_crossing_experiment', 'crossingtrial_program_id' => 134, 'crossingtrial_location' => 'test_location', 'year' => '2026', 'project_description' => 'test family' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $crossing_experiment_id = $schema->resultset('Project::Project')->find({ name => 'BB_crossing_experiment' })->project_id();

#adding crosses
$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'BB_cross_1', 'cross_combination' => 'UG120001xUG120002', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'BB_cross_2', 'cross_combination' => 'UG120001xUG120002', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'BB_cross_3', 'cross_combination' => 'UG120001xUG120002', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'BB_cross_4', 'cross_combination' => 'UG120001xUG120002', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

#upload family
my $file = $f->config->{basepath} . "/t/data/cross/upload_family_test.xlsx";
my $ua = LWP::UserAgent->new;
my $response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_family_names',
    Content_Type => 'form-data',
    Content      => [
        same_parents_file => [
            $file,
            "upload_family_test.xlsx",
            Content_Type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
        "sgn_session_id"  => $sgn_session_id
    ]
);
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is_deeply($message_hash, { 'success' => 1 });



#test removing a family member
my $family_stock_id = $schema->resultset('Stock::Stock')->find({ name => 'BB_family_1' })->stock_id();
my $BB_cross_3_stock_id = $schema->resultset('Stock::Stock')->find({ name => 'BB_cross_3' })->stock_id();

#number of members before removing a member
$mech->post_ok('http://localhost:3010/ajax/family/members/' . $family_stock_id);
$response = decode_json $mech->content;
my %data = %$response;
my $members = $data{data};
my $number_of_members = @$members;
is($number_of_members, 3);

$mech->post_ok('http://localhost:3010/ajax/family/remove_member', [ 'family_id' => $family_stock_id, 'cross_id' => $BB_cross_3_stock_id]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

#number of members after removing a member
$mech->post_ok('http://localhost:3010/ajax/family/members/' . $family_stock_id);
$response = decode_json $mech->content;
my %data_2 = %$response;
my $members_2 = $data_2{data};
my $number_of_members_2 = @$members_2;
is($number_of_members_2, 2);






$f->clean_up_db();


done_testing();


use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;

use CXGN::Pedigree::AddCrossingtrial;
use CXGN::Pedigree::AddCrosses;
use CXGN::Pedigree::AddCrossInfo;
use CXGN::Cross;
use LWP::UserAgent;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;


# test adding crossing trial
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $breeding_program_id = $schema->resultset('Project::Project')->find({name =>'test'})->project_id();

$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial', 'crossingtrial_program_id' => $breeding_program_id ,
    'crossingtrial_location' => 'test_location', 'year' => '2017', 'project_description' => 'test description' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial2', 'crossingtrial_program_id' => $breeding_program_id ,
    'crossingtrial_location' => 'test_location', 'year' => '2018', 'project_description' => 'test description2' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');



# test adding cross and info
my $crossing_trial_rs = $schema->resultset('Project::Project')->find({name =>'test_crossingtrial'});
my $crossing_trial_id = $crossing_trial_rs->project_id();
my $female_plot_id = $schema->resultset('Stock::Stock')->find({name =>'KASESE_TP2013_842'})->stock_id();
my $male_plot_id = $schema->resultset('Stock::Stock')->find({name =>'KASESE_TP2013_1591'})->stock_id();

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_trial_id, 'location' => 'test_location',
    'cross_name' => 'test_add_cross', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002', 'female_plot' => $female_plot_id,
    'male_plot' => $male_plot_id, 'pollination_date' => '2018/02/15', 'flower_number' => '20',
    'fruit_number' => '15', 'seed_number' => '30']);

$response = decode_json $mech->content;
is($response->{'success'}, '1');



# test uploading crosses
my $crossing_trial2_rs = $schema->resultset('Project::Project')->find({name =>'test_crossingtrial2'});
my $crossing_trial2_id = $crossing_trial2_rs->project_id();
my $file = $f->config->{basepath}."/t/data/cross/cross_upload.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_crosses_file',
    Content_Type => 'form-data',
    Content => [
        crosses_upload_file => [ $file, 'cross_upload.xls', Content_Type => 'application/vnd.ms-excel', ],
        "cross_upload_crossing_trial" => $crossing_trial2_id,
        "cross_upload_location" => "test_location",
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is_deeply($message_hash, {'success' => 1});



# test retrieving crosses in a trial
my $test_add_cross_rs = $schema->resultset('Stock::Stock')->find({name =>'test_add_cross'});
my $test_add_cross_id = $test_add_cross_rs->stock_id();
my $UG120001_id = $schema->resultset('Stock::Stock')->find({name =>'UG120001'})->stock_id();
my $UG120002_id = $schema->resultset('Stock::Stock')->find({name =>'UG120002'})->stock_id();

$mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_trial_id/crosses_in_trial");
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data'=> [
    [qq{<a href = "/cross/$test_add_cross_id">test_add_cross</a>}, qq{<a href = "/stock/$UG120001_id/view">UG120001</a>}, qq{<a href = "/stock/$UG120002_id/view">UG120002</a>}, 'biparental', qq{<a href = "/stock/$female_plot_id/view">KASESE_TP2013_842</a>}, qq{<a href = "/stock/$male_plot_id/view">KASESE_TP2013_1591</a>}]
]}, 'crosses in a trial');



# test retrieving crossing experiment info
$mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_trial_id/cross_properties_trial");
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data'=> [
    [qq{<a href = "/cross/$test_add_cross_id">test_add_cross</a>}, undef, "2018/02/15", undef, "20", "15", "30"]
]}, 'crossing experiment info');



# remove added crossing trials after test so that they don't affect downstream tests
$crossing_trial_rs->delete();
$crossing_trial2_rs->delete();



done_testing();

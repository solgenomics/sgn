
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
#print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $breeding_program_id = $schema->resultset('Project::Project')->find({name =>'test'})->project_id();


$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial', 'crossingtrial_program_id' => $breeding_program_id ,
    'crossingtrial_location' => 'test_location', 'year' => '2018', 'project_description' => 'test description' ]);

$response = decode_json $mech->content;
#print STDERR Dumper $response;
is($response->{'success'}, '1');

# test adding cross and info
my $crossing_trial_id = $schema->resultset('Project::Project')->find({name =>'test_crossingtrial'})->project_id();
my $female_plot_id = $schema->resultset('Stock::Stock')->find({name =>'KASESE_TP2013_842'})->stock_id();
my $male_plot_id = $schema->resultset('Stock::Stock')->find({name =>'KASESE_TP2013_1591'})->stock_id();

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_trial_id, 'location' => 'test_location',
    'cross_name' => 'test_add_cross', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002', 'female_plot' => $female_plot_id,
    'male_plot' => $male_plot_id, 'tag_number' => '842', 'pollination_date' => '2018/02/15', 'bag_number' => '5', 'flower_number' => '20',
    'fruit_number' => '15', 'seed_number' => '30']);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

# test uploading crosses
my $file = $f->config->{basepath}."/t/data/cross/upload_cross.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_crosses_file',
    Content_Type => 'form-data',
    Content => [
        crosses_upload_file => [ $file, 'cross_upload.xls', Content_Type => 'application/vnd.ms-excel', ],
        'cross_upload_crossing_trial' => $crossing_trial_id,
        'cross_upload_location' => 'test_location',
    ]
);

$response = decode_json $mech->content;
is($response->{'success'}, '1');





done_testing();

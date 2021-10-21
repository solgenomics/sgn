use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use SGN::Model::Cvterm;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

# adding a crossing experiment for intercross upload
$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'intercross_upload', 'crossingtrial_program_id' => 134 ,
    'crossingtrial_location' => 'test_location', 'year' => '2020', 'project_description' => 'test intercross upload' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
my $before_uploading_cross = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $before_uploading_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $before_uploading_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

my $file = $f->config->{basepath}."/t/data/cross/intercross_upload.csv";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_intercross_file',
    Content_Type => 'form-data',
    Content => [
        "intercross_file" => [ $file, 'intercross_upload.csv', Content_Type => 'text/plain', ],
        "sgn_session_id" => $sgn_session_id,
        "cross_id_format_option" => 'auto_generated_id'
    ]
);
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_uploading_cross = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $after_uploading_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $after_uploading_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

is($after_uploading_cross, $before_uploading_cross + 2);
is($after_uploading_stocks, $before_uploading_stocks + 2);
is($after_uploading_relationship, $before_uploading_relationship + 4);

# checking number of crosses in intercross_upload experiment
my $crossing_experiment_rs = $schema->resultset('Project::Project')->find({name =>'intercross_upload'});
my $crossing_experiment_id = $crossing_experiment_rs->project_id();

$mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_experiment_id/crosses_and_details_in_trial");
$response = decode_json $mech->content;
my %data = %$response;
my $crosses = $data{data};
my $number_of_crosses = @$crosses;
is($number_of_crosses, 2);

# checking transactions in intercross_upload_1
my $intercross_upload_1_id = $schema->resultset('Stock::Stock')->find({name =>'intercross_upload_1'})->stock_id();

$mech->post_ok("http://localhost:3010/ajax/cross/transactions/$intercross_upload_1_id");
$response = decode_json $mech->content;
my %result = %$response;
my $transactions = $result{data};
my $number_of_transactions = @$transactions;
is($number_of_transactions, 2);

#checking stockprop
my $cross_transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_transaction_json', 'stock_property')->cvterm_id();
my $transaction_rows = $schema->resultset("Stock::Stockprop")->search({type_id => $cross_transaction_type_id})->count();
is($transaction_rows, 2);

my $cross_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_identifier', 'stock_property')->cvterm_id();
my $cross_identifier_rows = $schema->resultset("Stock::Stockprop")->search({type_id => $cross_identifier_type_id})->count();
is($cross_identifier_rows, 2);

#deleting crosses and crossing experiment after testing
$mech->post_ok('http://localhost:3010/ajax/cross/delete', [ 'cross_id' => $intercross_upload_1_id]);
$response = decode_json $mech->content;
is_deeply($message_hash, {'success' => 1});

my $intercross_upload_2_id = $schema->resultset('Stock::Stock')->find({name =>'intercross_upload_2'})->stock_id();
$mech->post_ok('http://localhost:3010/ajax/cross/delete', [ 'cross_id' => $intercross_upload_2_id]);
$response = decode_json $mech->content;
is_deeply($message_hash, {'success' => 1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$crossing_experiment_id.'/delete/crossing_experiment');
$response = decode_json $mech->content;
is_deeply($message_hash, {'success' => 1});


done_testing();

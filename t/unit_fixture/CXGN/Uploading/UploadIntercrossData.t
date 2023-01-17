use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use SGN::Model::Cvterm;
use CXGN::Trial::Download;
use Spreadsheet::WriteExcel;
use Spreadsheet::Read;
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

my $crossing_experiment_rs = $schema->resultset('Project::Project')->find({name =>'intercross_upload'});
my $crossing_experiment_id = $crossing_experiment_rs->project_id();

#test uploading target numbers
my $target_numbers_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'target_numbers_json', 'project_property')->cvterm_id();
my $before_uploading_target_numbers_all_projectprop = $schema->resultset("Project::Projectprop")->search({})->count();
my $before_uploading_target_numbers = $schema->resultset("Project::Projectprop")->search({ project_id => $crossing_experiment_id, type_id => $target_numbers_type_id })->count();

for my $extension ("xls", "xlsx") {
    my $file = $f->config->{basepath} . "/t/data/cross/target_numbers.$extension";
    my $ua = LWP::UserAgent->new;
    my $response = $ua->post(
        'http://localhost:3010/ajax/crossing_experiment/upload_target_numbers',
        Content_Type => 'form-data',
        Content => [
            "target_numbers_file" => [
                $file,
                "target_numbers.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "target_numbers_experiment_id" => $crossing_experiment_id,
            "sgn_session_id" => $sgn_session_id
        ]
    );
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });
}

my $after_uploading_target_numbers_all_projectprop = $schema->resultset("Project::Projectprop")->search({})->count();
my $after_uploading_target_numbers = $schema->resultset("Project::Projectprop")->search({ project_id => $crossing_experiment_id, type_id => $target_numbers_type_id })->count();

is($after_uploading_target_numbers_all_projectprop, $before_uploading_target_numbers_all_projectprop + 1);
is($after_uploading_target_numbers, $before_uploading_target_numbers + 1);

#retrieving target number
$mech->post_ok("http://localhost:3010/ajax/crossing_experiment/target_numbers_and_progress/$crossing_experiment_id");
$response = decode_json $mech->content;
is_deeply($response, { 'data' => [
    ['UG120001','UG120002',50,undef,25,undef,''],
    ['UG120002','UG120003',40,undef,20,undef,'']
]}, 'target numbers');


#uploading intercross data
my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
my $before_uploading_cross = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $before_uploading_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $before_uploading_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $cross_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_identifier', 'stock_property')->cvterm_id();
my $before_upload_identifier_rows = $schema->resultset("Stock::Stockprop")->search({type_id => $cross_identifier_type_id})->count();

my $file = $f->config->{basepath}."/t/data/cross/intercross_upload.csv";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_intercross_file',
    Content_Type => 'form-data',
    Content => [
        "intercross_file" => [ $file, 'intercross_upload.csv', Content_Type => 'text/plain', ],
        "sgn_session_id" => $sgn_session_id,
        "cross_id_format_option" => 'auto_generated_id',
        "intercross_experiment_id" => $crossing_experiment_id
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

#retrieving target number and progress
$mech->post_ok("http://localhost:3010/ajax/crossing_experiment/target_numbers_and_progress/$crossing_experiment_id");
$response = decode_json $mech->content;
my $target_data = $response->{'data'};

is($target_data->[0]->[0], 'UG120001');
is($target_data->[0]->[1], 'UG120002');
is($target_data->[0]->[2], 50);
is($target_data->[0]->[3], 35);
is($target_data->[0]->[4], 25);
is($target_data->[0]->[5], 0);

is($target_data->[1]->[0], 'UG120002');
is($target_data->[1]->[1], 'UG120003');
is($target_data->[1]->[2], 40);
is($target_data->[1]->[3], 25);
is($target_data->[1]->[4], 20);
is($target_data->[1]->[5], 0);

# checking number of crosses in intercross_upload experiment
$mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_experiment_id/crosses_and_details_in_trial");
$response = decode_json $mech->content;
my %data = %$response;
my $crosses = $data{data};
my $number_of_crosses = @$crosses;
is($number_of_crosses, 2);

# checking transactions in intercross_upload_1
my $intercross_upload_1_id = $schema->resultset('Stock::Stock')->find({ name => 'intercross_upload_1' })->stock_id();
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

my $after_upload_identifier_rows = $schema->resultset("Stock::Stockprop")->search({type_id => $cross_identifier_type_id})->count();
is($after_upload_identifier_rows, $before_upload_identifier_rows + 2);

#test crossing experiment download with transaction info
my @cross_properties = ("Tag Number", "Pollination Date", "Number of Bags", "Number of Flowers", "Number of Fruits", "Number of Seeds");
my $tempfile = "/tmp/test_download_crossing_experiment.xls";
my $format = 'CrossingExperimentXLS';
my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema => $f->bcs_schema,
    trial_list => [$crossing_experiment_id],
    filename => $tempfile,
    format => $format,
    field_crossing_data_order => \@cross_properties
});

$create_spreadsheet->download();
my $contents = ReadData $tempfile;

my $columns = $contents->[1]->{'cell'};
my @column_array = @$columns;
my $number_of_columns = scalar @column_array;
ok(scalar($number_of_columns) == 22, "check number of columns.");

is_deeply($contents->[1]->{'cell'}->[1], [
    undef,
    'Cross Unique ID',
    'intercross_upload_1',
    'intercross_upload_2'
], "check cross unique ids column");

my $transaction_column = $contents->[1]->{'cell'}->[21];
my @transaction_array = @$transaction_column;
my $correct_grouping_1;
my $correct_grouping_2;

if ('transaction_id_0001,transaction_id_0004' ~~ @transaction_array){
    $correct_grouping_1 = 1;
} else {
    $correct_grouping_1 = 0
}

if ('transaction_id_0002,transaction_id_0003' ~~ @transaction_array){
    $correct_grouping_2 = 1;
} else {
    $correct_grouping_2 = 0
}

is($correct_grouping_1, 1);
is($correct_grouping_2, 1);

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

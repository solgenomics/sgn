
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Dataset;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

print STDERR "Uploading NIRS\n";

my $file = $f->config->{basepath}."/t/data/NIRS/C16Mval_spectra.csv";

my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_verify',
        Content_Type => 'form-data',
        Content => [
            upload_nirs_spreadsheet_file_input => [ $file, 'nirs_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_nirs_spreadsheet_data_level"=>"plots",
            "upload_nirs_spreadsheet_protocol_name"=>"NIRS SCIO Protocol",
            "upload_nirs_spreadsheet_protocol_desc"=>"description",
            "upload_nirs_spreadsheet_protocol_device_type"=>"SCIO"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
print STDERR Dumper $message;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
ok($message_hash->{figure});
is_deeply($message_hash->{success}, ['File nirs_data_upload saved in archive.','File valid: nirs_data_upload.','File data successfully parsed.','Aggregated file data successfully parsed.','Aggregated file data verified. Plot names and trait names are valid.']);

my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_store',
        Content_Type => 'form-data',
        Content => [
            upload_nirs_spreadsheet_file_input => [ $file, 'nirs_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_nirs_spreadsheet_data_level"=>"plots",
            "upload_nirs_spreadsheet_protocol_name"=>"NIRS SCIO Protocol",
            "upload_nirs_spreadsheet_protocol_desc"=>"description",
            "upload_nirs_spreadsheet_protocol_device_type"=>"SCIO"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
ok($message_hash->{figure});
is(scalar(@{$message_hash->{success}}), 8);
like($message_hash->{success}->[6], qr/All values in your file have been successfully processed!/, "return message test");
my $nirs_protocol_id = $message_hash->{nd_protocol_id};

my $ds = CXGN::Dataset->new( people_schema => $f->people_schema(), schema => $f->bcs_schema());
$ds->plots([
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial21'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial22'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial23'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial24'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial25'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial26'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial27'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial28'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial29'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial210'})->stock_id(),
    $f->bcs_schema()->resultset("Stock::Stock")->find({uniquename => 'test_trial211'})->stock_id()
]);
$ds->name("nirs_dataset_test");
$ds->description("test nirs description");
$ds->sp_person_id(41);
my $sp_dataset_id = $ds->store();

my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/Nirs/generate_spectral_plot',
        Content_Type => 'form-data',
        Content => [
            dataset_id => $sp_dataset_id,
            "sgn_session_id"=>$sgn_session_id,
            "nd_protocol_id"=>$nirs_protocol_id,
            "query_associated_stocks"=>"yes"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
ok($message_hash->{figure});

$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/download_file',
        Content_Type => 'form-data',
        Content => [
            dataset_id => $sp_dataset_id,
            nd_protocol_id => $nirs_protocol_id,
            "sgn_session_id"=>$sgn_session_id,
            "high_dimensional_phenotype_type"=>"NIRS",
            "query_associated_stocks"=>"yes",
            "download_file_type"=>"data_matrix"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
ok($message_hash->{download_file_link});

$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/download_file',
        Content_Type => 'form-data',
        Content => [
            dataset_id => $sp_dataset_id,
            nd_protocol_id => $nirs_protocol_id,
            "sgn_session_id"=>$sgn_session_id,
            "high_dimensional_phenotype_type"=>"NIRS",
            "query_associated_stocks"=>"yes",
            "download_file_type"=>"identifier_metadata"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
ok($message_hash->{download_file_link});

$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/download_relationship_matrix_file',
        Content_Type => 'form-data',
        Content => [
            dataset_id => $sp_dataset_id,
            nd_protocol_id => $nirs_protocol_id,
            "sgn_session_id"=>$sgn_session_id,
            "high_dimensional_phenotype_type"=>"NIRS",
            "query_associated_stocks"=>"yes",
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
ok($message_hash->{download_file_link});

done_testing();

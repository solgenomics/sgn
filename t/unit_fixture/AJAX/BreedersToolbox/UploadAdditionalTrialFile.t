
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $trial_id = $schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id();

my $file = $f->config->{basepath}."/t/data/stock/seedlot_upload";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/upload_additional_file',
        Content_Type => 'form-data',
        Content => [
            trial_upload_additional_file => [ $file, 'additional_file', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
ok($message_hash->{file_id});

$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/upload_additional_file',
        Content_Type => 'form-data',
        Content => [
            trial_upload_additional_file => [ $file, 'additional_file', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
ok($message_hash->{file_id});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/get_uploaded_additional_file');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is(scalar(@{$response->{files}}), 2);

done_testing();


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

my $breeding_program_id = $schema->resultset('Project::Project')->find({name=>'test'})->project_id();

my $file = $f->config->{basepath}."/t/data/stock/seedlot_upload";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_uploaded_file => [ $file, 'seedlot_upload', Content_Type => 'application/vnd.ms-excel', ],
            "upload_seedlot_breeding_program_id"=>$breeding_program_id,
            "upload_seedlot_location"=>'test_location',
            "upload_seedlot_population_name"=>"testpop1",
            "upload_seedlot_organization_name"=>"testorg1",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is_deeply($message_hash, {'success' => 1});

done_testing();

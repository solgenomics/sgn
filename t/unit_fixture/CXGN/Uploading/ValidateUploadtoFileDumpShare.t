
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
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

print STDERR "Uploading File to Data Dump for Sharing\n";

my $file = $f->config->{basepath}."/t/data/genotype_data/testset_GT-AD-DP-GQ-DS-PL.vcf";

my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/filesharedump/upload',
        Content_Type => 'form-data',
        Content => [
            manage_file_dump_upload_file_dialog_file => [ $file, 'manage_file_dump_upload_file_dialog_file' ],
            "sgn_session_id"=>$sgn_session_id,
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is_deeply($message_hash, {success=>1});

my $ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/ajax/filesharedump/list?sgn_session_id=$sgn_session_id");
$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is(scalar(@{$message_hash->{data}}), 1);

done_testing();

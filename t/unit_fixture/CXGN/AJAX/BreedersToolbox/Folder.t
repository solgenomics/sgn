use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

my $breeding_program_id = $schema->resultset('Project::Project')->find({name=>'test'})->project_id();

$mech->post_ok('http://localhost:3010/ajax/folder/new', [ "folder_name"=> "test_folder_1", "breeding_program_id"=> $breeding_program_id, "folder_for_trials"=>'true', "folder_for_crosses"=>'true' ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'error' => 'You need to be logged in.'}, 'check not logged in create new folder.');

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw"=> "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->{'message'}, 'Login Successfull');

$mech->post_ok('http://localhost:3010/ajax/folder/new', [ "folder_name"=> "test_folder_1", "breeding_program_id"=> $breeding_program_id, "folder_for_trials"=>'true', "folder_for_crosses"=>'true' ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

done_testing();
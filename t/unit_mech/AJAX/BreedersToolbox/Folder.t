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
my $trial_id = $schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id();

$mech->post_ok('http://localhost:3010/ajax/folder/new', [ "folder_name"=> "test_folder_1", "breeding_program_id"=> $breeding_program_id, "folder_for_trials"=>'true', "folder_for_crosses"=>'true' ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'error' => 'You need to be logged in.'}, 'check not logged in create new folder.');

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw"=> "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');

$mech->post_ok('http://localhost:3010/ajax/folder/new', [ "folder_name"=> "test_folder_1", "breeding_program_id"=> $breeding_program_id, "folder_for_trials"=>'true', "folder_for_crosses"=>'true' ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');
my $folder_id = $response->{'folder_id'};

$mech->post_ok('http://localhost:3010/ajax/folder/new', [ "parent_folder_id"=>$folder_id, "folder_name"=> "test_folder_1", "breeding_program_id"=> $breeding_program_id, "folder_for_trials"=>'true', "folder_for_crosses"=>'false' ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'error'}, 'A folder or trial with that name already exists in the database. Please select another name.');

$mech->post_ok('http://localhost:3010/ajax/folder/new', [ "parent_folder_id"=>$folder_id, "folder_name"=> "test_folder_2", "breeding_program_id"=> $breeding_program_id, "folder_for_trials"=>'true', "folder_for_crosses"=>'false' ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');
my $folder2_id = $response->{'folder_id'};

$mech->get_ok("http://localhost:3010/ajax/folder/$folder_id/associate/parent/$folder2_id");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

$mech->get_ok("http://localhost:3010/ajax/folder/$trial_id/associate/parent/$folder2_id");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

$mech->post_ok("http://localhost:3010/ajax/folder/$folder_id/categories", ["folder_for_trials"=>'true', "folder_for_crosses"=>"true"]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

$mech->post_ok("http://localhost:3010/ajax/folder/$folder_id/categories", ["folder_for_trials"=>'false', "folder_for_crosses"=>"false"]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

$mech->get_ok("http://localhost:3010/ajax/folder/$folder_id/delete");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

$mech->get_ok("http://localhost:3010/ajax/folder/$folder2_id/delete");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'error'}, 'Folder Not Deleted! To delete a folder first move all trials and sub-folders out of it.');

$mech->get_ok("http://localhost:3010/ajax/folder/$trial_id/associate/parent/0");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

$mech->get_ok("http://localhost:3010/ajax/folder/$folder2_id/delete");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, '1');

done_testing();

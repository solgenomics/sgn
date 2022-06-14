
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
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');

my $access_token = $response->{access_token};

$mech->default_header("Content-Type" => "application/json");
$mech->default_header('Authorization'=> 'Bearer ' . $access_token);

my $trial_id = $schema->resultset('Project::Project')->find({name=>'Kasese solgs trial'})->project_id();

#Get original value
$mech->get_ok('http://localhost:3010/brapi/v2/studies/' . $trial_id);
$response = decode_json $mech->content;
my $experiment_type_original = $response->{result}->{experimentalDesign}->{description};


#Update value
$mech->post_ok(
        'http://localhost:3010/ajax/breeders/trial/'. $trial_id .'/update_trial_design_type',
           [ trial_design_type => "Lattice"]
    );
$response = decode_json $mech->content;

is_deeply($response, {'success' => 1});

#Get changed value
$mech->get_ok('http://localhost:3010/brapi/v2/studies/' . $trial_id);
$response = decode_json $mech->content;
is_deeply($response->{result}->{experimentalDesign}->{description}, 'Lattice');


#Store original value
$mech->post_ok(
        'http://localhost:3010/ajax/breeders/trial/'. $trial_id .'/update_trial_design_type',
           [ trial_design_type => "Alpha"]
    );
$response = decode_json $mech->content;
is_deeply($response, {'success' => 1});
$mech->get_ok('http://localhost:3010/brapi/v2/studies/' . $trial_id);
$response = decode_json $mech->content;
is_deeply($response->{result}->{experimentalDesign}->{description}, $experiment_type_original);



$f->clean_up_db();
done_testing();

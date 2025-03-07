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

for my $extension ("xls", "xlsx") {

    my $mech = Test::WWW::Mechanize->new;

    $mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
    my $response = decode_json $mech->content;
    print STDERR Dumper $response;
    is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
    my $sgn_session_id = $response->{access_token};
    print STDERR $sgn_session_id . "\n";

    my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id();

    #test uploading soil data
    my $file = $f->config->{basepath} . "/t/data/trial/soil_data.$extension";
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/trial/upload_soil_data',
        Content_Type => 'form-data',
        Content      => [
            "soil_data_upload_file" => [
                $file,
                "soil_data.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "soil_data_trial_id"    => $trial_id,
            "soil_data_description" => 'test soil data',
            "changed"               => '2022-Jun-15',
            "soil_data_gps"         => '-12.654348, -39.080347',
            "type_of_sampling"      => 'Soil 0-30 cm deep',
            "sgn_session_id"        => $sgn_session_id
        ]
    );
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 }, "check soil upload");

    #test retrieving soil data
    $mech->post_ok("http://localhost:3010/ajax/breeders/trial/$trial_id/all_soil_data", "check post");
    $response = decode_json $mech->content;

    my $data = $response->{'data'};
    print STDERR "DATA : ".Dumper($data);
    my $soil_data = $data->[0];
    is($soil_data->{'description'},'test soil data', "soil description test");
    is($soil_data->{'date'}, '2022-Jun-15', "soil date test");
    is($soil_data->{'gps'}, '-12.654348, -39.080347', "soil gps test");
    is($soil_data->{'type_of_sampling'}, 'Soil 0-30 cm deep', "type of sampling test");

    my $prop_id = $soil_data->{'prop_id'};

    #test deleting soil data
    $mech->post_ok("http://localhost:3010/ajax/breeders/trial/$trial_id/delete_soil_data", [ 'prop_id' => $prop_id ], "check soil delete post");
    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    $f->clean_up_db();
}

done_testing();

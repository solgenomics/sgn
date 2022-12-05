use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::BreedersToolbox::Projects;
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;


my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

for my $extension ("xls", "xlsx") {

    my $mech = Test::WWW::Mechanize->new;

    $mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
    my $response = decode_json $mech->content;
    is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
    my $session_id = $response->{access_token};

    my $program_rs = $schema->resultset('Project::Project')->find({ name => 'test' });
    my $program_id = $program_rs->project_id();

    my $profile_json_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'product_profile_json', 'project_property')->cvterm_id();
    my $before_adding_profile_all_projectprop = $schema->resultset("Project::Projectprop")->search({})->count();
    my $before_adding_profile_projectprop = $schema->resultset("Project::Projectprop")->search({ project_id => $program_id, type_id => $profile_json_type_id })->count();

    my $file = $f->config->{basepath} . "/t/data/product_profile_test.$extension";
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/breeders/program/upload_profile',
        Content_Type => 'form-data',
        Content      => [
            "profile_uploaded_file" => [
                $file,
                "product_profile_test.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "profile_program_id"    => $program_id,
            "new_profile_name"      => 'product_profile_1',
            "new_profile_scope"     => 'test_upload',
            "sgn_session_id"        => $session_id
        ]
    );

    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_adding_profile_all_projectprop = $schema->resultset("Project::Projectprop")->search({})->count();
    my $after_adding_profile_projectprop = $schema->resultset("Project::Projectprop")->search({ project_id => $program_id, type_id => $profile_json_type_id })->count();
    is($after_adding_profile_all_projectprop, $before_adding_profile_all_projectprop + 1);
    is($after_adding_profile_projectprop, $before_adding_profile_projectprop + 1);
    $f->clean_up_db();
}

done_testing();

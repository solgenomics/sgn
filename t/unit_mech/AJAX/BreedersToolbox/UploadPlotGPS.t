
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

    my $breeding_program_id = $schema->resultset('Project::Project')->find({ name => 'test' })->project_id();

    my $file = $f->config->{basepath} . "/t/data/trial/test_trial_plot_gps.$extension";
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/breeders/trial/137/upload_plot_gps',
        Content_Type => 'form-data',
        Content      => [
            trial_upload_plot_gps_file => [
                $file,
                "test_trial_plot_gps.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
        "sgn_session_id" => $sgn_session_id
        ]
    );

    print STDERR Dumper $response;
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    is_deeply($message_hash, { 'success' => 1 });

    $f->clean_up_db();
}
done_testing();

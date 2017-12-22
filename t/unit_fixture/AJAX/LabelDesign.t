
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->get_ok("http://localhost:3010//tools/label_designer/retrieve_longest_fields?data_type=Trials&value=139");
my $response = $mech->content;

my $expected_response = (
    "accession_name" => "UG120054",
    "trial_name" => "Kasese solgs trial",
    "year" => "2014",
    "plot_number" => "35667",
    "rep_number" => "1",
    "block_number" => "10",
    "accession_id" => 38926,
    "plot_id" => 39295,
    "plot_name" => "KASESE_TP2013_1000",
    "pedigree_string" => "NA/NA"
);

is($response, $expected_response, 'retrieve longest fields test');

$mech->post_ok('http://localhost:3010/tools/label_designer/download', [ 'download_type' => $download_type, 'data_type' => $data_type, 'value'=> $value, 'design_json' => $design_json ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'filename'}, '');


done_testing;

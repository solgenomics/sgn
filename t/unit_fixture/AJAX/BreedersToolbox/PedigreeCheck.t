use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Chado::Stock;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');

my @accessions_array = ("UG120041", "UG120285");
my $accessions_json = encode_json (\@accessions_array);
print STDERR "json accessions is $accessions_json";

$mech->post_ok('http://localhost:3010/ajax/accession_list/pedigree_check', ["accession_list"=> $accessions_json]);
$response = $mech->content;
print STDERR Dumper $response->{'score'};

is(scalar @{$response->{'score'}}, 1.09, 'check verify score response content');

done_testing();

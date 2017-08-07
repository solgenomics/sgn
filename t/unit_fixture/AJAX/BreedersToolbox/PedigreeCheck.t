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

print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successful');

$mech->post_ok('http://localhost:3010/ajax/accession_list/pedigree_check', [ "accession_list"=> '["UG120285"]']);
print STDERR Dumper $response->{'score'};

is(scalar @{$response->{'score'}}, 1.09, 'check verify score response content');

done_testing();

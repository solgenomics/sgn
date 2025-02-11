

# Tests stock deletion (obsoleted) function on stock detail page through AJAX request

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Chado::Stock;
use LWP::UserAgent;
use CXGN::List;
use CXGN::Stock::Accession;
use CXGN::Trial;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $metadata_schema = $f->metadata_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
my $json = JSON->new->allow_nonref;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
my $sgn_session_id = $response->{access_token};

my $previous_stock_count_all = $schema->resultset("Stock::Stock")->search({})->count();
my $previous_stock_count_obsolete = $schema->resultset("Stock::Stock")->search({is_obsolete=>1})->count();

my $stock_id = $schema->resultset("Stock::Stock")->find({name=>'test_accession1'})->stock_id;

$mech->get_ok('http://localhost:3010/stock/obsolete?stock_id='.$stock_id.'&is_obsolete=1'.'&obsolete_note="test"');
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $after_stock_count_all = $schema->resultset("Stock::Stock")->search({})->count();
my $after_stock_count_obsolete = $schema->resultset("Stock::Stock")->search({is_obsolete=>1})->count();

is($after_stock_count_all, $previous_stock_count_all);
is($after_stock_count_obsolete, $previous_stock_count_obsolete + 1);

done_testing();

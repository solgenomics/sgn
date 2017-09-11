use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/barcode/stock/download/pdf/',["stock_names" => "TestAccession1", "select_barcode_type" => "1D"] );
ok($mech->success);
$mech->content_contains('/static/documents/tempfiles/pdfs/pdf-');
#$response = $mech->content;
#print STDERR Dumper $response;


done_testing();

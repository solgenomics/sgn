
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
use Spreadsheet::Read;

use CXGN::Dataset;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $people_schema = $f->people_schema();

my $mech = Test::WWW::Mechanize->new;
my $response;

# login
#
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login with brapi call');

$response = decode_json $mech->content;

is($response->{'userDisplayName'}, 'Jane Doe', 'check login name');

# create a suitable dataset
#
my $ds = CXGN::Dataset->new( { schema=> $schema, people_schema => $people_schema });

$ds->trials( [ 139, 141 ]);
$ds->store();

my $dataset_id = $ds->sp_dataset_id();

$mech->get_ok('http://localhost:3010/tools/heritability', 'load heritability input page');

$mech->get_ok('http://localhost:3010/ajax/heritability/shared_phenotypes?dataset_id='.$dataset_id, 'get common traits for dataset');

my $sp_data = JSON::Any->decode($mech->content());

my $trait_id = $sp_data->{options}->[0]->[0];

$mech->get_ok('http://localhost:3010/ajax/heritability/generate_results?dataset_id='.$dataset_id.'&trait_id='.$trait_id, 'run the heritability analysis');

my $rdata = JSON::Any->decode($mech->content());

print STDERR "RDATA: ".Dumper($rdata);

# check if file names were returned
#
ok($rdata->{figure3}, "figure 3 returned");
ok($rdata->{figure4}, "figure 4 returned");
ok($rdata->{h2Table}, "h2Table returned");

# check if files were created
#
ok( -e "static/".$rdata->{figure3}, "figure 3 created");
#ok( -e "static/".$rdata->{figure4}, "figure 4 created");
ok( -e "static/".$rdata->{h2Table}, "table created");

# remove changes to the database
#
$ds->delete();

done_testing();

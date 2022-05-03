

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

$mech->get_ok('http://localhost:3010/tools/solgwas', 'load solgwas input page');

$mech->get_ok('http://localhost:3010/ajax/solgwas/shared_phenotypes?dataset_id='.$dataset_id, 'get common traits for dataset');

my $sp_data = JSON::Any->decode($mech->content());

my $trait_id = $sp_data->{options}->[0]->[1];

$mech->get_ok('http://localhost:3010/ajax/solgwas/generate_results?dataset_id='.$dataset_id.'&trait_id='.$trait_id.'&pc_check=0&kinship_check=0', 'run the solgwas analysis');

print STDERR "CONTENT: ".Dumper($mech->content());

my $rdata = JSON::Any->decode($mech->content());

print STDERR "RDATA: ".Dumper($rdata);

# check if file names were returned
#
ok($rdata->{figure3}, "Manhattan plot returned");
ok($rdata->{figure4}, "QQ plot returned");

# check if files were created
#
ok( -e "static/".$rdata->{figure3}, "Manhattan plot file created");
ok( -e "static/".$rdata->{figure4}, "QQ plot file created");

ok( -s "static/".$rdata->{figure3} > 10000, "Manhattan plot file has contents");
ok( -s "static/".$rdata->{figure4} > 10000, "QQ plot file has contents");

# remove changes to the database
#
$ds->delete();

done_testing();

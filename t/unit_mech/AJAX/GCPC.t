
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
use CXGN::List;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $people_schema = $f->people_schema();

my $mech = Test::WWW::Mechanize->new;
my $response;
#139 141
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
#replicate_factor =fixed
#studyDesign_factor = None
my $dataset_id = $ds->sp_dataset_id();
my $sin_id = CXGN::List::create_list($f->dbh, "si", "", 41);
my $si = CXGN::List-> new({dbh=>$f->dbh, list_id=>$sin_id});

$si-> type('dataset');
$si -> add_bulk(['traits:dry matter content percentage|CO_334:0000092,fresh root weight|CO_334:0000012,fresh shoot weight measurement in kg|CO_334:0000016',
                  'numbers:2,0.5,1',
                  'accessions:,,']);


$mech->get_ok('http://localhost:3010/tools/gcpc', 'load gcpc input page');

$mech->get_ok('http://localhost:3010/ajax/gcpc/factors?dataset_id='.$dataset_id, 'get factors for dataset');

my $sp_data = JSON::Any->decode($mech->content());

my $trait_id = $sp_data->{options}->[0]->[0];

$mech->get_ok('http://localhost:3010/ajax/gcpc/generate_results?dataset_id='.$dataset_id.'&trait_id='.$trait_id."&method_id=GCPC&replicate_factor=fixed&studyDesign_factor=None&sin_list_id=$sin_id", 'run the GCPC analysis');

sleep(2);

my $rdata = JSON::Any->decode($mech->content());

ok($rdata->{data}, "data created");
print STDERR "DATA: ".Dumper($rdata->{data});
#is($rdata-> {data}->[0]->[3], 1.3294458276476, "check specific no.");
 #remove changes to the database
#
$ds->delete();

done_testing();

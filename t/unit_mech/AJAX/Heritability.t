
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
use Text::CSV ("csv");

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

sleep(5);

my $rdata = JSON::Any->decode($mech->content());

print STDERR "RDATA: ".Dumper($rdata);

ok($rdata->{h2Table}, "h2TableJson returned");
ok($rdata->{h2CsvTable}, "h2CsvTable returned");

# check if files were created
ok( -e "static/".$rdata->{h2Table}, "table created");
ok( -e "static/".$rdata->{h2CsvTable}, "csv table file created");

my $test_basic_h2_file = csv(in => "static/".$rdata->{h2CsvTable});

is(@$test_basic_h2_file[1]->[1], 'dry matter content percentage', "check value of row name in a table");
is(@$test_basic_h2_file[1]->[5], '49.92', "check value of Vres fresh.root.weight in a table");

# run test for dataset with outliers but with false outliers parameter
my $outliers_included_dataset_id = 1;
my $outliers_included_trait_id = "fresh root weight";
$mech->get_ok('http://localhost:3010/ajax/heritability/generate_results?dataset_id='.$outliers_included_dataset_id.'&trait_id='.$outliers_included_trait_id, 'run the heritability analysis');

my $rdata_full_set = JSON::Any->decode($mech->content());
ok($rdata_full_set->{h2Table}, "h2TableJson returned");
ok($rdata_full_set->{h2CsvTable}, "h2CsvTable returned");

my $test_included_h2_file = csv(in => "static/".$rdata_full_set->{h2CsvTable});
is(@$test_included_h2_file[2]->[1], 'fresh root weight', "check value of row name in a table");
is(@$test_included_h2_file[2]->[5], '15.542', "check value of Heritability fresh.root.weight in a table");

# run test for dataset with outliers but with false outliers parameter
my $outliers_excluded_dataset_id = 1;
my $outliers_excluded_trait_id = "dry matter content percentage";

# run test for dataset with outliers but with true outliers parameter
$mech->get_ok('http://localhost:3010/ajax/heritability/generate_results?dataset_id='.$outliers_excluded_dataset_id.'&trait_id='.$outliers_excluded_trait_id.'&dataset_trait_outliers=1', 'run the heritability analysis');
my $rdata_excluded_set = JSON::Any->decode($mech->content());

# check if names are created in jsn response
ok($rdata_excluded_set->{h2Table}, "h2TableJson returned");
ok($rdata_excluded_set->{h2CsvTable}, "h2CsvTable returned");

# check if files were created
ok( -e "static/".$rdata_excluded_set->{h2Table}, "table created");
ok( -e "static/".$rdata_excluded_set->{h2CsvTable}, "csv table file created");

# check if values are changed for set with outliers excluded
my $test_excluded_h2_file = csv(in => "static/".$rdata_excluded_set->{h2CsvTable});
is(@$test_excluded_h2_file[2]->[1], 'fresh root weight', "check value of row name in a table");
is(@$test_excluded_h2_file[2]->[5], '8.864', "check value of Heritability fresh.root.weight in a table");

# remove changes to the database
#
$ds->delete();

done_testing();

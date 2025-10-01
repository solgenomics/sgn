use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use Data::Dumper;
use File::Basename;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $mech = Test::WWW::Mechanize->new();
my $data;
my $submit_result;

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
my $sgn_session_id = $response->{access_token};

my $test_file = 't/data/multi_image_analysis_test.jpg';

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();
my $stock_id = $row->stock_id();

$data = '[{"germplasmDbId":"41281","locationDbId":"23","observationUnitName":"Testing Plant","programDbId":"134","studyDbId":"165","trialDbId":"165","observationUnitPosition":{"observationLevel":{"levelName":"plant","levelCode":"plant_1"},"observationLevelRelationships":[{"levelCode":"' . $stock_id. '","levelName":"plot"}],"positionCoordinateX":"74","positionCoordinateXType":"GRID_COL","positionCoordinateY":"03","positionCoordinateYType":"GRID_ROW"}, "additionalInfo" : {"observationUnitParent":"' . $stock_id. '"} }]';
$mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => $data);
$response = decode_json $mech->content;

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();

my $plant_id = $row->stock_id();

$mech->get_ok("/image/add?type=stock&type_id=$plant_id");

$mech->get_ok("/image/add?action=new&type=stock&type_id=$plant_id");

my %form = (
    form_name => 'upload_image_form',
    fields => {
        file => $test_file,
        type => 'stock',
        type_id => $plant_id,
        refering_page => 'http://google.com',
    },
);

$mech->submit_form_ok(\%form, "Form submitted");

my $store_form = {
    form_name => 'store_image',
};

$mech->submit_form_ok($store_form, "Submitting multi analysis image for storage");
$mech->content_contains('SGN Image');
$mech->content_contains(basename($test_file));

my $uri = $mech->uri();
my $image_id = "";
if ($uri =~ /\/(\d+)$/) {
    $image_id =$1;
}

$mech->post_ok('http://localhost:3010/ajax/image_analysis/submit', ["selected_image_ids"=> $image_id, 'service'=> 'plantcv_citrus_app', 'trait'=> 'Fruit Diameter|INV:0000118']);
$submit_result = decode_json $mech->content;

is( $submit_result->{results}[0]{result}{value}, '651.52', "value matches" );

ok(ref($submit_result->{results}) eq 'ARRAY', "results array returned from submit");

# Image analysis group
$mech->post_ok('http://localhost:3010/ajax/image_analysis/group', [
    'result' => encode_json($submit_result->{results}),
], 'group image analysis results');
my $group_result = decode_json $mech->content;
ok($group_result->{success}, "image analysis group success");
ok(ref($group_result->{results}) eq 'ARRAY', "results array returned from group");

# Save results: create tissue samples via BrAPI
my $table_data = $group_result->{results};

# Create tissue sample
$tissueSamplesData = '[{"additionalInfo":{"observationUnitParent":" ' . $plant_id . '"},"observationUnitName":"FruitDiameter_"' . $table_data->[0]{observationUnitName} .'_sample1","studyDbId":144,"germplasmDbId":38878,"observationUnitPosition":{"observationLevel":{"levelName":"tissue_sample","levelCode":"' . $plant_id . '","levelOrder":4},"observationLevelRelationships":[{"levelName":"plant","observationUnitDbId":"' . $plant_id . '","levelOrder":4}],"positionCoordinateX":null,"positionCoordinateY":null,"geoCoordinates":null}}]';

$mech->post_ok('http://localhost:3010/brapi/v2/observationunits', Content => $tissueSamplesData);
my $tissue_resp = decode_json $mech->content;
ok($tissue_resp->{result}{data}[0]{observationUnitDbId}, "Tissue sample created via BrAPI");

# Get created tissue sample
$mech->get_ok('http://localhost:3010/brapi/v2/observationunits?observationUnitName=FruitDiameter_"IITA-TMS-IBA980581_001"_sample1', 'get tissue sample');

done_testing();


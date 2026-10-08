use strict;
use warnings;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use Test::LWP::UserAgent;
use SGN::Test::WWW::Mechanize;
use CXGN::Image;
use CXGN::Stock;
use CXGN::Chado::Stock;
use JSON;
use Data::Dumper;
use File::Basename;
use HTTP::Response;
use Test::MockModule;
use Test::Deep;

# Set up Test::LWP::UserAgent to mock the external service
my $mock_ua = Test::LWP::UserAgent->new;

$mock_ua->map_response(
    qr|http://fake-image-analysis-service/|,
HTTP::Response->new(
        200,
        'OK',
        [ 'Content-Type' => 'application/json' ],
        '{"trait_value":"651.52","image_link":"http://localhost/fake_image.png"}'
)
    );

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $mech = SGN::Test::WWW::Mechanize->new();
my $data;
my $submit_result;

# Return mocked HTTP client
{
    no warnings 'redefine';
    require LWP::UserAgent;
    *LWP::UserAgent::new = sub { return $mock_ua };
}

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
my $sgn_session_id = $response->{access_token};

my $test_file = 't/data/multi_image_analysis_test.jpg';

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();
my $stock_id = $row->stock_id();

# Create test plant
$data = '[{"germplasmDbId":"41281","locationDbId":"23","observationUnitName":"Testing Plant","programDbId":"134","studyDbId":"165","trialDbId":"165","observationUnitPosition":{"observationLevel":{"levelName":"plant","levelCode":"plant_1"},"observationLevelRelationships":[{"levelCode":"' . $stock_id. '","levelName":"plot"}],"positionCoordinateX":"74","positionCoordinateXType":"GRID_COL","positionCoordinateY":"03","positionCoordinateYType":"GRID_ROW"}, "additionalInfo" : {"observationUnitParent":"' . $stock_id. '"} }]';
$mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => $data);
$response = decode_json $mech->content;

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();

my $plant_id = $row->stock_id();

$mech->get_ok("/image/add?type=stock&type_id=$plant_id");

$mech->get_ok("/image/add?action=new&type=stock&type_id=$plant_id");

# Store image associated with created plant
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

# Image analysis submit
$mech->post_ok('http://localhost:3010/ajax/image_analysis/submit', ["selected_image_ids"=> $image_id, 'service'=> 'plantcv_citrus_app', 'trait'=> 'Fruit Diameter|INV:0000118']);
$submit_result = decode_json $mech->content;
ok(ref($submit_result->{results}) eq 'ARRAY', "results array returned from submit");

my $test_submit_result = {
    results => [
        {
            stock_type_name      => 'plant',
            image_obsolete       => 0,
            tags_array           => [],
            image_create_date    => '2026-03-26T14:55:08+00:00',
            image_username       => 'janedoe',
            image_name           => '',
            stock_id             => 45627,
            image_description    => '',
            project_id           => undef,
            observations_array   => [],
            image_md5sum         => 'fd65dd78259d7d32c010d533005a7e4a',
            stock_uniquename     => 'geo_test-rep1-geo_accession1_1_plant_1',
            image_original_filename => '45627_branching_5_2025-03-24',
            project_md_image_id  => undef,
            project_name         => undef,
            related_stocks_array => [
                { stock_id => 41784, uniquename => 'geo_test-rep1-geo_accession1_1' },
                { stock_id => 41782, uniquename => 'geo_accession1' },
            ],
            image_file_ext       => '.jpg',
            image_modified_date  => '2026-03-26T14:55:09+00:00',
            project_image_type_name => undef,
            result => {
                original_image      => 'https://breedbase.org/data/images/image_files_test/fd/65/dd/78/259d7d32c010d533005a7e4a/45627_branching_5_2025-03-24.jpg',
                subanalyses          => {
                    obj_001 => {
                        'amylopectin content ug/g in percentage|CO_334:0000121' => {
                            image_link  => undef,
                            trait_value => '0.9789',
                        },
                        'amylose amylopectin root content ratio | CO_334:0000124' => {
                            image_link  => undef,
                            trait_value => '17.71',
                        },
                    },
                    obj_002 => {
                        'amylopectin content ug/g in percentage|CO_334:0000121' => {
                            image_link  => undef,
                            trait_value => '14.77',
                        },
                        'amylose amylopectin root content ratio | CO_334:0000124' => {
                            trait_value => '1.0068',
                            image_link  => undef,
                        },
                    },
                },
                image_link            => '/data/images/image_files_test/cd/b2/62/95/67cc83a541093e9bcf4c4666/imageUbaX.png',
                analysis_info         => {},
                analyzed_image_id     => 2612,
                analyzed_image_overlay => 'https://multi-trait-analysis.breedbase.org/download/home_production_volume_public_images_image_files_test_fd_65_dd_78_259d7d32c010d533005a7e4a_45627_branching_5_2025-03-24_09770ca3-3f4e-4ef3-94e8-06df08f0c58e_ResultImage_ccaccd00-487f-4343-957b-fa444a87abfa.png',
            },
            image_sp_person_id => 41,
            image_id           => 2610,
        }
    ]
};

# Image analysis group
$mech->post_ok('http://localhost:3010/ajax/image_analysis/group', [
    'result' => encode_json($test_submit_result->{results}),
], 'group image analysis results');
my $group_result = decode_json $mech->content;
ok($group_result->{success}, "image analysis group success");

ok(ref($group_result->{results}) eq 'HASH', "results hash returned from group");
ok(ref($group_result->{results}{table_data}) eq 'ARRAY', "table_data array in results");

# Save results: create tissue samples via BrAPI
my $table_data = $group_result->{results}{table_data};

# Create tissue sample
my $tissueSamplesData = '[{"additionalInfo":{"observationUnitParent":" ' . $plant_id . '"},"observationUnitName":"FruitDiameter_"' . $table_data->[0]{observationUnitName} .'_sample1","studyDbId":144,"germplasmDbId":38878,"observationUnitPosition":{"observationLevel":{"levelName":"tissue_sample","levelCode":"' . $plant_id . '","levelOrder":4},"observationLevelRelationships":[{"levelName":"plant","observationUnitDbId":"' . $plant_id . '","levelOrder":4}],"positionCoordinateX":null,"positionCoordinateY":null,"geoCoordinates":null}}]';

$mech->post_ok('http://localhost:3010/brapi/v2/observationunits', Content => $tissueSamplesData);
my $tissue_resp = decode_json $mech->content;
ok($tissue_resp->{result}{data}[0]{observationUnitDbId}, "Tissue sample created via BrAPI");

# Get created tissue sample
$mech->get_ok('http://localhost:3010/brapi/v2/observationunits?observationUnitName=FruitDiameter_"IITA-TMS-IBA980581_001"_sample1', 'get tissue sample');

# Delete test image
my $dbh = SGN::Test::Fixture->new()->dbh();
my $i = CXGN::Image->new(dbh => $dbh, image_id => $image_id, image_dir => $mech->context->config->{'image_dir'});
$i->hard_delete();

$f->clean_up_db();
done_testing();
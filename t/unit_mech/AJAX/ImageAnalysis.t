use strict;
use warnings;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use Test::LWP::UserAgent;
use SGN::Test::WWW::Mechanize;
use CXGN::Image;
use CXGN::Stock;
use CXGN::Trial;
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


# create_run_project tests

# A trial to attach the run to. Use an existing fixture trial id.
my $trial_rs = $schema->resultset('Project::Project')->search(
    undef, { rows => 1, order_by => { -desc => 'project_id' } }
);
my $trial_id = $trial_rs->first->project_id();

# Source stock (reuse the stock from the submit test)
my $source_stock_id = $stock_id;

# A couple of tissue sample stocks to link. Grab two existing stocks.
my @ts_rows = $schema->resultset('Stock::Stock')->search(
    undef, { rows => 2, order_by => { -desc => 'stock_id' } }
)->all;
my @tissue_sample_ids = map { $_->stock_id } @ts_rows;

my $tissue_samples_json = encode_json([
    map { { stock_id => $_, result_image_id => undef } } @tissue_sample_ids
]);

# Trait ids to associate (use real cvterm ids from the fixture)
my $trait_cvterm = $schema->resultset('Cv::Cvterm')->search(
    undef, { rows => 1 }
)->first;
my $trait_id_1 = $trait_cvterm->cvterm_id();
my $trait_ids_json = encode_json([ $trait_id_1 ]);

# analysis_info_json carrying analysis_metadata
my $analysis_info_json = encode_json({
    analysis_metadata => {
        job_id              => 'test-job-123',
        timestamp           => '2026-07-09T20:32:28+00:00',
        pipeline_name       => 'seed_size_shape',
        pipeline_version    => '0.1.0',
        input_filename      => 'test_input.jpg',
        qc_json             => encode_json({ object_count => 2, analysis_pass => JSON::true }),
        output_mode         => 'all',
        traits_emitted_json => encode_json([ 'Object Area|IMGSTAT:0000006' ]),
        raw_result_json     => encode_json({
            objects => [
                { object_id => 'obj_001', source_label => '1',
                  traits => { 'Object Area|IMGSTAT:0000006' => { value => 12.01 } } },
                { object_id => 'obj_002', source_label => '2',
                  traits => { 'Object Area|IMGSTAT:0000006' => { value => 14.46 } } },
            ],
            traits_emitted => [ 'Object Area|IMGSTAT:0000006' ],
        }),
    }
});

my $run_name = 'ImageAnalysisRun_test_' . time();

# --- Happy path: create a run project -------------------------------

$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        trial_id           => $trial_id,
        run_name           => $run_name,
        service_name       => 'Image Multi Object Multi Trait Analysis',
        run_date           => '2026-07-09',
        analysis_info_json => $analysis_info_json,
        source_stock_id    => $source_stock_id,
        source_image_id    => $image_id,
        overlay_image_id   => $image_id,
        trait_ids          => $trait_ids_json,
        tissue_samples     => $tissue_samples_json,
    ]
);

my $create_result = decode_json $mech->content;
print STDERR "create result: " . Dumper $create_result;
ok($create_result->{success}, "create_run_project returned success");
ok($create_result->{run_project_id}, "run_project_id returned");
is($create_result->{run_name}, $run_name, "run_name echoed back");
is($create_result->{traits_associated}, 1, "one trait associated");

my $run_project_id = $create_result->{run_project_id};

# --- Verify the project was created ---------------------------------

my $project = $schema->resultset('Project::Project')->find({ project_id => $run_project_id });
ok($project, "run project row exists in the database");
is($project->name(), $run_name, "project name matches run_name");

# --- Verify the design projectprop marks it as an analysis run ------

my $design_id = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'design', 'project_property')->cvterm_id();
my $design_prop = $schema->resultset('Project::Projectprop')->find({
    project_id => $run_project_id,
    type_id    => $design_id,
});
ok($design_prop, "design projectprop exists");
is($design_prop->value, 'image_analysis_run', "design value is image_analysis_run");

# --- Verify pipeline metadata projectprops --------------------------

my %expect_meta = (
    image_analysis_pipeline_name    => 'seed_size_shape',
    image_analysis_pipeline_version => '0.1.0',
    image_analysis_job_id           => 'test-job-123',
    image_analysis_input_filename   => 'test_input.jpg',
);
foreach my $term (sort keys %expect_meta) {
    my $tid = SGN::Model::Cvterm->get_cvterm_row(
        $schema, $term, 'project_property')->cvterm_id();
    my $prop = $schema->resultset('Project::Projectprop')->find({
        project_id => $run_project_id,
        type_id    => $tid,
    });
    ok($prop, "$term projectprop exists");
    is($prop->value, $expect_meta{$term}, "$term value correct");
}

# --- Verify raw_result_json stored ----------------------------------

my $raw_id = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'image_analysis_raw_result_json', 'project_property')->cvterm_id();
my $raw_prop = $schema->resultset('Project::Projectprop')->find({
    project_id => $run_project_id,
    type_id    => $raw_id,
});
ok($raw_prop && $raw_prop->value, "raw_result_json projectprop stored");
my $stored_raw = decode_json($raw_prop->value);
is(scalar(@{ $stored_raw->{objects} }), 2, "raw result has 2 objects");

# --- Verify trait association (projectprop keyed on trait cvterm) ---

my $trait_prop = $schema->resultset('Project::Projectprop')->find({
    project_id => $run_project_id,
    type_id    => $trait_id_1,
});
ok($trait_prop, "trait association projectprop exists");
is($trait_prop->value, 1, "trait association value is 1");

# --- Verify the run-on-trial relationship ---------------------------

my $rel_id = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'image_analysis_run_on_field_trial', 'project_relationship')->cvterm_id();
my $rel = $schema->resultset('Project::ProjectRelationship')->find({
    subject_project_id => $run_project_id,
    object_project_id  => $trial_id,
    type_id            => $rel_id,
});
ok($rel, "run project is linked to the field trial");

# --- Verify nd_experiment + stock links -----------------------------

my $exp_type_id = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'image_analysis_experiment', 'experiment_type')->cvterm_id();

my $nep_rs = $schema->resultset('NaturalDiversity::NdExperimentProject')->search({
    project_id => $run_project_id,
});
is($nep_rs->count, 1, "one nd_experiment linked to run project");

my $nd_experiment_id = $nep_rs->first->nd_experiment_id;
my $nes_rs = $schema->resultset('NaturalDiversity::NdExperimentStock')->search({
    nd_experiment_id => $nd_experiment_id,
});
# source stock + 2 tissue samples = 3
is($nes_rs->count, 1 + scalar(@tissue_sample_ids),
   "nd_experiment links source stock and tissue samples");

# source stock is among the linked stocks
my %linked_stocks = map { $_->stock_id => 1 } $nes_rs->all;
ok($linked_stocks{$source_stock_id}, "source stock linked to nd_experiment");
ok($linked_stocks{$tissue_sample_ids[0]}, "first tissue sample linked");

# --- Verify source image link (phenome.project_md_image) ------------

my $src_img_type_id = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'image_analysis_source_image', 'project_md_image')->cvterm_id();
my $dbh = $schema->storage->dbh();
my $img_check = $dbh->prepare(
    "SELECT count(*) FROM phenome.project_md_image
      WHERE project_id = ? AND image_id = ? AND type_id = ?"
);
$img_check->execute($run_project_id, $image_id, $src_img_type_id);
my ($src_img_count) = $img_check->fetchrow_array();
is($src_img_count, 1, "source image linked to run project");

# create_run_project validation / error tests

# Missing required params -> error
$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        run_name       => 'incomplete_run',
        tissue_samples => $tissue_samples_json,
        # no trial_id / source_stock_id / source_image_id
    ]
);
my $err1 = decode_json $mech->content;
ok($err1->{error}, "error returned when required params missing");
like($err1->{error}, qr/required/, "error mentions required params");

# No tissue samples -> error
$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        trial_id        => $trial_id,
        run_name        => 'no_samples_run_' . time(),
        service_name    => 'Test',
        run_date        => '2026-07-09',
        source_stock_id => $source_stock_id,
        source_image_id => $image_id,
        tissue_samples  => '[]',
    ]
);
my $err2 = decode_json $mech->content;
ok($err2->{error}, "error returned when no tissue samples");
like($err2->{error}, qr/tissue_sample/, "error mentions tissue_sample");

# run_object_results test (uses the run project created above)

$mech->get_ok(
    "http://localhost:3010/ajax/image_analysis/run_object_results?run_project_id=$run_project_id"
);
my $ror = decode_json $mech->content;
ok($ror->{success}, "run_object_results returned success");
ok(ref($ror->{table_data}) eq 'ARRAY', "table_data is an array");
is(scalar(@{ $ror->{table_data} }), 1, "one trait row in table_data");

my $trait_row = $ror->{table_data}->[0];
is($trait_row->{observationVariableName}, 'Object Area', "trait name parsed");
is($trait_row->{numberAnalyzed}, 2, "two objects analyzed for the trait");
is(scalar(@{ $trait_row->{details} }), 2, "two detail rows");
# mean of 12.01 and 14.46 = 13.235
cmp_ok(abs($trait_row->{value} - 13.2350), '<', 0.001, "mean value computed correctly");

# --- Verify object_name carries the source_label ---------------------

my %detail_by_object = map { $_->{object_name} => $_ } @{ $trait_row->{details} };
ok(exists $detail_by_object{'1'}, "detail exists for object source_label 1");
ok(exists $detail_by_object{'2'}, "detail exists for object source_label 2");
is($detail_by_object{'1'}->{value}, 12.01, "object 1 value correct");
is($detail_by_object{'2'}->{value}, 14.46, "object 2 value correct");

# run_object_results validation / edge cases

# Missing run_project_id -> error
$mech->get_ok('http://localhost:3010/ajax/image_analysis/run_object_results');
my $ror_err = decode_json $mech->content;
ok($ror_err->{error}, "error returned when run_project_id missing");
like($ror_err->{error}, qr/run_project_id/, "error mentions run_project_id");

# A project with no raw_result_json -> graceful empty result
# (use the trial project id, which has no image-analysis raw result)
$mech->get_ok(
    "http://localhost:3010/ajax/image_analysis/run_object_results?run_project_id=$trial_id"
);
my $ror_empty = decode_json $mech->content;
ok($ror_empty->{error}, "error returned when no stored analysis results");
ok(ref($ror_empty->{table_data}) eq 'ARRAY', "table_data present as empty array");
is(scalar(@{ $ror_empty->{table_data} }), 0, "table_data is empty");

# Delete test image
my $dbh = SGN::Test::Fixture->new()->dbh();
my $i = CXGN::Image->new(dbh => $dbh, image_id => $image_id, image_dir => $mech->context->config->{'image_dir'});
$i->hard_delete();

$f->clean_up_db();
done_testing();
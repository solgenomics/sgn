use strict;
use warnings;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SGN::Test::OwnedTrialCleanup;
use Test::LWP::UserAgent;
use SGN::Test::WWW::Mechanize;
use CXGN::Image;
use SGN::Image;
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use CXGN::Stock;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
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


# Use unique request names to recover an owned row even if an HTTP response
# fails after commit. ID cutoffs alone do not establish ownership.
my $owned_prefix = 'image_analysis_http_'.$$.'_'.time();
my %owned_run_names = map { ($owned_prefix.'_'.$_) => undef } qw(single multi same duplicate);
my (%owned_images, %upload_sources, %original_trials);
my $before_image_id = $f->dbstats_start->{images} || 0;
my $before_project_id = $f->dbstats_start->{projects} || 0;
my $cleanup_done = 0;
my $upload_dir = tempdir('sgn-image-analysis-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $test_file = $upload_dir.'/'.$owned_prefix.'.jpg';
copy('t/data/multi_image_analysis_test.jpg', $test_file) or die "Cannot copy synthetic image: $!";

# Fixture cleanup deletes new rows; it cannot undo updates to existing flags,
# recorded design tags, occurrence versions or layout caches.
my $remember_trial = sub {
    my ($trial_id) = @_;
    return if exists $original_trials{$trial_id};
    my $db = $schema->storage->dbh;
    my $unit_ids = $db->selectcol_arrayref(q{
        SELECT DISTINCT es.stock_id FROM nd_experiment_project ep
        JOIN nd_experiment ne USING(nd_experiment_id)
        JOIN cvterm et ON et.cvterm_id=ne.type_id
        JOIN nd_experiment_stock es USING(nd_experiment_id)
        WHERE ep.project_id=? AND et.name='field_layout'
    }, undef, $trial_id);
    $original_trials{$trial_id} = {
        unit_ids => $unit_ids,
        projectprops => $db->selectall_arrayref(
            'SELECT projectprop_id,project_id,type_id,value,rank FROM projectprop WHERE project_id=? ORDER BY projectprop_id', undef, $trial_id),
        stockprops => @$unit_ids ? $db->selectall_arrayref(
            'SELECT stockprop_id,stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) ORDER BY stockprop_id', undef, $unit_ids) : [],
    };
};
my $restore_trial = sub {
    my ($trial_id, $restore_stockprops) = @_;
    my $db = $schema->storage->dbh;
    my $snapshot = $original_trials{$trial_id};
    my @tables = (['projectprop', 'projectprop_id', 'project_id', [$trial_id], $snapshot->{projectprops}]);
    push @tables, ['stockprop', 'stockprop_id', 'stock_id', $snapshot->{unit_ids}, $snapshot->{stockprops}]
        if $restore_stockprops && @{$snapshot->{unit_ids}};
    for my $table (@tables) {
        my ($name, $key, $parent, $parent_ids, $rows) = @$table;
        my @ids = map { $_->[0] } @$rows;
        $db->do("DELETE FROM $name WHERE $parent=ANY(?) AND NOT ($key=ANY(?))", undef, $parent_ids, \@ids);
        for my $row (@$rows) {
            $db->do("INSERT INTO $name ($key,$parent,type_id,value,rank) VALUES (?,?,?,?,?) " .
                "ON CONFLICT ($key) DO UPDATE SET $parent=EXCLUDED.$parent,type_id=EXCLUDED.type_id,value=EXCLUDED.value,rank=EXCLUDED.rank " .
                "WHERE ($name.$parent,$name.type_id,$name.value,$name.rank) IS DISTINCT FROM (EXCLUDED.$parent,EXCLUDED.type_id,EXCLUDED.value,EXCLUDED.rank)",
                undef, @$row);
        }
    }
};

my $remember_image = sub {
    my ($id, $stock_id) = @_;
    return unless defined($id) && $id =~ /^[1-9]\d*$/;
    die "Refusing baseline image $id" unless $id > $before_image_id;
    $owned_images{$id} = $stock_id;
};
my $remember_run = sub {
    my ($name, $id) = @_;
    return unless defined($id) && $id =~ /^[1-9]\d*$/;
    die "Refusing baseline run project $id" unless $id > $before_project_id;
    die "Unregistered run name $name" unless exists $owned_run_names{$name};
    $owned_run_names{$name} = $id;
};
my $checkpoint = sub {
    my ($stage) = @_;
    die "Deliberate ImageAnalysis failure: $stage\n"
        if ($ENV{SGN_TEST_IMAGE_ANALYSIS_FAIL} // '') eq $stage;
};

my $cleanup = sub {
    return 1 if $cleanup_done;
    my $db = $schema->storage->dbh;
    my @names = keys %owned_run_names;
    my $runs = $db->selectall_arrayref(q{
        SELECT project_id, name FROM project WHERE project_id>? AND name=ANY(?)
    }, {Slice => {}}, $before_project_id, \@names);
    my %run_ids;
    for my $run (@$runs) {
        my ($id, $name) = @{$run}{qw(project_id name)};
        die "Run identity changed for $name" if defined($owned_run_names{$name}) && $owned_run_names{$name} != $id;
        $run_ids{$id} = 1;
    }
    # The unique upload name, declared owner and new ID recover a
    # committed upload whose returned page could not be decoded by the test.
    my $images = $db->selectcol_arrayref(q{
        SELECT image_id FROM metadata.md_image
        WHERE image_id>? AND name=ANY(?) AND sp_person_id=41
    }, undef, $before_image_id, [basename($test_file), $test_file]);
    $owned_images{$_} //= undef for @$images;
    for my $id (@{$db->selectcol_arrayref('SELECT image_id FROM metadata.md_image WHERE image_id>?', undef, $before_image_id)}) {
        die "Unowned new image $id prevents fixture cleanup" unless exists $owned_images{$id};
    }
    for my $row (@{$db->selectall_arrayref('SELECT project_id,name FROM project WHERE project_id>?', undef, $before_project_id)}) {
        die "Unowned new project $row->[0] prevents fixture cleanup" unless $run_ids{$row->[0]};
    }
    my @image_ids = sort {$a <=> $b} keys %owned_images;
    my @run_ids = sort {$a <=> $b} keys %run_ids;
    $schema->txn_do(sub {
        # Verify the complete link boundary before native hard_delete removes
        # any files or stock/tag/locus links. Unknown consumers remain intact.
        my $foreign_keys = $db->selectall_arrayref(q{
            SELECT ns.nspname, cl.relname, att.attname
            FROM pg_constraint fk
            JOIN pg_class cl ON cl.oid=fk.conrelid
            JOIN pg_namespace ns ON ns.oid=cl.relnamespace
            JOIN pg_attribute att ON att.attrelid=fk.conrelid AND att.attnum=fk.conkey[1]
            WHERE fk.contype='f' AND fk.confrelid='metadata.md_image'::regclass
        });
        for my $id (@image_ids) {
            my $image = $db->selectrow_hashref('SELECT name,sp_person_id FROM metadata.md_image WHERE image_id=?', undef, $id);
            next unless $image; # An END retry may follow an already deleted image.
            die "Image $id no longer matches the synthetic upload"
                unless basename($image->{name}) eq basename($test_file) && $image->{sp_person_id} == 41;
            for my $stock_id (@{$db->selectcol_arrayref('SELECT stock_id FROM phenome.stock_image WHERE image_id=?', undef, $id)}) {
                die "Image $id is shared with stock $stock_id"
                    unless $upload_sources{$stock_id} && (!defined($owned_images{$id}) || $owned_images{$id} == $stock_id);
            }
            for my $project_id (@{$db->selectcol_arrayref('SELECT project_id FROM phenome.project_md_image WHERE image_id=?', undef, $id)}) {
                die "Image $id is shared with project $project_id" unless $run_ids{$project_id};
            }
            for my $fk (@$foreign_keys) {
                my ($namespace, $table, $column) = @$fk;
                next if "$namespace.$table" =~ /^(?:phenome\.(?:stock_image|project_md_image)|metadata\.md_tag_image)$/;
                my $table_sql = $db->quote_identifier($namespace, $table);
                my $column_sql = $db->quote_identifier($column);
                die "Image $id has another consumer in $namespace.$table"
                    if $db->selectrow_array("SELECT count(*) FROM $table_sql WHERE $column_sql=?", undef, $id);
            }
        }
        for my $id (@run_ids) {
            for my $image_id (@{$db->selectcol_arrayref('SELECT image_id FROM phenome.project_md_image WHERE project_id=?', undef, $id)}) {
                die "Run project $id refers to an unowned image $image_id" unless exists $owned_images{$image_id};
            }
        }
        for my $id (@image_ids) {
            $db->do('DELETE FROM phenome.project_md_image WHERE image_id=? AND project_id=ANY(?)', undef, $id, \@run_ids);
        }
    });
    for my $id (@image_ids) {
        next unless $db->selectrow_array('SELECT count(*) FROM metadata.md_image WHERE image_id=?', undef, $id);
        SGN::Image->new($db, $id, $mech->context)->hard_delete;
        die "Native deletion retained image $id"
            if $db->selectrow_array('SELECT count(*) FROM metadata.md_image WHERE image_id=?', undef, $id);
    }
    # Native image deletion must precede Fixture's stock-before-metadata order.
    # Keep the original fixture cutoffs; creating another Fixture would lose them.
    $f->clean_up_db;
    $schema->txn_do(sub {
        for my $trial_id (sort {$a <=> $b} keys %original_trials) {
            $restore_trial->($trial_id, 1);
            CXGN::Trial::TrialLayout->new({
                schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout',
            })->generate_and_cache_layout;
            # Cache generation replaces its projectprop. Restore original cache
            # IDs/bytes after rebuilding from the restored original source rows.
            $restore_trial->($trial_id, 0);
        }
    });
    die 'Owned run projects remain after fixture cleanup'
        if @run_ids && $db->selectrow_array('SELECT count(*) FROM project WHERE project_id=ANY(?)', undef, \@run_ids);
    # Source restoration is committed. Remove deleted own plants/images from
    # the same three analytical views used by the observation HTTP tests.
    SGN::Test::OwnedTrialCleanup->refresh_analytical_caches($schema);
    $cleanup_done = 1;
    return 1;
};
END {
    my $status = $?;
    if ($cleanup && !$cleanup_done) {
        eval { $cleanup->(); 1 } or do {
            warn "ImageAnalysis cleanup failed: $@";
            $status = 1 unless $status;
        };
    }
    $? = $status;
}

# Return mocked HTTP client
{
    no warnings 'redefine';
    require LWP::UserAgent;
    *LWP::UserAgent::new = sub { return $mock_ua };
}

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
my $sgn_session_id = $response->{access_token};


# Choose a parent by its declared field study and germplasm, not sequence state.
my ($stock_id) = $schema->storage->dbh->selectrow_array(q{
    SELECT DISTINCT s.stock_id FROM stock s
    JOIN cvterm st ON st.cvterm_id=s.type_id
    JOIN stock_relationship r ON r.subject_id=s.stock_id
    JOIN cvterm rt ON rt.cvterm_id=r.type_id
    JOIN nd_experiment_stock nes ON nes.stock_id=s.stock_id
    JOIN nd_experiment ne USING(nd_experiment_id)
    JOIN cvterm et ON et.cvterm_id=ne.type_id
    JOIN nd_experiment_project nep USING(nd_experiment_id)
    WHERE nep.project_id=165 AND r.object_id=41281
      AND st.name='plot' AND rt.name='plot_of' AND et.name='field_layout'
    ORDER BY s.stock_id LIMIT 1
});
ok($stock_id, 'fixture provides a plot in study 165 for germplasm 41281')
    or BAIL_OUT('No matching fixture plot; do not infer a parent from a generated stock ID.');

$remember_trial->(165);

# Create test plant
$data = '[{"germplasmDbId":"41281","locationDbId":"23","observationUnitName":"Testing Plant","programDbId":"134","studyDbId":"165","trialDbId":"165","observationUnitPosition":{"observationLevel":{"levelName":"plant","levelCode":"plant_1"},"observationLevelRelationships":[{"levelCode":"' . $stock_id. '","levelName":"plot"}],"positionCoordinateX":"74","positionCoordinateXType":"GRID_COL","positionCoordinateY":"03","positionCoordinateYType":"GRID_ROW"}, "additionalInfo" : {"observationUnitParent":"' . $stock_id. '"} }]';
$mech->post('http://localhost:3010/brapi/v2/observationunits/',
    'Content-Type' => 'application/json', 'Authorization' => "Bearer $sgn_session_id",
    Content => $data);
ok($mech->success, 'create the plant with its explicit field parent')
    or diag($mech->content);
my $plant_response = decode_json $mech->content;

my $plant_unit = $plant_response->{result}{data}[0];
my $plant_id = $plant_unit ? $plant_unit->{observationUnitDbId} : undef;
ok($plant_id, 'created plant ID comes from the successful API response')
    or BAIL_OUT('Plant creation failed; do not attach images to an unrelated stock.');
is($plant_unit->{studyDbId}, '165', 'created plant remains in its declared field study');
is($plant_unit->{germplasmDbId}, '41281', 'created plant retains its parent germplasm');
is(scalar @{$plant_response->{result}{data}}, 1, 'plant creation returns only the requested unit');
is($plant_unit->{observationUnitName}, 'Testing Plant', 'plant DTO retains the exact requested name');
is($schema->resultset('Stock::Stock')->find($plant_id)->type->name, 'plant',
    'the returned plant ID resolves to the requested stock level');
my $actual_parent_plots = $schema->storage->dbh->selectcol_arrayref(q{
    SELECT r.subject_id FROM stock_relationship r
    JOIN cvterm rt ON rt.cvterm_id=r.type_id
    JOIN stock p ON p.stock_id=r.subject_id JOIN cvterm pt ON pt.cvterm_id=p.type_id
    WHERE r.object_id=? AND rt.name='plant_of' AND pt.name='plot' ORDER BY r.subject_id
}, undef, $plant_id);
is_deeply($actual_parent_plots, [$stock_id], 'the returned plant has the exact selected parent plot');

$upload_sources{$plant_id} = 1;
$mech->get_ok("/image/add?type=stock&type_id=$plant_id");
$mech->get_ok("/image/add?action=new&type=stock&type_id=$plant_id");

# Store first image associated with created plant
my %form = (
    form_name => 'upload_image_form',
    fields => {
        file          => $test_file,
        type          => 'stock',
        type_id       => $plant_id,
        refering_page => 'http://google.com',
    },
);
$mech->submit_form_ok(\%form, "Form submitted");

my $store_form = { form_name => 'store_image' };
$mech->submit_form_ok($store_form, "Submitting multi analysis image for storage");
$mech->content_contains('SGN Image');
$mech->content_contains(basename($test_file));

my $uri = $mech->uri();
my $image_id = "";
if ($uri =~ /\/(\d+)$/) {
    $image_id = $1;
}
$remember_image->($image_id, $plant_id);
$checkpoint->('after_first_image');

# --- Navigate back to the upload form before uploading the second image ---
$mech->get_ok("/image/add?type=stock&type_id=$plant_id");
$mech->get_ok("/image/add?action=new&type=stock&type_id=$plant_id");

# Store second image associated with created plant
my %form2 = (
    form_name => 'upload_image_form',
    fields => {
        file          => $test_file,
        type          => 'stock',
        type_id       => $plant_id,
        refering_page => 'http://google.com',
    },
);
$mech->submit_form_ok(\%form2, "Form submitted (second image)");

my $store_form2 = { form_name => 'store_image' };
$mech->submit_form_ok($store_form2, "Submitting multi analysis image for storage (second image)");
$mech->content_contains('SGN Image');
$mech->content_contains(basename($test_file));

my $uri2 = $mech->uri();
my $image_id_2 = "";
if ($uri2 =~ /\/(\d+)$/) {
    $image_id_2 = $1;
}
$remember_image->($image_id_2, $plant_id);
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

# --- Tissue samples ---
my @tissue_sample_ids;

my $study_id     = $plant_unit->{studyDbId};
my $germplasm_id = $plant_unit->{germplasmDbId};

foreach my $n (1, 2) {
    my $name = 'FruitDiameter_' . $table_data->[0]{observationUnitName} . "_sample$n";

    my $payload = encode_json([{
        additionalInfo      => { observationUnitParent => $plant_id },
        observationUnitName => $name,
        studyDbId           => $study_id,
        germplasmDbId       => $germplasm_id,
        observationUnitPosition => {
            observationLevel => {
                levelName  => 'tissue_sample',
                levelCode  => "$n",
                levelOrder => 4,
            },
            observationLevelRelationships => [
                { levelName => 'plant', observationUnitDbId => $plant_id, levelOrder => 4 }
            ],
            positionCoordinateX => undef,
            positionCoordinateY => undef,
            geoCoordinates      => undef,
        },
    }]);

    # post_ok expects an options reference; raw named arguments are discarded.
    $mech->post(
        'http://localhost:3010/brapi/v2/observationunits',
        'Content-Type'  => 'application/json',
        'Authorization' => "Bearer $sgn_session_id",
        Content         => $payload,
    );
    ok($mech->success, "tissue sample $n JSON request succeeds") or diag($mech->content);
    my $resp = decode_json $mech->content;
    my $ts_id = $resp->{result}{data}[0]{observationUnitDbId};
    ok($ts_id, "tissue sample $n created")
        or BAIL_OUT('Tissue creation failed; do not submit unrelated observation units.');
    isnt($ts_id, $plant_id, "tissue sample $n has its own identity"); # codespell:ignore isnt
    ok(!(grep { $_ eq $ts_id } @tissue_sample_ids), "tissue sample $n is distinct from earlier samples");
    is($resp->{result}{data}[0]{studyDbId}, $study_id, "tissue sample $n retains the parent field study");
    is($resp->{result}{data}[0]{germplasmDbId}, $germplasm_id, "tissue sample $n retains the parent germplasm");
    push @tissue_sample_ids, $ts_id;
}

# create_run_project tests

# Use the analyzed-image unit and its declared field study, as the browser does.
my $trial_id = $study_id;
my $source_stock_id = $plant_id;


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

my $run_name = $owned_prefix.'_single';

# --- Single image via images_json ------------------------

my $images_json_single = encode_json([
    {
        source_image_id  => $image_id,
        source_stock_id  => $source_stock_id,
        trial_id         => $trial_id,
        overlay_image_id => $image_id,
        tissue_samples   => [ map { { stock_id => $_ } } @tissue_sample_ids ],
    }
]);

$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        run_name           => $run_name,
        service_name       => 'Image Multi Object Multi Trait Analysis',
        run_date           => '2026-07-09',
        analysis_info_json => $analysis_info_json,
        trait_ids          => $trait_ids_json,
        images_json        => $images_json_single,
    ]
);

my $create_result = decode_json $mech->content;
$remember_run->($run_name, $create_result->{run_project_id});
$checkpoint->('after_first_run');
ok($create_result->{success}, "create_run_project returned success");
ok($create_result->{run_project_id}, "run_project_id returned");
is($create_result->{run_name}, $run_name, "run_name echoed back");
is($create_result->{image_count}, 1, "one image reported");
is($create_result->{traits_associated}, 1, "one trait associated");
ok($create_result->{stock_count} >= 1, "stock_count reported");

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
diag("source_stock_id: $source_stock_id");
diag("tissue_sample_ids: " . join(',', @tissue_sample_ids));
my %uniq = map { $_ => 1 } ($source_stock_id, @tissue_sample_ids);
diag("distinct stocks expected: " . scalar(keys %uniq));
diag("linked in db: " . join(',', map { $_->stock_id } $nes_rs->all));

is($nes_rs->count, scalar(keys %uniq),
   "nd_experiment links the distinct source stock and both tissue samples");
is_deeply([sort { $a <=> $b } map { $_->stock_id } $nes_rs->all],
          [sort { $a <=> $b } keys %uniq],
          "the stored observation units are exactly the submitted source and samples");

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
# Missing run_name
$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [ images_json => $images_json_single ]
);
my $err_name = decode_json $mech->content;
like($err_name->{error}, qr/run_name/, "error when run_name missing");

# No images_json at all
$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [ run_name => 'no_images_' . time() ]
);
my $err_none = decode_json $mech->content;
like($err_none->{error}, qr/At least one image/, "error when images_json absent");

# Incomplete image entry
$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        run_name    => 'incomplete_' . time(),
        images_json => encode_json([ { source_image_id => $image_id } ]),
    ]
);
my $err_fields = decode_json $mech->content;
like($err_fields->{error}, qr/requires/, "error names the missing fields");

# Non-numeric ids
$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        run_name    => 'nonnumeric_' . time(),
        images_json => encode_json([
            { source_image_id => 'abc', source_stock_id => $source_stock_id, trial_id => $trial_id }
        ]),
    ]
);
my $err_num = decode_json $mech->content;
like($err_num->{error}, qr/numeric/, "non-numeric ids rejected");

# Malformed JSON returns JSON, not a 500
$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [ run_name => 'badjson_' . time(), images_json => '{not valid json' ]
);
my $err_json = decode_json $mech->content;
like($err_json->{error}, qr/images_json/, "malformed images_json rejected cleanly");

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

# --- Multi-image, multi-trial ---------------------------------------

# Resolve another real field source through its owning layout and germplasm.
my ($trial_id_2, $source_stock_id_2, $germplasm_id_2) =
    $schema->storage->dbh->selectrow_array(q{
        SELECT DISTINCT p.project_id, s.stock_id, r.object_id
        FROM project p
        JOIN nd_experiment_project ep ON ep.project_id=p.project_id
        JOIN nd_experiment ne USING(nd_experiment_id)
        JOIN cvterm et ON et.cvterm_id=ne.type_id
        JOIN nd_experiment_stock es USING(nd_experiment_id)
        JOIN stock s USING(stock_id)
        JOIN cvterm st ON st.cvterm_id=s.type_id
        JOIN stock_relationship r ON r.subject_id=s.stock_id
        JOIN cvterm rt ON rt.cvterm_id=r.type_id
        JOIN stock g ON g.stock_id=r.object_id
        JOIN cvterm gt ON gt.cvterm_id=g.type_id
        WHERE p.name='test_trial' AND p.project_id<>?
          AND et.name='field_layout' AND st.name='plot' AND rt.name='plot_of'
          AND gt.name IN ('accession','cross','family_name')
        ORDER BY p.project_id, s.stock_id, r.object_id LIMIT 1
    }, undef, $trial_id);
ok($trial_id_2 && $source_stock_id_2 && $germplasm_id_2,
   "a distinct fixture field study has a declared plot and germplasm")
    or BAIL_OUT('No second field-study source; do not infer membership from project sequence state.');

# Keep both original plant images for the same-source regression. This third
# image and sample belong to the second study used by the multi-trial run.
$remember_trial->($trial_id_2);
$upload_sources{$source_stock_id_2} = 1;
$mech->get_ok("/image/add?type=stock&type_id=$source_stock_id_2");
$mech->get_ok("/image/add?action=new&type=stock&type_id=$source_stock_id_2");
$mech->submit_form_ok({
    form_name => 'upload_image_form',
    fields => {
        file => $test_file, type => 'stock', type_id => $source_stock_id_2,
        refering_page => 'http://google.com',
    },
}, "upload a separate image for the second field study");
$mech->submit_form_ok({form_name => 'store_image'},
    "store the second-study source image");
my ($image_id_3) = $mech->uri() =~ m{/(\d+)$};
$remember_image->($image_id_3, $source_stock_id_2);
ok($image_id_3, "the second-study image has its returned identity")
    or BAIL_OUT('Second-study image storage did not return an image ID.');
isnt($image_id_3, $image_id, "second-study image is distinct from the first source image"); # codespell:ignore isnt
isnt($image_id_3, $image_id_2, "second-study image is distinct from the second plant image"); # codespell:ignore isnt

$mech->post('http://localhost:3010/brapi/v2/observationunits',
    'Content-Type' => 'application/json', 'Authorization' => "Bearer $sgn_session_id",
    Content => encode_json([{
        observationUnitName => $run_name.'_second_study_sample1',
        studyDbId => "$trial_id_2", germplasmDbId => "$germplasm_id_2",
        additionalInfo => {observationUnitParent => "$source_stock_id_2"},
        observationUnitPosition => {
            observationLevel => {levelName => 'tissue_sample', levelCode => '1'},
            observationLevelRelationships => [],
        },
    }]),
);
ok($mech->success, "create the second-study tissue sample with its actual source parent")
    or diag($mech->content);
my $sample_response_2 = decode_json $mech->content;
my $sample_unit_2 = $sample_response_2->{result}{data}[0];
my $sample_id_2 = $sample_unit_2 ? $sample_unit_2->{observationUnitDbId} : undef;
ok($sample_id_2, "second-study tissue sample has its returned identity")
    or BAIL_OUT('Second-study tissue creation failed.');
is($sample_unit_2->{studyDbId}, $trial_id_2, "second-study sample retains its actual field study");
is($sample_unit_2->{germplasmDbId}, $germplasm_id_2, "second-study sample retains its parent germplasm");
ok(!$uniq{$sample_id_2} && $sample_id_2 ne $source_stock_id_2,
   "second-study sample is distinct from both source units and the first-study samples");

my $multi_run_name = $owned_prefix.'_multi';

$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        run_name           => $multi_run_name,
        service_name       => 'Image Multi Object Multi Trait Analysis',
        run_date           => '2026-07-09',
        analysis_info_json => $analysis_info_json,
        trait_ids          => $trait_ids_json,
        images_json        => encode_json([
            { source_image_id => $image_id,   source_stock_id => $source_stock_id,
              trial_id => $trial_id,   overlay_image_id => $image_id,
              tissue_samples => [ { stock_id => $tissue_sample_ids[0] } ] },
            { source_image_id => $image_id_3, source_stock_id => $source_stock_id_2,
              trial_id => $trial_id_2, overlay_image_id => undef,
              tissue_samples => [ { stock_id => $sample_id_2 } ] },
        ]),
    ]
);

my $multi = decode_json $mech->content;
$remember_run->($multi_run_name, $multi->{run_project_id});
ok($multi->{success}, "multi-image run created");
is($multi->{image_count}, 2, "two images reported");

my $multi_run_id = $multi->{run_project_id};
my $expected_exp = 2;

is($schema->resultset('NaturalDiversity::NdExperimentProject')
     ->search({ project_id => $multi_run_id })->count,
   $expected_exp, "one nd_experiment per distinct trial");

is($schema->resultset('Project::ProjectRelationship')
     ->search({ subject_project_id => $multi_run_id, type_id => $rel_id })->count,
   $expected_exp, "each trial linked to the run");

# Both source images linked
foreach my $iid ($image_id, $image_id_3) {
    $img_check->execute($multi_run_id, $iid, $src_img_type_id);
    my ($cnt) = $img_check->fetchrow_array();
    is($cnt, 1, "source image $iid linked to run");
}

# Image/stock map projectprop
my $map_type_id = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'image_analysis_image_stock_map_json', 'project_property')->cvterm_id();
my $map_prop = $schema->resultset('Project::Projectprop')->find({
    project_id => $multi_run_id, type_id => $map_type_id,
});
ok($map_prop && $map_prop->value, "image_stock_map projectprop stored");
my $map = decode_json($map_prop->value);
is(scalar(@$map), 2, "map has one entry per image");
is($map->[0]{trial_id}, $trial_id, "map entry carries trial_id");
ok(scalar(@{ $map->[0]{tissue_sample_ids} }), "map entry carries tissue samples");
is_deeply([map { [$_->{source_image_id}, $_->{source_stock_id}, $_->{trial_id},
                  @{$_->{tissue_sample_ids}}] } @$map],
          [[$image_id, $source_stock_id, $trial_id, $tissue_sample_ids[0]],
           [$image_id_3, $source_stock_id_2, $trial_id_2, $sample_id_2]],
          "each image map retains its exact source, field study and tissue sample");
my $multi_stock_ids = $schema->storage->dbh->selectcol_arrayref(q{
    SELECT es.stock_id FROM nd_experiment_project ep
    JOIN nd_experiment_stock es USING(nd_experiment_id)
    WHERE ep.project_id=? ORDER BY es.stock_id
}, undef, $multi_run_id);
is_deeply($multi_stock_ids,
          [sort { $a <=> $b } ($source_stock_id, $tissue_sample_ids[0],
                              $source_stock_id_2, $sample_id_2)],
          "multi-trial storage contains exactly the two real sources and their samples");

# --- Regression: two images of the SAME plot --------------------------
# This is what crashed the original code on nd_experiment_stock's
# (nd_experiment_id, stock_id, type_id) unique constraint.

$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        run_name    => $owned_prefix.'_same',
        images_json => encode_json([
            { source_image_id => $image_id,   source_stock_id => $source_stock_id,
              trial_id => $trial_id, tissue_samples => [ { stock_id => $tissue_sample_ids[0] } ] },
            { source_image_id => $image_id_2, source_stock_id => $source_stock_id,
              trial_id => $trial_id, tissue_samples => [ { stock_id => $tissue_sample_ids[1] } ] },
        ]),
    ]
);
my $same = decode_json $mech->content;
$remember_run->($owned_prefix.'_same', $same->{run_project_id});
ok($same->{success}, "two images of the same plot save without constraint violation");
is($same->{stock_count}, scalar(keys %uniq), "shared source counted once, both samples counted");
my $same_stock_ids = $schema->storage->dbh->selectcol_arrayref(q{
    SELECT DISTINCT es.stock_id
    FROM nd_experiment_project ep
    JOIN nd_experiment_stock es USING(nd_experiment_id)
    WHERE ep.project_id=? ORDER BY es.stock_id
}, undef, $same->{run_project_id});
is_deeply($same_stock_ids, [sort { $a <=> $b } keys %uniq],
          "two images of the same source retain exactly the source and both samples");

# --- Duplicate image id is deduped ----------------------------------

$mech->post_ok(
    'http://localhost:3010/ajax/image_analysis/create_run_project',
    [
        run_name    => $owned_prefix.'_duplicate',
        images_json => encode_json([
            { source_image_id => $image_id, source_stock_id => $source_stock_id,
              trial_id => $trial_id, tissue_samples => [ { stock_id => $tissue_sample_ids[0] } ] },
            { source_image_id => $image_id, source_stock_id => $source_stock_id,
              trial_id => $trial_id, tissue_samples => [ { stock_id => $tissue_sample_ids[1] } ] },
        ]),
    ]
);
my $dup = decode_json $mech->content;
$remember_run->($owned_prefix.'_duplicate', $dup->{run_project_id});
is($dup->{image_count}, 1, "duplicate source_image_id deduped");

ok($cleanup->(), 'all owned images and run projects removed before fixture stocks');
done_testing();

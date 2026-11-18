
# Plants and tissue samples created through BrAPI v2 POST /observationunits must inherit the
# treatments of their parent observation unit, but not its ordinary phenotypic trait values.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use DateTime;
use CXGN::Trait::Treatment;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial::TrialLayout;

my $f = SGN::Test::Fixture->new(); # records db stats for clean_up_db
my $schema = $f->bcs_schema();
my $dbh = $schema->storage->dbh();

my $study_id = 165; # CASS_6Genotypes_Sampling_2015
my $plot = $schema->resultset('Stock::Stock')->find({ uniquename => 'CASS_6Genotypes_103' });
ok($plot, 'found parent plot');
my $plot_id = $plot->stock_id();

my ($germplasm_id) = $dbh->selectrow_array(
    "SELECT object_id FROM stock_relationship JOIN cvterm ON (stock_relationship.type_id = cvterm.cvterm_id)
     WHERE subject_id = ? AND cvterm.name = 'plot_of'", undef, $plot_id);
ok($germplasm_id, 'found germplasm of parent plot');

# A treatment and an ordinary trait, both stored on the parent plot
my $treatment = CXGN::Trait::Treatment->new({
    bcs_schema => $schema,
    name => 'inheritance test treatment',
    definition => 'A treatment used to test inheritance by BrAPI-created observation units.',
    format => 'numeric'
});
$treatment->store(encode_json(['Experimental treatment ontology|EXPERIMENT_TREATMENT:0000000']));
my $treatment_id = $treatment->cvterm_id();
my ($treatment_name) = $dbh->selectrow_array(
    "SELECT cvterm.name || '|' || db.name || ':' || dbxref.accession FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) WHERE cvterm_id = ?",
    undef, $treatment_id);
like($treatment_name, qr/\|EXPERIMENT_TREATMENT:/, "created treatment $treatment_name");

my $trait_name = 'dry matter content percentage|CO_334:0000092';
my ($trait_id) = $dbh->selectrow_array(
    "SELECT cvterm_id FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) WHERE db.name = 'CO_334' AND dbxref.accession = '0000092'");
ok($trait_id, 'found trait');

my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();
my $store = CXGN::Phenotypes::StorePhenotypes->new(
    basepath => $f->config->{basepath},
    dbhost => $f->config->{dbhost},
    dbname => $f->config->{dbname},
    dbuser => $f->config->{dbuser},
    dbpass => $f->config->{dbpass},
    temp_file_nd_experiment_id => $f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema => $schema,
    metadata_schema => $f->metadata_schema,
    phenome_schema => $f->phenome_schema,
    user_id => 41,
    stock_list => ['CASS_6Genotypes_103'],
    trait_list => [$treatment_name, $trait_name],
    values_hash => { 'CASS_6Genotypes_103' => {
        $treatment_name => ['7', $timestamp, 'janedoe', '', ''],
        $trait_name => ['33', $timestamp, 'janedoe', '', ''],
    }},
    has_timestamps => 0,
    metadata_hash => { archived_file => 'none', archived_file_type => 'treatment inheritance test', operator => 'janedoe', date => $timestamp },
    composable_validation_check_name => $f->config->{composable_validation_check_name}
);
my ($verify_warning, $verify_error) = $store->verify();
ok(!$verify_error, 'parent plot values verify') or diag($verify_error);
my ($store_error) = $store->store();
ok(!$store_error, 'parent plot values stored') or diag($store_error);

# Log in to BrAPI
my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
my $access_token = decode_json($mech->content)->{access_token};
$mech->default_header("Content-Type" => "application/json");
$mech->default_header('Authorization' => 'Bearer ' . $access_token);

sub post_ou {
    my ($name, $level, $level_code, $parent_id) = @_;
    my $ou = [{
        germplasmDbId => "$germplasm_id",
        observationUnitName => $name,
        studyDbId => "$study_id",
        trialDbId => "$study_id",
        observationUnitPosition => { observationLevel => { levelName => $level, levelCode => $level_code } },
        additionalInfo => { observationUnitParent => "$parent_id" }
    }];
    $mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => encode_json($ou));
    my $response = decode_json($mech->content);
    my $data = $response->{result}->{data} || [];
    my $messages = join('; ', map { $_->{message} } @{$response->{metadata}->{status} || []});
    is(scalar(@$data), 1, "POST $level $name returned one observation unit") or diag($messages);
    return $data->[0] ? $data->[0]->{observationUnitDbId} : undef;
}

sub child_value {
    my ($stock_id, $cvterm_id) = @_;
    my ($value) = $dbh->selectrow_array(
        "SELECT phenotype.value FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id)
         WHERE nd_experiment_stock.stock_id = ? AND phenotype.cvalue_id = ?", undef, $stock_id, $cvterm_id);
    return $value;
}

my $plant_id = post_ou('inheritance_test_plant', 'plant', '1', $plot_id);
my $plot_sample_id = post_ou('inheritance_test_plot_sample', 'tissue_sample', '1', $plot_id);
my $plant_sample_id = post_ou('inheritance_test_plant_sample', 'tissue_sample', '1', $plant_id);

foreach my $child (['plant', $plant_id], ['tissue sample of plot', $plot_sample_id], ['tissue sample of plant', $plant_sample_id]) {
    my ($label, $stock_id) = @$child;
    SKIP: {
        skip("$label was not created", 2) if !$stock_id;
        is(child_value($stock_id, $treatment_id), '7', "$label inherits the parent's treatment");
        ok(!defined(child_value($stock_id, $trait_id)), "$label does not inherit the parent's phenotypic trait");
    }
}

# A plant whose germplasm differs from its parent plot is rejected
my ($other_germplasm_id) = $dbh->selectrow_array(
    "SELECT stock_id FROM stock JOIN cvterm ON (stock.type_id = cvterm.cvterm_id) WHERE cvterm.name = 'accession' AND stock_id <> ? LIMIT 1", undef, $germplasm_id);
$mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => encode_json([{
    germplasmDbId => "$other_germplasm_id",
    observationUnitName => 'inheritance_test_wrong_germplasm',
    studyDbId => "$study_id",
    trialDbId => "$study_id",
    observationUnitPosition => { observationLevel => { levelName => 'plant', levelCode => '2' } },
    additionalInfo => { observationUnitParent => "$plot_id" }
}]));
ok(!$schema->resultset('Stock::Stock')->find({ uniquename => 'inheritance_test_wrong_germplasm' }), 'plant with mismatched germplasm is not created');

# A new plot sent with a tissue sample whose name already exists is not stored, so the request can be corrected and resent
$mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => encode_json([
    {
        germplasmDbId => "$germplasm_id",
        observationUnitName => 'inheritance_test_new_plot',
        studyDbId => "$study_id",
        trialDbId => "$study_id",
        observationUnitPosition => {
            observationLevel => { levelName => 'plot', levelCode => '9001' },
            observationLevelRelationships => [ { levelName => 'rep', levelCode => '1' }, { levelName => 'block', levelCode => '1' } ]
        }
    },
    {
        germplasmDbId => "$germplasm_id",
        observationUnitName => 'inheritance_test_plot_sample',
        studyDbId => "$study_id",
        trialDbId => "$study_id",
        observationUnitPosition => { observationLevel => { levelName => 'tissue_sample', levelCode => '2' } },
        additionalInfo => { observationUnitParent => "$plot_id" }
    }
]));
my $duplicate_response = decode_json($mech->content);
like(join('; ', map { $_->{message} } @{$duplicate_response->{metadata}->{status} || []}), qr/already exist.*inheritance_test_plot_sample/, 'existing tissue sample name is reported');
ok(!$schema->resultset('Stock::Stock')->find({ uniquename => 'inheritance_test_new_plot' }), 'new plot is not stored when a tissue sample in the same request would fail');

# Plant coordinates: each new plant keeps its own row and column, whether or not the other new plants in its plot have them
sub post_plants {
    my ($plot_name, @plants) = @_; # each plant is [ name, x (col), y (row) ]
    my $parent_id = $schema->resultset('Stock::Stock')->find({ uniquename => $plot_name })->stock_id();
    my ($plot_germplasm_id) = $dbh->selectrow_array(
        "SELECT object_id FROM stock_relationship JOIN cvterm ON (stock_relationship.type_id = cvterm.cvterm_id)
         WHERE subject_id = ? AND cvterm.name = 'plot_of'", undef, $parent_id);
    my $index = 1;
    $mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => encode_json([ map {
        my ($name, $x, $y) = @$_;
        my $position = { observationLevel => { levelName => 'plant', levelCode => $index++ } };
        $position->{positionCoordinateX} = $x if defined $x;
        $position->{positionCoordinateY} = $y if defined $y;
        {
            germplasmDbId => "$plot_germplasm_id",
            observationUnitName => $name,
            studyDbId => "$study_id",
            trialDbId => "$study_id",
            observationUnitPosition => $position,
            additionalInfo => { observationUnitParent => "$parent_id" }
        }
    } @plants ]));
    return decode_json($mech->content);
}

sub status_messages {
    my $response = shift;
    return join('; ', map { $_->{message} } @{$response->{metadata}->{status} || []});
}

sub post_plants_ok {
    my ($label, $plot_name, @plants) = @_;
    my $response = post_plants($plot_name, @plants);
    is(scalar(@{$response->{result}->{data} || []}), scalar(@plants), "$label: plants created") or diag(status_messages($response));
}

sub plant_coords {
    my $name = shift;
    my %coords;
    my $sth = $dbh->prepare(
        "SELECT cvterm.name, stockprop.value FROM stockprop JOIN stock USING(stock_id) JOIN cvterm ON (stockprop.type_id = cvterm.cvterm_id)
         WHERE stock.uniquename = ? AND cvterm.name IN ('row_number', 'col_number')");
    $sth->execute($name);
    while (my ($type, $value) = $sth->fetchrow_array()) { push @{$coords{$type}}, $value; }
    return \%coords;
}

# Every new plant in the plot has coordinates
post_plants_ok('all plants with coordinates', 'CASS_6Genotypes_104', ['coords_test_all_1', 1, 1], ['coords_test_all_2', 2, 1]);
is_deeply(plant_coords('coords_test_all_1'), { row_number => ['1'], col_number => ['1'] }, 'all plants with coordinates: first plant keeps its coordinates');
is_deeply(plant_coords('coords_test_all_2'), { row_number => ['1'], col_number => ['2'] }, 'all plants with coordinates: second plant keeps its coordinates');

# Only some new plants in the plot have coordinates
post_plants_ok('some plants with coordinates', 'CASS_6Genotypes_105', ['coords_test_some_1', 3, 2], ['coords_test_some_2']);
is_deeply(plant_coords('coords_test_some_1'), { row_number => ['2'], col_number => ['3'] }, 'some plants with coordinates: plant with coordinates keeps them');
is_deeply(plant_coords('coords_test_some_2'), {}, 'some plants with coordinates: plant without coordinates has none');

# No new plant in the plot has coordinates
post_plants_ok('no plants with coordinates', 'CASS_6Genotypes_106', ['coords_test_none_1'], ['coords_test_none_2']);
is_deeply(plant_coords('coords_test_none_1'), {}, 'no plants with coordinates: plant has none');

# A plant whose position is taken by an existing plant of the same plot is rejected, along with the rest of the request
my $occupied_response = post_plants('CASS_6Genotypes_104', ['coords_test_free', 3, 3], ['coords_test_occupied', 1, 1]);
like(status_messages($occupied_response), qr/coords_test_occupied.*occupied/, 'occupied position is reported');
ok(!$schema->resultset('Stock::Stock')->find({ uniquename => $_ }), "$_ is not created when a position in the request is occupied") for qw(coords_test_free coords_test_occupied);

$f->clean_up_db();
CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $study_id, experiment_type => 'field_layout' })->generate_and_cache_layout();

done_testing();

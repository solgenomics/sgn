
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

$f->clean_up_db();
CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $study_id, experiment_type => 'field_layout' })->generate_and_cache_layout();

done_testing();

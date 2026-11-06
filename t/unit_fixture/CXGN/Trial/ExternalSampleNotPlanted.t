use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::AccessionChange;
use CXGN::Phenotypes::StorePhenotypes;

# Native samples belong only to their sampling layout, while their source plots
# belong to the field trial. Exercise both serialized operation orders without
# a scheduler-dependent race. All database changes use one rollback-only connection.
my $fixture = SGN::Test::Fixture->new;
my $schema = $fixture->bcs_schema;
$schema->storage->auto_savepoint(1);
my $dbh = $schema->storage->dbh;
my $directory = tempdir(CLEANUP => 1);
my $prefix = 'audit_external_sample_not_planted_' . $$;
my ($trial_id, $sampling_trial_id);
my (@plots, @samples, @sample_names);
my $trait_id = 70741;
my $trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_id, 'extended');

sub term {
    return SGN::Model::Cvterm->get_cvterm_row($schema, @_)->cvterm_id;
}

sub service {
    return CXGN::Trial::AccessionChange->new({schema => $schema, trial_id => $trial_id});
}

sub is_not_planted {
    my ($plot_id) = @_;
    return $dbh->selectrow_array(q{
        SELECT count(*) FROM stockprop JOIN cvterm ON cvterm_id = type_id
        WHERE stock_id = ? AND cvterm.name = 'not_planted' AND value = '1'
    }, undef, $plot_id);
}

sub observations {
    my ($sample_id) = @_;
    return $dbh->selectall_arrayref(q{
        SELECT p.phenotype_id, p.value, p.collect_date, p.cvalue_id,
               nes.nd_experiment_id, nes.stock_id
        FROM phenotype p
        JOIN nd_experiment_phenotype nep USING (phenotype_id)
        JOIN nd_experiment_stock nes USING (nd_experiment_id)
        WHERE nes.stock_id = ? ORDER BY p.phenotype_id, nes.nd_experiment_id
    }, {Slice => {}}, $sample_id);
}

sub phenotype_store {
    my ($index) = @_;
    my $name = $sample_names[$index];
    return CXGN::Phenotypes::StorePhenotypes->new({
        basepath => $fixture->config->{basepath},
        dbhost => $fixture->config->{dbhost},
        dbname => $fixture->config->{dbname},
        dbuser => $fixture->config->{dbuser},
        dbpass => $fixture->config->{dbpass},
        temp_file_nd_experiment_id => "$directory/experiments_$index",
        bcs_schema => $schema,
        metadata_schema => $fixture->metadata_schema,
        phenome_schema => $fixture->phenome_schema,
        user_id => 41,
        stock_list => [$name],
        trait_list => [$trait_name],
        values_hash => {$name => {$trait_name => [73, '']}},
        has_timestamps => 0,
        overwrite_values => 0,
        metadata_hash => {operator => 'janedoe', date => '2030-11-03_12:00:00'},
        composable_validation_check_name => $fixture->config->{composable_validation_check_name},
    });
}

sub refuse_not_planted {
    my ($index, $label) = @_;
    my $changes = [{plot_id => $plots[$index], not_planted => 1}];
    my $plan = service()->plan($changes, {curator => 1});
    like(join(' ', @{$plan->{errors}}), qr/were stored.*not planted.*values are retained/is,
        "$label: preview refuses the impossible source status");
    my $applied = eval {
        service()->apply($changes, {curator => 1, delete_phenotypes => 1});
        1;
    };
    my $error = "$@";
    ok(!$applied, "$label: actual apply refuses even with the legacy deletion option");
    like($error, qr/were stored.*not planted.*values are retained/is,
        "$label: refusal explains that the observations are retained");
    is(is_not_planted($plots[$index]), 0, "$label: source plot remains planted");
}

$schema->txn_begin;
my $completed = eval {
    my %design = map {$_ => {
        plot_name => "${prefix}_plot_$_", plot_number => $_,
        stock_name => 'test_accession1', block_number => 1, rep_number => 1,
        row_number => 1, col_number => $_,
    }} 1 .. 3;
    my $field = CXGN::Trial::TrialCreate->new({
        chado_schema => $schema, dbh => $dbh, owner_id => 41,
        operator => 'janedoe', program => 'test', trial_location => 'test_location',
        trial_name => $prefix, trial_description => 'Rollback-only external-sample status regression',
        trial_year => 2030, design_type => 'CRD', design => \%design,
    })->save_trial;
    $trial_id = $field->{trial_id};
    die 'Native field trial creation failed' unless $trial_id;
    @plots = map {
        $schema->resultset('Stock::Stock')->find({uniquename => "${prefix}_plot_$_"})->stock_id
    } 1 .. 3;
    my %sample_design = map {$_ => {
        plot_name => "${prefix}_sample_$_", plot_number => $_,
        stock_name => "${prefix}_plot_$_", block_number => 1, rep_number => 1,
        row_number => 1, col_number => $_,
    }} 1 .. 3;
    my $sampling = CXGN::Trial::TrialCreate->new({
        chado_schema => $schema, dbh => $dbh, owner_id => 41,
        operator => 'janedoe', program => 'test', trial_location => 'test_location',
        trial_name => "${prefix}_sampling", trial_description => 'Native cross-project source samples',
        trial_year => 2030, design_type => 'sampling_trial', is_sampling_trial => 1,
        sampling_trial_facility => 'audit', sampling_trial_sample_type => 'leaf',
        sampling_trial_from_field_trial => [$trial_id], design => \%sample_design,
    })->save_trial;
    $sampling_trial_id = $sampling->{trial_id};
    die 'Native sampling trial creation failed' unless $sampling_trial_id;
    @sample_names = map {"${prefix}_sample_$_"} 1 .. 3;
    @samples = map {$schema->resultset('Stock::Stock')->find({uniquename => $_})->stock_id} @sample_names;
    for my $index (0 .. 2) {
        my $memberships = $dbh->selectcol_arrayref(q{
            SELECT DISTINCT project_id FROM nd_experiment_stock
            JOIN nd_experiment_project USING (nd_experiment_id)
            JOIN nd_experiment USING (nd_experiment_id)
            JOIN cvterm ON cvterm_id = nd_experiment.type_id
            WHERE stock_id = ? AND cvterm.name IN ('field_layout', 'sampling_layout')
            ORDER BY project_id
        }, undef, $samples[$index]);
        is_deeply($memberships, [$sampling_trial_id],
            "sample $index belongs only to its separate native sampling layout");
        is($dbh->selectrow_array(q{
            SELECT count(*) FROM stock_relationship
            WHERE subject_id = ? AND object_id = ? AND type_id = ?
        }, undef, $samples[$index], $plots[$index], term('tissue_sample_of', 'stock_relationship')), 1,
            "sample $index retains its native source-plot relationship");
    }

    subtest 'ordinary sample measurement is preserved and prevents source not-planted' => sub {
        my ($error) = phenotype_store(0)->store;
        ok(!$error, 'actual StorePhenotypes stores the external sample measurement') or diag($error);
        my $before = observations($samples[0]);
        is(scalar(@$before), 1, 'one raw sample measurement was actually stored');
        is($before->[0]{value}, '73', 'raw sample value is the submitted measurement');
        refuse_not_planted(0, 'ordinary sample');
        is_deeply(observations($samples[0]), $before,
            'refused transition preserves the measurement IDs, values, dates and experiment links');
    };

    subtest 'high-dimensional sample data are preserved and prevent source not-planted' => sub {
        # Use the same persisted spectra representation as AccessionChange.t.
        my $type = term('phenotyping_experiment', 'experiment_type');
        my $location = $schema->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id;
        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $location, type_id => $type,
        });
        $experiment->create_related('nd_experiment_stocks', {stock_id => $samples[1], type_id => $type});
        $experiment->create_related('nd_experiment_projects', {project_id => $sampling_trial_id});
        my $raw_json = '{"spectra":{"740":0.5},"device_type":"SCIO"}';
        my ($json_id) = $dbh->selectrow_array(q{
            INSERT INTO metadata.md_json (json_type, json) VALUES ('nirs_spectra', ?) RETURNING json_id
        }, undef, $raw_json);
        $dbh->do('INSERT INTO phenome.nd_experiment_md_json (nd_experiment_id, json_id) VALUES (?, ?)',
            undef, $experiment->nd_experiment_id, $json_id);
        my $snapshot = sub {
            return $dbh->selectall_arrayref(q{
                SELECT j.json_id, j.json_type, j.json, link.nd_experiment_id, nes.stock_id
                FROM metadata.md_json j JOIN phenome.nd_experiment_md_json link USING (json_id)
                JOIN nd_experiment_stock nes USING (nd_experiment_id)
                WHERE j.json_id = ? ORDER BY nes.stock_id
            }, {Slice => {}}, $json_id);
        };
        my $before = $snapshot->();
        is(scalar(@$before), 1, 'one actual sample spectra record is linked to its experiment');
        is_deeply(observations($samples[1]), [], 'spectra scenario has no ordinary phenotype row');
        refuse_not_planted(1, 'high-dimensional sample');
        is_deeply($snapshot->(), $before,
            'refused transition preserves exact spectra bytes, IDs and experiment links');
    };

    subtest 'source status first makes actual StorePhenotypes skip its external sample' => sub {
        my $store = phenotype_store(2);
        my (undef, $verify_error) = $store->verify;
        ok(!$verify_error, 'sample upload verifies while its source plot is still planted') or diag($verify_error);
        service()->apply([{plot_id => $plots[2], not_planted => 1}], {curator => 1});
        is(is_not_planted($plots[2]), 1, 'actual status transition marks the unmeasured source plot');
        my ($error, $success) = $store->store;
        ok(!$error, 'previously verified upload completes without a storage error') or diag($error);
        like($success // '', qr/1 unit\(s\) were not planted.*\Q$sample_names[2]\E/s,
            'actual store reports that the external sample measurement was skipped');
        is_deeply(observations($samples[2]), [], 'no raw sample observation is written after source status');
    };
    1;
};
my $error = "$@";
my $rolled_back = eval {$schema->txn_rollback; 1};
my $rollback_error = "$@";
ok($completed, 'native cross-project scenarios completed') or diag($error);
ok($rolled_back, 'all private field, sampling and measurement database changes rolled back') or diag($rollback_error);
is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name IN (?, ?)',
    undef, $prefix, "${prefix}_sampling"), 0, 'no synthetic field or sampling project remains');
is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE uniquename LIKE ?',
    undef, $prefix . '%'), 0, 'no synthetic source plot or sample remains');
done_testing;

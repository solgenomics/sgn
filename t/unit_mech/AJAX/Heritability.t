use strict;
use warnings;
use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use URI::Escape qw(uri_escape_utf8);
use CXGN::Dataset;
use CXGN::Cvterm;
use SGN::Model::Cvterm;
use Text::CSV qw(csv);

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $people_schema = $f->people_schema();
my $mech = Test::WWW::Mechanize->new;
my @owned_datasets;
my $initial_dataset_ids = dataset_ids();
my $initial_dataset_one_json = $people_schema->resultset('SpDataset')->find(1)->get_column('dataset');
END {
    my $original_exit = $?;
    if ($people_schema && $initial_dataset_ids) {
        my $finished = eval {
            my $errors = cleanup_owned_datasets();
            warn "Heritability cleanup: $_\n" for @$errors;
            my $ids = dataset_ids();
            warn "Heritability cleanup left a different dataset ID set\n"
                if join(',', @$ids) ne join(',', @$initial_dataset_ids);
            my $row = $people_schema->resultset('SpDataset')->find(1);
            warn "Heritability cleanup detected a changed original dataset 1\n"
                if !$row || $row->get_column('dataset') ne $initial_dataset_one_json;
            1;
        };
        warn "Heritability cleanup failed: $@" if !$finished;
    }
    $? = $original_exit;
}

sub dataset_ids {
    return [sort { $a <=> $b }
        $people_schema->resultset('SpDataset')->search({})->get_column('sp_dataset_id')->all()];
}

sub cleanup_owned_datasets {
    my (@errors, @remaining);
    for my $dataset (reverse @owned_datasets) {
        my $error;
        my $finished = eval { $error = $dataset->delete(); 1 };
        my $exception = $@;
        if (!$finished || defined($error)) {
            push @errors, 'dataset '.$dataset->sp_dataset_id().': '.
                (!$finished ? $exception : $error);
            unshift @remaining, $dataset;
        }
    }
    @owned_datasets = @remaining;
    return \@errors;
}

sub own_dataset {
    my ($trials, $traits, $outliers) = @_;
    my $dataset = CXGN::Dataset->new({schema => $schema, people_schema => $people_schema});
    $dataset->trials($trials);
    $dataset->traits($traits) if $traits;
    $dataset->outliers([@$outliers]) if $outliers;
    $dataset->store();
    push @owned_datasets, $dataset;
    return $dataset;
}

sub request_json {
    my ($endpoint, $dataset, $trait, $exclude) = @_;
    my $url = 'http://localhost:3010/ajax/heritability/'.$endpoint.
        '?dataset_id='.$dataset->sp_dataset_id();
    $url .= '&trait_id='.uri_escape_utf8($trait) if defined($trait);
    $url .= '&dataset_trait_outliers='.$exclude if defined($exclude);
    $mech->get_ok($url, "$endpoint responds for owned dataset");
    return decode_json($mech->content());
}

sub output_table {
    my ($response) = @_;
    ok($response->{h2Table}, 'JSON result URL returned');
    ok($response->{h2CsvTable}, 'CSV result URL returned');
    my $csv_path = 'static/'.$response->{h2CsvTable};
    my $json_path = 'static/'.$response->{h2Table};
    ok(-e $csv_path, 'CSV result exists');
    ok(-e $json_path, 'JSON result exists');
    return if !-e $csv_path || !-e $json_path;
    my $table = csv(in => $csv_path);
    open my $json_fh, '<', $json_path or die $!;
    my $json = decode_json(do { local $/; <$json_fh> });
    # jsonlite::write_json wraps its already encoded JSON in a one-string array.
    # Decode the existing transport wrappers before checking scientific rows.
    for (1..3) {
        if (!ref($json)) { $json = decode_json($json) }
        elsif (ref($json) eq 'ARRAY' && @$json == 1 && !ref($json->[0])) {
            $json = decode_json($json->[0]);
        }
        else { last }
    }
    return ($table, $json);
}

sub exported_matrix {
    my ($dataset, $exclude, $trait_header) = @_;
    my $response = request_json('shared_phenotypes', $dataset, undef, $exclude);
    ok(!$response->{error}, 'phenotype export has no error') or diag($response->{error});
    my $path = $f->config->{basepath}.'/'.$response->{tempfile};
    ok(-e $path, 'public phenotype export exists');
    open my $fh, '<', $path or die "Cannot read phenotype export $path: $!";
    my $header = <$fh>;
    chomp $header;
    my @header = split /\t/, $header, -1;
    my %column = map { $header[$_] => $_ } 0..$#header;
    die 'Export lost selected trait or plot identity' if !exists($column{$trait_header}) || !exists($column{observationUnitDbId});
    my %observations;
    my $observed = 0;
    while (my $line = <$fh>) {
        chomp $line;
        my @row = split /\t/, $line, -1;
        my $id = $row[$column{observationUnitDbId}];
        die "Duplicate exported observation unit $id" if exists($observations{$id});
        $observations{$id} = \@row;
        my $value = $row[$column{$trait_header}];
        ++$observed if defined($value) && $value ne '' && $value !~ /^(?:NA|--|-|\.|\.\.)$/;
    }
    diag("Independent Alpha reference input: $path (observed selected trait: $observed)");
    return {header => \@header, column => \%column, rows => \%observations, observed => $observed};
}

$mech->post_ok('http://localhost:3010/brapi/v1/token',
    [username => 'janedoe', password => 'secretpw', grant_type => 'password'], 'login');
is(decode_json($mech->content())->{userDisplayName}, 'Jane Doe', 'fixture user logged in');
$mech->get_ok('http://localhost:3010/tools/heritability', 'load heritability page');

# Keep the original mixed Alpha/CRD fixture as an explicit refusal regression.
my $mixed = own_dataset([139, 141], undef, undef);
my $options = request_json('shared_phenotypes', $mixed, undef, undef);
my $mixed_trait_id = $options->{options}[0][0];
subtest 'mixed study designs return no partial successful analysis' => sub {
    my $response = request_json('generate_results', $mixed, $mixed_trait_id, undef);
    like($response->{error}, qr/Mixed study designs require separate heritability analyses\./,
        'mixed declared designs produce the owning controlled error');
    my ($table, $json) = output_table($response);
    return if !$table;
    is(scalar(@$table), 1, 'failed analysis CSV contains only the unchanged header');
    is_deeply($json, [], 'failed analysis JSON contains no partial successful traits');
};

# A homogeneous label alone cannot identify genotype and residual variance.
my $unreplicated = own_dataset([141], [70666], undef);
subtest 'unreplicated genotypes return no successful variance estimate' => sub {
    my $response = request_json('generate_results', $unreplicated, '70666', undef);
    like($response->{error}, qr/number of levels.*number of observations.*germplasmName/s,
        'one observation per genotype is explicitly refused');
    my ($table, $json) = output_table($response);
    return if !$table;
    is(scalar(@$table), 1, 'nonidentifiable analysis has header-only CSV');
    is_deeply($json, [], 'nonidentifiable analysis has no successful JSON rows');
};

# Dataset 1 is read only: copy its outlier list into a newly owned Alpha subset.
# Trial 139 is a single Alpha trial, year and location with recorded design
# replicates, actual blocks, repeated genotypes, and real dataset outliers.
# No mixed-design or unreplicated-trial variance goldens apply.
my $original = CXGN::Dataset->new({schema => $schema, people_schema => $people_schema, sp_dataset_id => 1});
my $supported = own_dataset([139], [70666], $original->outliers());
my $trait_name = CXGN::Cvterm->new({schema => $schema, cvterm_id => 70666})->name();
my $trait_header = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, 70666, 'extended');
my $all = exported_matrix($supported, 0, $trait_header);
my $filtered = exported_matrix($supported, 1, $trait_header);
ok($all->{observed} > $filtered->{observed} && $filtered->{observed} > 0,
    'outlier exclusion removes real trait measurements and retains data');
is_deeply($filtered->{header}, $all->{header}, 'outlier exclusion preserves matrix schema');
is_deeply([sort keys %{$filtered->{rows}}], [sort keys %{$all->{rows}}],
    'outlier exclusion preserves selected observation units');
my $trait_column = $all->{column}{$trait_header};
my $changed = 0;
my (%before_metadata, %after_metadata);
for my $id (keys %{$all->{rows}}) {
    my @before = @{$all->{rows}{$id}};
    my @after = @{$filtered->{rows}{$id}};
    my $before_value = splice(@before, $trait_column, 1);
    my $after_value = splice(@after, $trait_column, 1);
    $before_metadata{$id} = \@before;
    $after_metadata{$id} = \@after;
    if ($before_value ne $after_value) {
        ++$changed;
        is($after_value, '', 'excluded dataset outlier is an empty trait field');
    }
}
is_deeply(\%after_metadata, \%before_metadata, 'outlier exclusion preserves all observation-unit metadata');
is($changed, $all->{observed} - $filtered->{observed}, 'only real observed trait measurements are excluded');

my ($numeric_table, $name_table, $excluded_table);
for my $case (
    ['numeric ID and unset outlier flag', '70666', undef],
    ['canonical browser name and explicit false flag', $trait_name, 0],
    ['canonical browser name and true flag', $trait_name, 1],
) {
    subtest $case->[0] => sub {
        my $response = request_json('generate_results', $supported, $case->[1], $case->[2]);
        ok(!$response->{error}, 'supported homogeneous Alpha analysis succeeds') or diag($response->{error});
        return if $response->{error};
        my ($table, $json) = output_table($response);
        return if !$table;
        is_deeply($table->[0], ['', 'trait', 'Hert', 'Vg', 'Ve', 'Vres'], 'existing CSV schema retained');
        is(scalar(@$table), 2, 'exactly the requested dataset trait is analyzed');
        # Independent ordinary Alpha REML (lme4 and nlme): recorded replicate
        # and physical block fixed, genotype random; preserve CSV precision.
        my $expected = defined($case->[2]) && $case->[2] == 1
            ? [1, $trait_name, 0.522, 6.69, 0, 6.127]
            : [1, $trait_name, 0.384, 10.105, 0, 16.217];
        is_deeply($table->[1], $expected, 'reported components match the independent replicated Alpha reference');
        is($table->[1][1], $trait_name, 'output retains the existing trait name');
        is($table->[1][4], 0, 'one-location Alpha has no added location variance');
        is(scalar(@$json), 1, 'JSON contains one successful trait');
        if (!defined($case->[2])) { $numeric_table = $table }
        elsif ($case->[2] == 0) { $name_table = $table }
        else { $excluded_table = $table }
    };
}
if ($numeric_table && $name_table) {
    is_deeply($numeric_table, $name_table, 'numeric/name and unset/false paths give identical scientific outputs');
}
if ($name_table && $excluded_table) {
    isnt($excluded_table->[1][5], $name_table->[1][5], 'real outlier exclusion changes residual variance'); # codespell:ignore isnt
}

# Dataset::delete returns an error string rather than necessarily throwing.
# Check both outcomes, keep failed owned records for END retry, and verify the
# exact row set: Fixture's datasets statistic is a maximum ID, not a row count.
is_deeply(cleanup_owned_datasets(), [], 'owned dataset deletion returns no errors');
is_deeply(dataset_ids(), $initial_dataset_ids, 'exact pre-test dataset ID set is restored');
my $original_row = $people_schema->resultset('SpDataset')->find(1);
ok($original_row, 'original dataset 1 still exists');
is($original_row->get_column('dataset'), $initial_dataset_one_json,
    'original dataset 1 JSON remains byte-for-byte unchanged') if $original_row;
done_testing();

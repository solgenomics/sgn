use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::MockModule;
use Test::MockObject;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Slurp qw(read_file write_file);
use JSON qw(encode_json decode_json);
use Text::CSV;
use SGN::Test::Fixture;
use CXGN::Trial::TrialCreate;
use SGN::Model::Cvterm;
use SGN::Model::solGS::solGS;
use SGN::Controller::solGS::solGS;
use SGN::Controller::solGS::Anova;
use SGN::Controller::solGS::Files;
use SGN::Controller::solGS::Trait;
use SGN::Controller::solGS::Utils;
use SGN::Controller::solGS::Search;
use SGN::Controller::solGS::CachedResult;
use SGN::Controller::solGS::clearCache;

# Query execution is synchronous here; the actual fixture model, formatter,
# trait/acronym generation, cache accessors, and ANOVA data action remain real.
# No R model, HTTP server, cluster job, or production cache is used.
my $f = SGN::Test::Fixture->new;
END { $f->clean_up_db if $f; }
my $schema = $f->bcs_schema;
my $directory = tempdir(CLEANUP => 1);
my $name = "anova_fixture_$$";
# Earlier fixture tests may obsolete shared accessions. Own this test's stock.
my $reference_accession = $schema->resultset('Stock::Stock')
    ->find({uniquename => 'test_accession1'});
my $original_obsolete = $reference_accession->is_obsolete;
my $accession_name = "${name}_accession";
$schema->resultset('Stock::Stock')->create({
    name => $accession_name, uniquename => $accession_name,
    organism_id => $reference_accession->organism_id,
    type_id => $reference_accession->type_id, is_obsolete => 0,
});
my $trait_id = 70741;
my ($previous_max) = $f->dbh->selectrow_array('SELECT max(phenotype_id) FROM phenotype');
my $snapshot_sql = 'SELECT phenotype_id, value, collect_date FROM phenotype WHERE cvalue_id=? AND phenotype_id<=? ORDER BY phenotype_id';
my $original = $f->dbh->selectall_arrayref($snapshot_sql, undef, $trait_id, $previous_max);
my %design = map { $_ => {
    plot_name => "${name}_$_", plot_number => $_, stock_name => $accession_name,
    block_number => 1, rep_number => 1, row_number => 1, col_number => $_,
} } 1 .. 5;
my $created = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema, dbh => $f->dbh, owner_id => 41, operator => 'janedoe',
    program => 'test', trial_location => 'test_location', trial_name => $name,
    trial_description => 'Synthetic ANOVA phenotype/acronym integration regression',
    trial_year => 2030, design_type => 'CRD', design => \%design,
})->save_trial;
my $trial_id = $created->{trial_id};
ok($trial_id, 'created an independent synthetic trial') or BAIL_OUT('trial setup failed');
my $experiment_type = SGN::Model::Cvterm->get_cvterm_row($schema,
    'phenotyping_experiment', 'experiment_type')->cvterm_id;
my $location = $schema->resultset('NaturalDiversity::NdGeolocation')
    ->find({description => 'test_location'})->nd_geolocation_id;
my @observations;
my @values = ('0', '2.5', '3.5', '1e-3'); # Plot five has no measurement.
for my $index (0 .. $#values) {
    my $stock = $schema->resultset('Stock::Stock')->find({uniquename => $name.'_'.($index+1)});
    my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
        type_id => $experiment_type, nd_geolocation_id => $location,
        nd_experiment_stocks => [{stock_id => $stock->stock_id, type_id => $experiment_type}],
        nd_experiment_projects => [{project_id => $trial_id}],
    });
    my $phenotype = $schema->resultset('Phenotype::Phenotype')->create({
        uniquename => "${name}_observation_$index", cvalue_id => $trait_id,
        value => $values[$index], collect_date => '2030-05-20 12:00:00',
    });
    $schema->resultset('NaturalDiversity::NdExperimentPhenotype')->create({
        nd_experiment_id => $experiment->nd_experiment_id, phenotype_id => $phenotype->phenotype_id,
    });
    push @observations, $phenotype;
}
my $model = SGN::Model::solGS::solGS->new({schema => $schema, people_schema => $f->people_schema});
my %controllers = map { my $class = 'SGN::Controller::solGS::'.$_;
    ('solGS::'.$_ => $class->new) } qw(Anova Files Trait Utils Search CachedResult clearCache);
my $async = Test::MockObject->new;
my $protocol = Test::MockObject->new;
$protocol->mock(stash_protocol_id => sub { return });
$controllers{'solGS::AsyncJob'} = $async;
$controllers{'solGS::genotypingProtocol'} = $protocol;
my %controller_lookup = map { lc($_) => $controllers{$_} } keys %controllers;
my $context = Test::MockObject->new;
$context->{stash} = {trial_id => $trial_id, training_pop_id => $trial_id,
    solgs_dir => "$directory/solgs/trials", anova_dir => "$directory/anova/trials",
    analysis_metadata_dir => "$directory/metadata", data_set_type => 'single_population'};
$context->mock(stash => sub { $context->{stash} });
make_path($context->stash->{analysis_metadata_dir});
$context->mock(controller => sub { $controller_lookup{lc($_[1])} or die "Unexpected controller $_[1]" });
$context->mock(error => sub { [] });
$context->mock(user => sub { $f->user });
$context->mock(dbic_schema => sub {
    return $schema if $_[1] eq 'Bio::Chado::Schema';
    return $f->people_schema if $_[1] eq 'CXGN::People::Schema';
    die "Unexpected schema $_[1]";
});
my $request = Test::MockObject->new;
$request->mock(path => sub { 'anova/phenotype/data' });
$request->mock(param => sub { encode_json({trial_id => $trial_id, trait_id => $trait_id,
    data_structure => 'trial', data_set_type => 'single_population'}) });
$request->mock(params => sub { {analysis_types => 'anova', trials => "$trial_id"} });
$context->mock(req => sub { $request });
my $logger = Test::MockObject->new;
$logger->mock(error => sub { die "Unexpected cache error $_[1]" });
$context->mock(log => sub { $logger });
my ($anova, $files) = @controllers{'solGS::Anova', 'solGS::Files'};
my $jobs = Test::MockModule->new('SGN::Controller::solGS::Anova');
$jobs->mock(anova_query_jobs_file => sub { $_[1]->stash->{anova_query_jobs_file} = 'synchronous_fixture_query' });
my $queries = 0;
$async->mock(run_async => sub {
    $queries++;
    my $raw = $model->phenotype_data($trial_id);
    $files->traits_list_file($context, $trial_id);
    my $formatted = SGN::Controller::solGS::solGS->format_phenotype_dataset(
        $raw, $model->trial_metadata, $context->stash->{traits_list_file});
    write_file($anova->trial_phenotype_file($context), {binmode => ':utf8'}, $formatted);
    $controllers{'solGS::Utils'}->save_metadata($context);
});

$anova->anova_phenotype_data($context);
is($context->stash->{rest}{success}, 'Success.', 'real DB phenotype data passes the ANOVA preflight')
    or diag explain $context->stash->{rest};
is($queries, 1, 'the first request queries the actual phenotype model');
my $mapping = decode_json($context->stash->{rest}{traits_abbrs});
is($mapping->{trait_id}, $trait_id, 'the actual selected trait identity is retained');
my ($headers, $cells) = cached_column($mapping->{trait_abbr});
is($headers->[-1], 'notes', 'the actual formatter retains the final notes column');
is($headers->[-2], $mapping->{trait_abbr}, 'the generated acronym names the final trait column');
ok(scalar(grep(defined($_) && $_ eq '0', @$cells)), 'a measured zero reaches the cached input');
ok(scalar(grep(defined($_) && $_ eq '1e-3', @$cells)), 'stored scientific notation reaches the cached input');
ok(scalar(grep(!defined($_) || $_ eq '' || $_ eq 'NA', @$cells)), 'the unmeasured plot remains missing');

$observations[1]->update({value => '7.25'}); # Only this test-created row changes.
$context->stash->{rest} = {};
$anova->anova_phenotype_data($context);
is($queries, 1, 'a second request uses cached data until explicitly cleared');
$controllers{'solGS::clearCache'}->solgs_cache_clear($context);
is($context->stash->{rest}{success}, 1, 'the actual manual ANOVA reset succeeds');
for my $method (qw(traits_list_file traits_acronym_file all_traits_file)) {
    ok(!-s $context->stash->{$method}, "$method is invalidated with the raw input");
}
$context->stash->{rest} = {};
$anova->anova_phenotype_data($context);
is($context->stash->{rest}{success}, 'Success.', 'regenerated trait mapping and input pass preflight');
is($queries, 2, 'manual reset triggers a second actual model query');
$mapping = decode_json($context->stash->{rest}{traits_abbrs});
($headers, $cells) = cached_column($mapping->{trait_abbr});
ok(scalar(grep(defined($_) && $_ eq '7.25', @$cells)), 'regenerated input contains the corrected synthetic value');
ok(!grep(defined($_) && $_ eq '2.5', @$cells), 'regenerated input drops the old cached value');
is_deeply($f->dbh->selectall_arrayref($snapshot_sql, undef, $trait_id, $previous_max), $original,
    'original fixture observations for this trait are unchanged');
is($reference_accession->discard_changes->is_obsolete, $original_obsolete,
    'the original fixture accession status is unchanged');
$f->clean_up_db;
undef $f;
done_testing();

sub cached_column {
    my ($acronym) = @_;
    open(my $input, '<:encoding(UTF-8)', $anova->trial_phenotype_file($context)) or die $!;
    my $csv = Text::CSV->new({sep_char => "\t", binary => 1});
    my $headers = $csv->getline($input);
    my ($column) = grep { defined($acronym) && $headers->[$_] eq $acronym } 0 .. $#$headers;
    die 'The actual generated acronym has no phenotype column' unless defined $column;
    my @cells;
    while (my $row = $csv->getline($input)) { push @cells, $row->[$column]; }
    close $input;
    return ($headers, \@cells);
}

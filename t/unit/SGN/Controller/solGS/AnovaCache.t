use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::MockObject;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use File::Slurp qw(read_file write_file);
use SGN::Controller::solGS::Anova;
use SGN::Controller::solGS::Files;
use SGN::Controller::solGS::CachedResult;
use SGN::Controller::solGS::Utils;
use SGN::Controller::solGS::clearCache;

# All cache operations use a disposable local directory. The actual clear
# action, cache accessors, and cached-data checks run here. Database querying
# and asynchronous execution are replaced by a synthetic file writer below;
# this verifies regeneration is requested, not an R analysis or a DB refresh.
my $directory = tempdir('AnovaCacheXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $trial_id = 101;
my $other_trial_id = 202;
my $files = SGN::Controller::solGS::Files->new;
my $anova = SGN::Controller::solGS::Anova->new;
my $cached = SGN::Controller::solGS::CachedResult->new;
my $utils = SGN::Controller::solGS::Utils->new;
my $clear = SGN::Controller::solGS::clearCache->new;
my $async = Test::MockObject->new;
my %controllers = (
    'solGS::Files' => $files, 'solGS::CachedResult' => $cached,
    'solGS::Utils' => $utils, 'solGS::AsyncJob' => $async,
);
my $context = Test::MockObject->new;
$context->{stash} = {
    trial_id => $trial_id,
    solgs_dir => File::Spec->catdir($directory, 'solgs', 'trials'),
    anova_dir => File::Spec->catdir($directory, 'anova', 'trials'),
    correlation_dir => File::Spec->catdir($directory, 'correlation', 'trials'),
    solgs_datasets_dir => File::Spec->catdir($directory, 'solgs', 'tempfiles', 'datasets'),
    analysis_metadata_dir => File::Spec->catdir($directory, 'metadata'),
};
$context->mock(stash => sub { $context->{stash} });
$context->mock(controller => sub {
    my ($self, $name) = @_;
    die "Unexpected controller: $name" unless $controllers{$name};
    return $controllers{$name};
});
my $request = Test::MockObject->new;
# This is the existing manual button's request shape; no new path inputs.
my $request_args = {analysis_types => 'anova', trials => "$trial_id"};
$request->mock(params => sub { return $request_args });
$context->mock(req => sub { $request });
my $logger = Test::MockObject->new;
$logger->mock(error => sub { die "Unexpected cache removal error: $_[1]" });
$context->mock(log => sub { $logger });

my $raw_file = $anova->trial_phenotype_file($context, $trial_id);
my $old_content = "unit\tsynthetic_trait\nsynthetic_unit\t1\n";
write_file($raw_file, $old_content);
my $other_raw_file = $anova->trial_phenotype_file($context, $other_trial_id);
my $other_content = "unit\tsynthetic_trait\nother_unit\t9\n";
write_file($other_raw_file, $other_content);
my $anova_dir = $anova->anova_trial_cache_dir($context, $trial_id);
my $anova_output = File::Spec->catfile($anova_dir, 'synthetic_anova_output.txt');
write_file($anova_output, 'old ANOVA result');
my $anova_temp_dir = $anova->anova_trial_temp_dir($context, $trial_id);
my $anova_temp = File::Spec->catfile($anova_temp_dir, 'synthetic_job.txt');
write_file($anova_temp, 'old ANOVA temporary input');
my $other_anova_dir = $anova->anova_trial_cache_dir($context, $other_trial_id);
my $other_anova_output = File::Spec->catfile($other_anova_dir, 'synthetic_anova_output.txt');
write_file($other_anova_output, 'other trial ANOVA result');
my $model = File::Spec->catfile($files->solgs_cache_dir($context, $trial_id), 'synthetic_model.txt');
write_file($model, 'unrelated shared-cache model');
make_path($context->stash->{analysis_metadata_dir});
$files->phenotype_metadata_file($context);
my $metadata = $context->stash->{phenotype_metadata_file};
write_file($metadata, 'shared phenotype metadata');
my %trait_inputs;
for my $method (qw(traits_list_file traits_acronym_file all_traits_file)) {
    $files->$method($context, $trial_id);
    $trait_inputs{$method} = $context->stash->{$method};
    write_file($trait_inputs{$method}, "stale per-trial $method");
}
$files->traits_acronym_file($context, $other_trial_id);
my $other_acronyms = $context->stash->{traits_acronym_file};
write_file($other_acronyms, 'other trial trait acronym mapping');

my $queries = 0;
my $anova_mock = Test::MockModule->new('SGN::Controller::solGS::Anova');
$anova_mock->mock(anova_query_jobs_file => sub {
    my ($self, $c) = @_;
    $c->stash->{anova_query_jobs_file} = 'synthetic_query_job';
});
my $new_content = "unit\tsynthetic_trait\nsynthetic_unit\t2\n";
$async->mock(run_async => sub {
    my ($self, $c) = @_;
    $queries++;
    my $new_file = $anova->trial_phenotype_file($c);
    write_file($new_file, $new_content);
});

$anova->create_anova_phenodata_file($context);
is($queries, 0, 'an existing raw input is reused before a manual clear');
is(scalar read_file($raw_file), $old_content, 'cached input starts with the old observations');

$request_args = {analysis_types => 'correlation', trials => "$trial_id"};
$clear->solgs_cache_clear($context);
is($context->stash->{rest}{success}, 1, 'another analysis type can still be cleared');
is(scalar read_file($raw_file), $old_content, 'clearing another analysis type retains the shared raw input');

# Dataset identifiers are an existing endpoint input, but outside this
# restoration of numeric trial raw-input invalidation. Keep their files.
make_path($context->stash->{solgs_datasets_dir});
my $dataset_file = $files->phenotype_file_name($context, 'dataset_101');
write_file($dataset_file, 'unsupported shared-input sentinel');
$request_args = {analysis_types => 'anova', trials => 'dataset_101'};
$clear->solgs_cache_clear($context);
is(scalar read_file($dataset_file), 'unsupported shared-input sentinel',
    'ANOVA clearing does not expand raw-input deletion to dataset identifiers');

$request_args = {analysis_types => 'anova', trials => "$trial_id"};
$clear->solgs_cache_clear($context);
is($context->stash->{rest}{success}, 1, 'the existing manual ANOVA clear action succeeds');
ok(!-s $raw_file, 'manual ANOVA clear invalidates its shared raw phenotype input');
for my $method (sort keys %trait_inputs) {
    ok(!-s $trait_inputs{$method}, "manual ANOVA clear invalidates dependent $method");
}
ok(!-e $anova_output, 'requested ANOVA output is removed');
ok(!-e $anova_temp, 'requested ANOVA temporary input is removed');
is(scalar read_file($model), 'unrelated shared-cache model', 'the same trial solGS model is retained');
is(scalar read_file($other_raw_file), $other_content, 'another trial raw input is retained');
is(scalar read_file($other_anova_output), 'other trial ANOVA result', 'another trial ANOVA output is retained');
is(scalar read_file($metadata), 'shared phenotype metadata', 'shared phenotype metadata is retained');
is(scalar read_file($other_acronyms), 'other trial trait acronym mapping',
    'another trial trait acronym mapping is retained');

# phenotype_file_name() can recreate an empty cache file while obtaining its
# path. File existence alone must not prevent the following data query.
my $empty_input = $anova->trial_phenotype_file($context, $trial_id);
ok(!-s $empty_input, 'getting the raw path after clearing does not restore stale observations');
my $regenerated = $anova->create_anova_phenodata_file($context);
is($queries, 1, 'the next ANOVA request queries phenotype input again');
is(scalar read_file($regenerated), $new_content, 'regeneration replaces the old observations');
is($anova->trial_phenotype_file($context), $regenerated, 'the actual ANOVA accessor uses the regenerated input');
is(scalar read_file($model), 'unrelated shared-cache model', 'regeneration leaves the solGS model intact');
is(scalar read_file($other_raw_file), $other_content, 'regeneration leaves the other trial untouched');

# Existing all-analysis callers can select solgs before anova. Removing the
# ANOVA input must not recreate the solgs cache after its requested deletion.
my $selected_solgs_cache = $files->solgs_cache_dir($context, $trial_id);
my $selected_anova_cache = $anova->anova_trial_cache_dir($context, $trial_id);
write_file($anova->trial_phenotype_file($context, $trial_id), $old_content);
write_file($model, 'selected solGS model');
write_file($anova_output, 'selected ANOVA result');
$request_args = {analysis_types => ['solgs', 'anova'], trials => "$trial_id"};
$clear->solgs_cache_clear($context);
is($context->stash->{rest}{success}, 1, 'a combined solgs and ANOVA clear succeeds');
ok(!-d $selected_solgs_cache, 'the selected solgs cache remains absent after ANOVA clearing');
ok(!-d $selected_anova_cache, 'the selected ANOVA cache remains absent');
is(scalar read_file($other_raw_file), $other_content, 'combined clearing preserves the other trial raw input');

done_testing();

#!/usr/bin/env perl
# The cached phenotype file and analysis results of a trial are cleared when
# the trial's stored phenotypes no longer match the fingerprint kept next to the cache
# (no database needed: the fingerprint is supplied by the test).
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use SGN::Controller::solGS::Files;
use SGN::Controller::solGS::clearCache;

{
    package Local::Log;
    sub new { return bless { errors => [] }, shift }
    sub error { my ($self, $message) = @_; push @{ $self->{errors} }, $message; return }

    package Local::Context;
    sub new { my ($class, %stash) = @_; return bless { stash => {%stash}, log => Local::Log->new }, $class }
    sub stash { return $_[0]->{stash} }
    sub log { return $_[0]->{log} }
    sub controller { return 'SGN::Controller::' . $_[1] }
}

my $files = 'SGN::Controller::solGS::Files';
my $root = tempdir(CLEANUP => 1);
my %dirs = map { ("${_}_dir" => File::Spec->catdir($root, $_, 'trials')) }
    @SGN::Controller::solGS::clearCache::ANALYSIS_TYPES;

my $fingerprint = '3:aaa';
my $fingerprint_reads = 0;
my $combined_population = 3147291660;    # crc32 of its trial ids: numeric, but no project
{
    no warnings 'redefine';
    *SGN::Controller::solGS::Files::trial_phenotypes_fingerprint = sub {
        my ($self, $c, $id) = @_;
        $fingerprint_reads++;
        return if $id == $combined_population;
        die "database is away\n" if !defined $fingerprint;
        return $fingerprint;
    };
}

sub cache_dir { my ($type, $id) = @_; return File::Spec->catdir($root, $type, 'trials', $id, 'cache') }
sub put {
    my ($type, $id, $subdir, $name) = @_;
    my $dir = File::Spec->catdir($root, $type, 'trials', $id, $subdir);
    make_path($dir);
    my $file = File::Spec->catfile($dir, $name);
    open(my $fh, '>', $file) or die "$file: $!";
    print {$fh} "cached\n";
    close($fh);
    return $file;
}
sub request { return Local::Context->new(%dirs) }
sub stored_fingerprint {
    my $file = File::Spec->catfile($root, 'solgs', 'trials', 672, 'phenotypes_fingerprint');
    return '' if !-e $file;
    open(my $fh, '<', $file) or die "$file: $!";
    local $/;
    return scalar <$fh>;
}

is($files->trial_id_of_cache_dir(cache_dir('correlation', 672)), 672, 'a trial cache directory gives the trial id');
is($files->trial_id_of_cache_dir(cache_dir('solgs', 672) . '/'), 672, 'also with a trailing slash');
for my $other (File::Spec->catdir($root, 'kinship', 'trials', 'list_20', 'cache'),
               File::Spec->catdir($root, 'solgs', 'trials', 'dataset_5', 'cache'),
               File::Spec->catdir($root, 'solgs', 'tempfiles', 'lists'),
               File::Spec->catdir($root, 'solgs', 'cache'), undef) {
    is($files->trial_id_of_cache_dir($other), undef, 'not a trial cache: ' . ($other // 'no directory'));
}

# A cache written before the fingerprint existed: its age is unknown, so it is rebuilt once.
my @old = (put('solgs', 672, 'cache', 'phenotype_data_672'), put('correlation', 672, 'cache', 'pheno_corr_json_672.txt'),
           put('correlation', 672, 'tempfiles', 'phenotypic-672-in'), put('anova', 672, 'cache', 'anova_table_672'));
my $other_trial = put('solgs', 674, 'cache', 'phenotype_data_674');
my $list = put('kinship', 'list_20', 'cache', 'kinship_list_20');

my $c = request();
$files->clear_stale_trial_cache($c, cache_dir('correlation', 672));
ok(!(grep { -e $_ } @old), 'cache without a fingerprint: the cached files of every analysis type are removed');
ok(-d cache_dir('correlation', 672) && -d cache_dir('solgs', 672), 'the cache directories are still there for the request');
ok(-d File::Spec->catdir($root, 'correlation', 'trials', 672, 'tempfiles'), 'so is the directory for its temporary files');
is(stored_fingerprint(), '3:aaa', 'the fingerprint is written next to the trial cache');
ok(-e $other_trial, 'another trial is untouched');
ok(-e $list, 'a list cache is untouched');
is_deeply($c->log->{errors}, [], 'nothing logged as an error');

# Same request, more cache files: the database is asked once per trial.
$fingerprint_reads = 0;
$c = request();
my @fresh = (put('solgs', 672, 'cache', 'phenotype_data_672'), put('correlation', 672, 'cache', 'pheno_corr_json_672.txt'));
$files->clear_stale_trial_cache($c, cache_dir('solgs', 672)) for 1 .. 3;
$files->clear_stale_trial_cache($c, cache_dir('correlation', 672));
is($fingerprint_reads, 1, 'one fingerprint query per trial and request');
ok(!(grep { !-e $_ } @fresh), 'unchanged phenotypes: the cache is kept');

# Values were stored, changed or deleted since.
$fingerprint = '4:bbb';
$c = request();
$files->clear_stale_trial_cache($c, cache_dir('solgs', 672));
ok(!(grep { -e $_ } @fresh), 'changed phenotypes: the cached phenotype file and results are removed');
is(stored_fingerprint(), '4:bbb', 'the new fingerprint is kept');
ok(-e $other_trial, 'another trial is still untouched');

# The check itself must never break an analysis.
@fresh = (put('solgs', 672, 'cache', 'phenotype_data_672'));
$fingerprint = undef;
$c = request();
$files->clear_stale_trial_cache($c, cache_dir('solgs', 672));
ok(-e $fresh[0], 'fingerprint query fails: the cache is kept');
is(stored_fingerprint(), '4:bbb', 'and so is the stored fingerprint');
like($c->log->{errors}->[0], qr/fingerprint of trial 672.*database is away/s, 'the failure is logged');

$files->clear_stale_trial_cache(request(), File::Spec->catdir($root, 'kinship', 'trials', 'list_20', 'cache'));
ok(-e $list, 'a list cache is never checked');

# A combined population keeps its catalogue and models under a numeric id that is no trial.
my $catalogue = put('solgs', $combined_population, 'cache', 'combined_pops_catalogue_file');
$c = request();
$files->clear_stale_trial_cache($c, cache_dir('solgs', $combined_population));
ok(-e $catalogue, 'an id without a project: the cache is kept');
ok(!-e File::Spec->catfile($root, 'solgs', 'trials', $combined_population, 'phenotypes_fingerprint'), 'and gets no fingerprint');
is_deeply($c->log->{errors}, [], 'without an error');

done_testing();

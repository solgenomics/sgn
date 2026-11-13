use strict;

use lib 't/lib';
use Test::More qw( no_plan );
use Data::Dumper;
use SGN::Test::Fixture;
use_ok('CXGN::Job');

my $t = SGN::Test::Fixture->new();

$t->dbh()->begin_work();

my $job;
my $dbhost = $t->config->{dbhost};
my $dbname = $t->config->{dbname};
my $dbuser = $t->config->{dbuser};
my $dbpass = $t->config->{dbpass};
my $basepath = $t->config->{basepath};

eval {
    $job = CXGN::Job->new({
        schema => $t->bcs_schema(),
        dbhost => $dbhost,
        dbuser => $dbuser,
        dbname => $dbname,
        dbpass => $dbpass,
        basepath => $basepath,
        people_schema => $t->people_schema(),
        sp_person_id => 41, #for Jane Doe
        name => 'unit_fixture test job',
        cmd => 'sleep 5',
        job_type => 'report', # try to create a job with a valid cvterm
    });

    my $job2 = CXGN::Job->new({
        schema => $t->bcs_schema(),
        people_schema => $t->people_schema(),
        dbhost => $dbhost,
        dbuser => $dbuser,
        dbname => $dbname,
        dbpass => $dbpass,
        basepath => $basepath,
        sp_person_id => 41, #for Jane Doe
        name => 'unit_fixture test job',
        cmd => 'sleep 5',
        job_type => 'unknown_job_type', # try to create a job with a missing cvterm
    });
};

if ($@) {
    print STDERR "Error making jobs: $@\n";
}

ok($@ eq '', "Check for successful object creation");

ok($job->name() eq "unit_fixture test job", 'Check for correct arg parsing');
ok($job->create_timestamp() ne "", 'Check for create timestamp');
eval {
    $job->generate_finish_timestamp_cmd();
};
ok($@, 'Check for refusal to generate finish timestamp due to no job ID');

my $SYSTEM_MODE = $ENV{SYSTEM};
# The following tests won't work on github, but you can run them locally
SKIP: {
    skip "Skip if run under git", 4 unless $SYSTEM_MODE ne "GITACTION";
    my $job_id = $job->submit();

    ok($job_id, 'Check for successful job submission');
    ok($job->check_status() eq "submitted", 'Check for proper job status');

    $job->cancel();

    sleep (6);

    ok($job->check_status() eq "canceled", 'Check for proper job status');

    eval {
        $job->delete();
    };
    ok($@ !~ m/An error occurred deleting job from database/, 'Make sure DB deletion worked cleanly');
};

# consuming a job. These jobs never go to a backend; their status is set directly, the way the
# upload validation jobs are.
#
my @status_jobs;
my $new_status_job = sub {
    my $status = shift;
    my $status_job = CXGN::Job->new({
        schema => $t->bcs_schema(),
        people_schema => $t->people_schema(),
        sp_person_id => 41,
        name => "unit_fixture $status job",
        job_type => 'upload',
        additional_args => { is_validation => 1 }
    });
    $status_job->update_status($status);
    push @status_jobs, $status_job;
    return $status_job;
};

my $unsaved_job = CXGN::Job->new({
    schema => $t->bcs_schema(),
    people_schema => $t->people_schema(),
    sp_person_id => 41,
    name => 'unit_fixture unsaved job',
    job_type => 'upload'
});
eval { $unsaved_job->consume(); };
like($@, qr/Only stored jobs can be consumed/, 'An unsaved job cannot be consumed');

foreach my $status ('submitted', 'failed', 'timed_out', 'canceled') {
    my $status_job = $new_status_job->($status);
    eval { $status_job->consume(); };
    like($@, qr/cannot be consumed because it is not finished/, "A $status job cannot be consumed");
    is($status_job->status(), $status, "A $status job keeps its status when consuming it fails");
}

my $finished_job = $new_status_job->('finished');
eval { $finished_job->consume(); };
is($@, '', 'A finished job can be consumed');
is($finished_job->status(), 'consumed', 'A consumed job has the consumed status');

my $reloaded_job = CXGN::Job->new({
    schema => $t->bcs_schema(),
    people_schema => $t->people_schema(),
    sp_job_id => $finished_job->sp_job_id()
});
is($reloaded_job->status(), 'consumed', 'The consumed status is stored');
ok($reloaded_job->finish_timestamp(), 'A consumed job keeps its finish timestamp');
is($reloaded_job->check_status(), 'consumed', 'check_status does not turn a consumed job back into a finished one');

eval { $reloaded_job->consume(); };
is($@, '', 'Consuming a consumed job again is allowed');
is($reloaded_job->status(), 'consumed', 'A job consumed again stays consumed');

# jobs that end without recording a result of their own
#
my $new_job = sub {
    my ($job_type, $additional_args) = @_;
    my $new = CXGN::Job->new({
        schema => $t->bcs_schema(),
        people_schema => $t->people_schema(),
        dbhost => $dbhost, dbuser => $dbuser, dbname => $dbname, dbpass => $dbpass, basepath => $basepath,
        sp_person_id => 41,
        name => "unit_fixture $job_type job",
        job_type => $job_type,
        additional_args => $additional_args
    });
    $new->update_status('submitted');
    push @status_jobs, $new;
    return $new;
};
my $reload = sub {
    return CXGN::Job->new({ schema => $t->bcs_schema(), people_schema => $t->people_schema(), sp_job_id => $_[0]->sp_job_id() });
};

my $silent_upload = $new_job->('upload', { final_upload => 1 });
ok($silent_upload->reports_own_result(), 'A final upload reports its own result');
ok($silent_upload->record_exit(0), 'An upload that exits cleanly without reporting a result is caught');
my $reloaded_upload = $reload->($silent_upload);
is($reloaded_upload->status(), 'failed', 'An upload that ended without reporting a result is failed');
like($reloaded_upload->additional_args()->{error_messages}, qr/ended without reporting a result/, 'and its report says so');

my $silent_validation = $new_job->('upload', { is_validation => 1, error_messages => 'earlier message' });
ok($silent_validation->record_exit(1), 'A validation whose command failed is caught');
like($reload->($silent_validation)->additional_args()->{error_messages}, qr/^earlier message<br>Job \d+ exited with code 1 without reporting a result/, 'The reason is added after any messages already recorded');

my $reported_job = $new_status_job->('finished');
ok(!$reported_job->record_exit(1), 'A job that already recorded its result is left alone');
is($reload->($reported_job)->status(), 'finished', 'A job that recorded its result keeps its status');

my $report_job = $new_job->('report', {});
ok(!$report_job->reports_own_result(), 'Other jobs do not report their own result');
ok(!$report_job->record_exit(0), 'Another kind of job that exits cleanly is left to check_status');
is($reload->($report_job)->status(), 'submitted', 'and is not marked failed');
ok($report_job->record_exit(137), 'Another kind of job that was killed is caught');
like($reload->($report_job)->additional_args()->{error_messages}, qr/stopped by signal 9 \(usually because it ran out of memory\)/, 'A kill is reported as a signal');

# without an exit code (a job submitted before record_exit existed), check_status still does not
# call an upload a success just because it has a finish timestamp
my $timestamped_upload = $new_job->('upload', { final_upload => 1 });
$timestamped_upload->finish_timestamp('2026-01-01 00:00:00');
$timestamped_upload->store();
is($reload->($timestamped_upload)->check_status(), 'failed', 'An upload with only a finish timestamp is failed by check_status');
like($reload->($timestamped_upload)->additional_args()->{error_messages}, qr/ended without reporting a result/, 'and its report says why');

my $timestamped_report = $new_job->('report', {});
$timestamped_report->finish_timestamp('2026-01-01 00:00:00');
$timestamped_report->store();
is($reload->($timestamped_report)->check_status(), 'finished', 'Other jobs with a finish timestamp are still finished');

my $finish_cmd = $timestamped_report->generate_finish_timestamp_cmd();
like($finish_cmd, qr/sp_job_exit_code=\$\?;/, 'The finish timestamp command keeps the job\'s exit code');
like($finish_cmd, qr/record_finish_timestamp\.pl .* -e \$sp_job_exit_code/, 'and passes it to record_finish_timestamp.pl');
like($finish_cmd, qr/exit \$sp_job_exit_code\s*$/, 'and exits with it');

# the same, end to end through the job queue
SKIP: {
    skip "Skip if run under git", 6 unless $SYSTEM_MODE ne "GITACTION";

    my $run = sub {
        my ($cmd, $job_type, $additional_args) = @_;
        my $queued = CXGN::Job->new({
            schema => $t->bcs_schema(), people_schema => $t->people_schema(),
            dbhost => $dbhost, dbuser => $dbuser, dbname => $dbname, dbpass => $dbpass, basepath => $basepath,
            sp_person_id => 41, name => "unit_fixture queued $job_type job", cmd => $cmd,
            job_type => $job_type, additional_args => $additional_args
        });
        $queued->submit();
        push @status_jobs, $queued;
        eval { $queued->wait(120); };
        my $done = $reload->($queued);
        $done->check_status();
        return $reload->($queued);
    };

    my $crashed = $run->("perl -e 'exit 3'", 'upload', { final_upload => 1 });
    is($crashed->status(), 'failed', 'A queued upload whose script exits with an error is failed');
    like($crashed->additional_args()->{error_messages}, qr/exited with code 3 without reporting a result/, 'and its report gives the exit code');
    ok($crashed->finish_timestamp(), 'and it still gets a finish timestamp');

    my $silent = $run->("perl -e 'exit 0'", 'upload', { is_validation => 1 });
    is($silent->status(), 'failed', 'A queued validation that never reports a result is failed');

    my $plain = $run->("perl -e 'exit 0'", 'report', {});
    is($plain->status(), 'finished', 'A queued job of another kind that exits cleanly is finished');

    my $plain_failure = $run->("perl -e 'exit 2'", 'report', {});
    is($plain_failure->status(), 'failed', 'A queued job of another kind that exits with an error is failed');
}

$_->delete() foreach @status_jobs;

$t->dbh->rollback();
$t->clean_up_db();

done_testing();
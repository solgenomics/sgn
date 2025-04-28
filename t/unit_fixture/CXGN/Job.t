use strict;

use lib 't/lib';
use Test::More qw( no_plan );
use Data::Dumper;
use SGN::Test::Fixture;
use_ok('CXGN::Job');

my $t = SGN::Test::Fixture->new();

$t->dbh()->begin_work();

my $job_finish_log = $t->config->{job_finish_log} ? $t->config->{job_finish_log} : '/home/production/volume/logs/job_finish.log';

my $job = CXGN::Job->new({
    schema => $t->bcs_schema(),
    people_schema => $t->people_schema(),
    sp_person_id => 41, #for Jane Doe
    name => 'unit_fixture test job',
    cmd => 'sleep 5',
    job_type => 'report',
    finish_logfile => $job_finish_log
});

ok($job->name() eq "unit_fixture test job", 'Check for correct arg parsing');
ok($job->create_timestamp() ne "", 'Check for create timestamp');
ok($job->finish_logfile() eq $job_finish_log, 'Check for correct arg parsing');
eval {
    $job->generate_finish_timestamp_cmd();
};
ok($@, 'Check for refusal to generate finish timestamp');

my $SYSTEM_MODE = $ENV{SYSTEM};
# The following tests wont work on github, but you can run them locally
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
    ok($@ !~ m/No such file or directory/, 'Making sure DB deletion worked, making sure job finish log was handled right');
};

system('rm /home/production/volume/logs/job_finish.log');

$t->dbh->rollback();

done_testing();
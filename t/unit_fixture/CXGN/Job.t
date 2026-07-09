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

eval {
    $job = CXGN::Job->new({
        schema => $t->bcs_schema(),
        people_schema => $t->people_schema(),
        sp_person_id => 41, #for Jane Doe
        name => 'unit_fixture test job',
        cmd => 'sleep 5',
        job_type => 'report', # try to create a job with a valid cvterm
    });

    my $job2 = CXGN::Job->new({
        schema => $t->bcs_schema(),
        people_schema => $t->people_schema(),
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
    $job->generate_finish_timestamp_cmd($dbhost, $dbname, $dbuser, $dbpass);
};
ok($@, 'Check for refusal to generate finish timestamp due to no job ID');

my $SYSTEM_MODE = $ENV{SYSTEM};
# The following tests wont work on github, but you can run them locally
SKIP: {
    skip "Skip if run under git", 4 unless $SYSTEM_MODE ne "GITACTION";
    my $job_id = $job->submit($dbhost, $dbname, $dbuser, $dbpass);

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

$t->dbh->rollback();
$t->clean_up_db();

done_testing();
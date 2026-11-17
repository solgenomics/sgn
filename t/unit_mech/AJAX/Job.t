
# Tests /ajax/job/consume, which marks a finished job as consumed

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;

use CXGN::Job;

my $f = SGN::Test::Fixture->new();

my $janedoe_id = 41; # a curator

my @jobs;

# Validation jobs never go to a backend; their status is set directly, so these do the same.
sub status_job {
    my $status = shift;
    my $job = CXGN::Job->new({
        schema => $f->bcs_schema(),
        people_schema => $f->people_schema(),
        sp_person_id => $janedoe_id,
        name => "consume test $status job",
        job_type => 'upload',
        additional_args => { is_validation => 1 }
    });
    $job->update_status($status);
    push @jobs, $job;
    return $job;
}

sub stored_status {
    my $job = shift;
    return CXGN::Job->new({
        schema => $f->bcs_schema(),
        people_schema => $f->people_schema(),
        sp_job_id => $job->sp_job_id()
    })->status();
}

my $finished_job = status_job('finished');
my $response;

# without a login
#
my $anonymous_mech = Test::WWW::Mechanize->new;
$anonymous_mech->get_ok('http://localhost:3010/ajax/job/consume/'.$finished_job->sp_job_id(), 'consume without logging in');
$response = decode_json $anonymous_mech->content;
like($response->{error}, qr/must be logged in/, 'consuming needs a login');
is(stored_status($finished_job), 'finished', 'a job is not consumed without a login');

# as a user who neither owns the job nor is a curator
#
my $other_mech = Test::WWW::Mechanize->new;
$other_mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "johndoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login as johndoe');
$other_mech->get_ok('http://localhost:3010/ajax/job/consume/'.$finished_job->sp_job_id(), 'consume another user\'s job');
$response = decode_json $other_mech->content;
like($response->{error}, qr/do not have permission/, 'only the owner or a curator can consume a job');
is(stored_status($finished_job), 'finished', 'a job is not consumed by another user');

# as the job's owner
#
my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login as janedoe');

foreach my $status ('submitted', 'failed', 'timed_out', 'canceled') {
    my $job = status_job($status);
    $mech->get_ok('http://localhost:3010/ajax/job/consume/'.$job->sp_job_id(), "consume a $status job");
    $response = decode_json $mech->content;
    like($response->{error}, qr/not finished/, "a $status job cannot be consumed");
    is(stored_status($job), $status, "a $status job keeps its status");
}

$mech->get_ok('http://localhost:3010/ajax/job/consume/'.$finished_job->sp_job_id(), 'consume a finished job');
$response = decode_json $mech->content;
ok($response->{success}, 'a finished job can be consumed') or diag Dumper $response;
is($response->{status}, 'consumed', 'the response gives the consumed status');
is(stored_status($finished_job), 'consumed', 'the consumed status is stored');

$mech->get_ok('http://localhost:3010/ajax/job/consume/'.$finished_job->sp_job_id(), 'consume the job again');
$response = decode_json $mech->content;
ok($response->{success}, 'a consumed job can be consumed again, as when a validation is committed again');
is(stored_status($finished_job), 'consumed', 'a job consumed again stays consumed');

$mech->get_ok('http://localhost:3010/ajax/job/consume/999999999', 'consume a missing job');
$response = decode_json $mech->content;
like($response->{error}, qr/was not found/, 'a missing job cannot be consumed');

$mech->get_ok('http://localhost:3010/ajax/job/consume/abc', 'consume with a bad job id');
$response = decode_json $mech->content;
like($response->{error}, qr/Invalid job ID/, 'a bad job id is rejected');

# the consumed job shows as a successful end state in the user's job log
#
$mech->get_ok("http://localhost:3010/ajax/job/jobs_by_user/$janedoe_id", 'job log');
$response = decode_json $mech->content;
my ($log_row) = grep { $_->{id} == $finished_job->sp_job_id() } @{ $response->{data}->{data} };
is($log_row->{status}, 'consumed', 'the job log shows the consumed status');
unlike($log_row->{actions}, qr/cancel_job/, 'a consumed job cannot be canceled from the job log');

# the consumed job is still listed with the user's validations, so it can be committed again
#
$mech->get_ok("http://localhost:3010/ajax/job/validations_in_progress/$janedoe_id", 'validations in progress');
$response = decode_json $mech->content;
my ($validation_row) = grep { $_->{job_id} == $finished_job->sp_job_id() } @{ $response->{data} };
is($validation_row->{status}, 'consumed', 'a consumed validation is still listed, as consumed');

# clean up the jobs that are left
#
foreach my $job (@jobs) {
    my $row = $f->people_schema()->resultset('SpJob')->find({ sp_job_id => $job->sp_job_id() });
    $row->delete() if $row;
}

$f->clean_up_db();

done_testing();

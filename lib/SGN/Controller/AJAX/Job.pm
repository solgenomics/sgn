package SGN::Controller::AJAX::Job;

use Moose;
use CXGN::Job;

BEGIN {extends 'Catalyst::Controller::REST'};

use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

sub retrieve_jobs_by_user :Path('/ajax/job/jobs_by_user') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $jobs = CXGN::Job->get_user_submitted_jobs(
        $bcs_schema,
        $people_schema,
        $sp_person_id
    );

    my $data = {
        data => [],
        columns => [
            {title => 'Name', data => 'name'},
            {title => 'Type', data => 'type'},
            {title => 'Start Time', data => 'create_timestamp'},
            {title => 'End Time', data => 'finish_timestamp'},
            {title => 'Status', data => 'status'},
            {title => 'Results', data => 'results_page'},
            {title => 'Actions', data => 'actions'},
        ]
    };

    foreach my $job_id (@{$jobs}) {
        my $job = CXGN::Job->new({
            schema => $bcs_schema,
            people_schema => $people_schema,
            sp_job_id => $job_id
        });
        my $row = {
            id => $job_id,
            name => $job->args->{name},
            type => $job->args->{type},
            status => $job->check_status(),
            create_timestamp => $job->create_timestamp(),
            finish_timestamp => $job->finish_timestamp(),
            results_page => $job->args->{results_page},
            actions => "<span id=\"$job_id\" style=\"display: none;\"></span><button class=\"btn btn-small btn-danger\">Dismiss</button>"
        };

        push @{$data->{data}}, $row;
    }
    $c->stash->{rest} = {data => $data};
}

sub delete :Path('/ajax/job/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_job_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $job = CXGN::Job->new({
            schema => $bcs_schema,
            people_schema => $people_schema,
            sp_job_id => $sp_job_id
    });

    $job->delete();
}

sub cancel :Path('/ajax/job/cancel') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_job_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $job = CXGN::Job->new({
            schema => $bcs_schema,
            people_schema => $people_schema,
            sp_job_id => $sp_job_id
    });

    $job->cancel();
}
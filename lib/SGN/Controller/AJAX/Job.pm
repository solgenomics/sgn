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

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if ($sp_person_id ne $logged_user && $role ne "curator") {
        die "You do not have permission to see these job logs.\n";
    }

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
        my $actions_html = "<span id=\"$job_id\" style=\"display: none;\"></span><button id=\"dismiss_job_$job_id\" onclick=\"jsMod['job'].dismiss_job($job_id);\" class=\"btn btn-small btn-danger\">Dismiss</button>";
        my $status = $job->check_status();
        # if ($status eq "finished" && $job->retrieve_argument('type') =~ /analysis/) {
        #     $actions_html .= "<button id=\"save_job_$job_id\" class=\"btn btn-small btn-success\">Save Results</button>";
        # } 
        if ($status eq "submitted") {
            $actions_html .= "<button id=\"cancel_job_$job_id\" onclick=\"jsMod['job'].cancel_job($job_id)\" class=\"btn btn-small btn-danger\">Cancel</button>"
        }
        my $row = {
            id => $job_id,
            name => $job->retrieve_argument('name'),
            type => $job->type(),
            status => $status,
            create_timestamp => $job->create_timestamp(),
            finish_timestamp => $job->finish_timestamp(),
            results_page => '<a href="'.$job->retrieve_argument('results_page').'>'.$job->retrieve_argument('results_page').'</a>',
            actions => $actions_html
        };

        push @{$data->{data}}, $row;
    }
    $c->stash->{rest} = {data => $data};
}

sub delete :Path('/ajax/job/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_job_id = shift;

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $job = CXGN::Job->new({
            schema => $bcs_schema,
            people_schema => $people_schema,
            sp_job_id => $sp_job_id
    });

    if ($job->sp_person_id() ne $logged_user && $role ne "curator") {
        die "You do not have permission to delete this job.\n";
    }

    $job->delete();
    $c->stash->{rest} = {success => 1};
}

sub cancel :Path('/ajax/job/cancel') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_job_id = shift;

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $job = CXGN::Job->new({
            schema => $bcs_schema,
            people_schema => $people_schema,
            sp_job_id => $sp_job_id
    });

    if ($job->sp_person_id() ne $logged_user && $role ne "curator") {
        die "You do not have permission to cancel this job.\n";
    }

    $job->cancel();
    $c->stash->{rest} = {success => 1};
}

sub delete_dead_jobs :Path('/ajax/job/delete_dead_jobs') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if ($sp_person_id ne $logged_user && $role ne "curator") {
        die "You do not have permission to delete these job logs.\n";
    }

    CXGN::Job->delete_dead_jobs(
        $bcs_schema,
        $people_schema,
        $sp_person_id
    );
    $c->stash->{rest} = {success => 1};
}

sub delete_older_than :Path('/ajax/job/delete_older_than') Args(2) {
    my $self = shift;
    my $c = shift;
    my $older_than = shift;
    my $sp_person_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if ($sp_person_id ne $logged_user && $role ne "curator") {
        die "You do not have permission to delete these job logs.\n";
    }

    if ($older_than ne "one_week" &&  $older_than ne "one_month" && $older_than ne "six_months" && $older_than ne "one_year") {
        die "Invalid time selection: $older_than.\n";
    }

    CXGN::Job->delete_jobs_older_than(
        $bcs_schema,
        $people_schema,
        $sp_person_id,
        $older_than
    );
    $c->stash->{rest} = {success => 1};
}
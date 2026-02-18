package SGN::Controller::AJAX::Job;

use Moose;
use CXGN::Job;
use CXGN::People::Person;
use Try::Tiny;

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
        $c->stash->{rest} = {error => "You do not have permission to see these job logs.\n"} ;
        return;
    }

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $jobs = CXGN::Job->get_user_submitted_jobs(
        $bcs_schema,
        $people_schema,
        $sp_person_id,
        $role
    );

    my $data;

    if ($role eq "curator") {
        $data = {
            data => [],
            columns => [
                {title => 'Submitted By', data => 'user'},
                {title => 'Name', data => 'name'},
                {title => 'Type', data => 'type'},
                {title => 'Start Time', data => 'create_timestamp'},
                {title => 'End Time', data => 'finish_timestamp'},
                {title => 'Status', data => 'status'},
                {title => 'Results', data => 'results_page'},
                {title => 'Actions', data => 'actions'},
            ],
            order => [[3, 'asc']]
        };
    } else {
        $data = {
            data => [],
            columns => [
                {title => 'Name', data => 'name'},
                {title => 'Type', data => 'type'},
                {title => 'Start Time', data => 'create_timestamp'},
                {title => 'End Time', data => 'finish_timestamp'},
                {title => 'Status', data => 'status'},
                {title => 'Results', data => 'results_page'},
                {title => 'Actions', data => 'actions'},
            ],
            order => [[2, 'asc']]
        };
    }

    foreach my $job_id (@{$jobs}) {
        my $job = CXGN::Job->new({
            schema => $bcs_schema,
            people_schema => $people_schema,
            sp_job_id => $job_id
        });
        my $actions_html = "<span id=\"$job_id\" style=\"display: none;\"></span><button id=\"dismiss_job_$job_id\" onclick=\"jsMod['job'].dismiss_job($job_id);\" class=\"btn btn-small btn-danger\">Dismiss</button>";
        my $status = $job->check_status();
        my $results_page = "";
        # if ($status eq "finished" && $job->retrieve_argument('type') =~ /analysis/) {
        #     $actions_html .= "<button id=\"save_job_$job_id\" class=\"btn btn-small btn-success\">Save Results</button>";
        # } 
        if ($status eq "submitted") {
            $actions_html .= "<button id=\"cancel_job_$job_id\" onclick=\"jsMod['job'].cancel_job($job_id)\" class=\"btn btn-small btn-danger\">Cancel</button>";
            $results_page = "In progress";
        }
        if ($status eq "finished") {
            $results_page = $job->results_page();
            if ($results_page) {
                $results_page =~ s/http[s]*:\/\///;
                $results_page =~ s/localhost[:0-9]*//;
                $results_page = '<a href="'.$results_page.'">View</a>';
            } else {
                $results_page = '';
            }
        }
        my $create_timestamp = $job->create_timestamp() =~ s/(:\d{2}\+\d{2})$//r;
        my $finish_timestamp = $job->finish_timestamp() =~ s/(:\d{2}\+\d{2})$//r;
        my $row;
        if ($role eq "curator") {
            my $dbh = $bcs_schema->storage->dbh();
            my $owner = CXGN::People::Person->new(
                $dbh,
                $job->sp_person_id()
            );
            $row = {
                id => $job_id,
                user => $owner->get_first_name()." ".$owner->get_last_name(),
                name => $job->name(),
                type => $job->job_type(),
                status => $status,
                create_timestamp => $create_timestamp,
                finish_timestamp => $finish_timestamp,
                results_page => $results_page,
                actions => $actions_html
            };
        } else {
            $row = {
                id => $job_id,
                name => $job->name(),
                type => $job->job_type(),
                status => $status,
                create_timestamp => $create_timestamp,
                finish_timestamp => $finish_timestamp,
                results_page => $results_page,
                actions => $actions_html
            };
        }

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
        $c->stash->{rest} = {error => "You do not have permission to delete this job.\n"} ;
        return;
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
        $c->stash->{rest} = {error => "You do not have permission to cancel this job.\n"} ;
        return;
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
        $c->stash->{rest} = {error => "You do not have permission to delete these job logs.\n"} ;
        return;
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
        $c->stash->{rest} = {error => "You do not have permission to delete these job logs.\n"} ;
        return;
    }

    if ($older_than ne "one_week" &&  $older_than ne "one_month" && $older_than ne "six_months" && $older_than ne "one_year") {
        $c->stash->{rest} = {error => "Invalid time selection: $older_than.\n"} ;
        return;
    }

    CXGN::Job->delete_jobs_older_than(
        $bcs_schema,
        $people_schema,
        $sp_person_id,
        $older_than
    );
    $c->stash->{rest} = {success => 1};
}

sub delete_finished :Path('/ajax/job/delete_finished') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if ($sp_person_id ne $logged_user && $role ne "curator") {
        $c->stash->{rest} = {error => "You do not have permission to delete these job logs.\n"} ;
        return;
    }

    CXGN::Job->delete_finished_jobs(
        $bcs_schema,
        $people_schema,
        $sp_person_id
    );
    $c->stash->{rest} = {success => 1};
}

sub retrieve_user_in_progress_uploads :Path('/ajax/job/uploads_in_progress') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = shift;

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if ($sp_person_id ne $logged_user && $role ne "curator") {
        $c->stash->{rest} = {error => "You do not have permission to see these job logs.\n"} ;
        return;
    }

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $jobs;
    try {
        $jobs = CXGN::Job->get_user_in_progress_uploads(
            $bcs_schema,
            $people_schema,
            $sp_person_id,
            $role
        );
    } catch {
        print STDERR $_, "\n";
        $c->stash->{rest} = {error => "Error retrieving in-progress uploads: $_"};
        return;
    };

    $c->stash->{rest} = {data => $jobs};
    return;
    
}

sub retrieve_user_completed_uploads :Path('/ajax/job/completed_uploads') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = shift;

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if ($sp_person_id ne $logged_user && $role ne "curator") {
        $c->stash->{rest} = {error => "You do not have permission to see these job logs.\n"} ;
        return;
    }

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $jobs;
    try {
        $jobs = CXGN::Job->get_user_completed_uploads(
            $bcs_schema,
            $people_schema,
            $sp_person_id,
            $role
        );
    } catch {
        print STDERR $_, "\n";
        $c->stash->{rest} = {error => "Error retrieving in-progress uploads: $_"};
        return;
    };

    $c->stash->{rest} = {
        success => 1,
        data => $jobs
    };
    return;
}

sub delete_upload_jobs :Path('/ajax/job/dismiss_completed_uploads') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $logged_user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $role = $c->user() ? $c->user->get_object()->get_user_type() : undef;
    if ($sp_person_id ne $logged_user && $role ne "curator") {
        $c->stash->{rest} = {error => "You do not have permission to dismiss these finished uploads.\n"} ;
        return;
    }

    #TODO
}
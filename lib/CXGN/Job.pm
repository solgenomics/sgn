=head1 NAME

CXGN::Job - a class to unify background job submission, storage, and reporting

=head1 DESCRIPTION

CXGN::Job is a central location where background jobs can be submitted through cxgn-corelibs/CXGN::Tools::Run. 
By routing all jobs through this module, all submitted jobs regardless of type can be stored in sgn_people.sp_job 
and updated accordingly. To use this module, simply replace all calls to CXGN::Tools:Run with a call to this module,
supplying the Run arguments to the cxgn_tools_run_config hash. 

=head1 SYNOPSIS

my $job = CXGN::Job->new({
    people_schema => $people_schema
    schema => $bcs_schema
    args => {
        cxgn_tools_run_config => {$config},
        cmd => $cmd,
        type => 'download',
        submit_page => 'https://www.breedbase.org/submit_page_url'
        result_page => 'https://www.breedbase.org/result_page_url',
    }
});

my $job_id = $job->submit();

...

my $job = CXGN::Jobs->new({
    people_schema => $people_schema
    schema => $bcs_schema
    sp_job_id => $job_id
});

my $create_time = $job->create_timestamp();

my $current_status = $job->retrieve_status();

my $result_page = $job->result_page();

To create a job object representing an already submitted job, supply a job ID as sp_job_id. 
If constructing a new job to submit(), do not supply an sp_job_id. To specify 
instance variables as arguments, either supply them in the args hash with the appropriate
name or specify them using the class mutator methods (same as accessors). 

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut 

package CXGN::Jobs;

use Moose;
use Moose::Util::TypeConstraints;
use DateTime;
use Data::Dumper;
use JSON::Any;
use CXGN::Tools::Run;
use CXGN::People::Schema;

=head1 ACCESSORS

=head2 people_schema()

accessor for CXGN::People::Schema database object

=cut

has 'people_schema' => (isa => 'CXGN::People::Schema',  is => 'rw', required => 1 );

=head2 schema()

accessor for Bio::Chado::Schema database object

=cut

has 'schema' => ( isa => "Bio::Chado::Schema", is => 'rw', required => 1 );

=head2 sp_job_id()

Database ID for submitted job

=cut 

has 'sp_job_id' => ( isa => 'Int', is => 'rw', predicate => 'has_sp_job_id' );

=head2 sp_person_id()

User ID of the owner (submitter) of the job

=cut 

has 'sp_person_id' => ( isa => 'Int', is => 'rw' );

=head2 backend_id()

ID of the running process, as used by the workload manager (assumed to be Slurm). Useful for checking job status. 

=cut

has 'backend_id' => ( isa => 'Maybe[Int]', is => 'rw' );

=head2 create_timestamp()

Timestamp of job submission

=cut

has 'create_timestamp' => ( isa => 'Maybe[Str]', is => 'rw');

=head2 finish_timestamp()

Timestamp of job finishing, either successfully or on job failure

=cut

has 'finish_timestamp' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_finish_timestamp' );

=head2 status()

Current status of the job. May be stored in DB or may be gathered from Slurm (and then stored)

=cut 

has 'status' => ( isa => 'Maybe[Str]', is => 'rw');

=head2 submit_page()

The URL of the page from which this job was submitted

=cut

has 'submit_page' => (isa => 'Maybe[Str]', is => 'rw');

=head2 results_page()

The URL of the page for viewing results (if any)

=cut

has 'results_page' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_results_page');

=head2 type()

CVTerm describing what type of submitted job this is. Gathered using the CVTerm ID stored 
in the database row. Can be one of:
- download
- upload
- genotypic_analysis
- phenotypic_analysis
- genomic_prediction
- sequence_analysis
- tool_compatibility

=cut

has 'type' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_type' );

=head2 args()

Hashref of arguments supplied to the job. Not necessarily needed for job creation, but 
essential for job submission. Must have keys for cmd and cxgn_tools_run_config. All other keys
can be customized for the job type. Stored in the DB as a JSONB. This is the place to 
include config for CXGN::Tools::Run. As an argument to a new object, this will be 
ignored if an sp_job_id is also supplied. 

Ex:

my $job = CXGN::Jobs->new({
    people_schema => $ps,
    schema => $s,
    args => {
        cmd => 'perl /bin/script.pl -a arg1 -b arg2',
        cxgn_tools_run_config => {$config},
        type => 'download',
        submit_page => '...',
        results_page => '...'
    }
});

=cut

has 'args' => ( isa => 'Maybe[Hashref]', is => 'rw' );

=head1 INSTANCE METHODS

=cut

sub BUILD {
    my $self = shift;
    my $args = shift;

    my $bcs_schema = $args->{schema};
    my $people_schema = $args->{people_schema};

    if (!$self->has_sp_job_id()) { # New job, no ID yet
        my $job_args = $args->{args};
        $self->args($job_args);

        
    } else { #existing job, retrieve from DB
        $self->sp_job_id($args->{sp_job_id});
        my $row = $self->people_schema()->resultset("SpJob")->find({ sp_job_id => $self->sp_job_id() });
        if (!$row) { die "The job with id ".$self->sp_jb_id()." does not exist"; }
        my $job_args = JSON::Any->decode($row->args());
        $self->args($job_args);
        my $cvterm_row = $self->schema()->resultset("CV::Cvterm")->search({cvterm_id => $row->type_id()});
        $self->type($cvterm_row->name());
        $self->create_timestamp($row->create_timestamp());
        $self->finish_timestamp($row->finish_timestamp());
        $self->sp_person_id($row->sp_person_id());
        $self->backend_id($row->backend_id());
        $self->status($row->status());
        $self->submit_page($job_args->{submit_page});
        $self->results_page($job_args->{results_page});
    }
}

=head2 retrieve_status()

Returns the status of the job.

=cut

sub retrieve_status {
    my $self = shift;

    my $slurm_id = $self->slurm_id();

    if (!$slurm_id) {
        return "";
    } else {
        # ... determine status, check for end status vs curre
    }
}

=head2 retrieve_argument(arg) 

Returns the specified job argument stored in the args hashref. For example:

$job->retrieve_argument('cmd');

retrieves the command line code of the job. May return nothing for undefined arguments!

=cut

sub retrieve_argument {
    my $self = shift;
    my $arg_string = shift;

    my $args = $self->args();
    return $args->{$arg_string};
}

=head2 submit()

Creates a CXGN::Tools::Run object and runs the current job. Stores job data in a new db row.

=cut

sub submit {
    my $self = shift;

    #check for necessary parameters
    if (!$self->args->{cmd}) {
        die "Background jobs must have a command to run.\n";
    }
    my $cmd = $self->args->{cmd};
    if (!$self->args->{cxgn_tools_run_config}) {
        die "Must submit a cxgn_tools_run_config hash!\n";
    }

    my $job;
    my $create_time;
    my $backend_id;
    my $status;

    eval {
        $job = CXGN::Tools::Run->new($self->args->{cxgn_tools_run_config});
        $create_time = localtime();

        $job->run_cluster($cmd);

        $backend_id = $job->jobid();
        $status = 'Submitted';
    };

    $self->backend_id($backend_id);
    $self->status($status);
    $self->create_time($create_time)
    
    if ($@) {
        die "An error occured trying to submit a background job, sorry: $@\n";
    }


}

=head2 store()

Stores job data in a new db row.

=cut

sub store {
    my $self = shift;

}

=head1 CLASS METHODS

=head2 get_user_submitted_jobs(user_id)

Returns a listref of hashrefs containing the jobs submitted by the current user. 
All keys are named according to the value they denote. Arguments in the args hashref
are flattened. 

=cut

sub get_user_submitted_jobs {
    my $self = shift;
    my $sp_person_id = shift;
    my $bcs_schema = $self->schema;
    my $people_schema = $self->people_schema;


}
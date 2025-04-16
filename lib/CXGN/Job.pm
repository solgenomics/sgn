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
    schema => $bcs_schema,
    sp_person_id => $c->user->get_object()->get_sp_person_id(),
    cmd => $cmd,
    cxgn_tools_run_config => {
        'err_file' => $err_file,
        'out_file' => $out_file,
        'temp_base' => $temp_base, 
        'submit_host' => 'localhost',
        'queue' => 'batch',
        'max_cluster_jobs' => 1000000000,
        'is_cluster' => 1,
        'do_cleanup' => 0,
        'sleep' => undef,
        'backend' => 'Slurm'
    },
    finish_logfile => $c->config->{job_finish_log},
    name => 'Sample download',
    job_type => 'download',
    submit_page => 'https://www.breedbase.org/submit_page_url',
    results_page => 'https://www.breedbase.org/results_page_url',
    additional_args => {$more_stuff}
});

my $job_id = $job->submit();

...

my $job = CXGN::Jobs->new({
    people_schema => $people_schema
    schema => $bcs_schema
    sp_job_id => $job_id
});

my $create_time = $job->create_timestamp();

my $current_status = $job->check_status();

my $results_page = $job->results_page();

To create a job object representing an already submitted job, supply a job ID as sp_job_id. 
If constructing a new job to submit(), do not supply an sp_job_id. To specify 
instance variables as arguments, either supply them in the args hash with the appropriate
name or specify them using the class mutator methods (same as accessors). 

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut 

package CXGN::Job;

use Moose;
use Moose::Util::TypeConstraints;
use DateTime;
use DateTime::Format::ISO8601;
use Data::Dumper;
use File::Slurp qw( write_file read_file );
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

has 'sp_job_id' => ( isa => 'Maybe[Int]', is => 'rw', predicate => 'has_sp_job_id' );

=head2 sp_person_id()

User ID of the owner (submitter) of the job

=cut 

has 'sp_person_id' => ( isa => 'Int', is => 'rw' );

=head2 backend_id()

ID of the running process, as used by the workload manager (assumed to be Slurm). Useful for checking job status. 

=cut

has 'backend_id' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_backend_id');

=head2 create_timestamp()

Timestamp of job submission

=cut

has 'create_timestamp' => ( isa => 'Maybe[Str]', is => 'rw');

=head2 finish_timestamp()

Timestamp of job finishing, either successfully or on job failure

=cut

has 'finish_timestamp' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_finish_timestamp');

=head2 status()

Current status of the job. May be stored in DB or may be gathered from Slurm (and then stored)

=cut 

has 'status' => ( 
    isa => 'Maybe[Str]',
    isa => enum([qw( submitted finished failed timeout canceled )]), 
    is => 'rw'
);

=head2 submit_page()

The URL of the page from which this job was submitted

=cut

has 'submit_page' => (isa => 'Maybe[Str]', is => 'rw');

=head2 results_page()

The URL of the page for viewing results (if any)

=cut

has 'results_page' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_results_page');

=head2 job_type()

CVTerm describing what type of submitted job this is. Gathered using the CVTerm ID stored 
in the database row. Can be one of:
- download
- upload
- report
- genotypic_analysis
- phenotypic_analysis
- genomic_prediction
- sequence_analysis
- tool_compatibility

=cut

has 'job_type' => ( 
    isa => 'Maybe[Str]', 
    isa => enum([qw( download upload report tool_compatibility phenotypic_analysis genotypic_analysis sequence_analysis genomic_prediction )]),
    is => 'rw', 
    predicate => 'has_type'
);

=head2 type_id()

The cvterm_id stored in the database.

=cut

has 'type_id' => ( isa => 'Maybe[Int]', is => 'rw');

=head2 cxgn_tools_run_config()

The configuration options for CXGN::Tools::Run. Sensible defaults are used and accessed with $self->get_default_cxgn_tools_run_config().

Config keys include:

- err_file      err_file, out_file, and temp_base can be left blank for default temp directories
- out_file
- temp_base
- submit_host (probably localhost, but could be a different server)
- queue (batch by default)
- max_cluster_jobs 
- is_cluster (true by default)
- do_cleanup (0 by default)
- sleep (undef by default)
- backend (likely to be Slurm)

=cut

has 'cxgn_tools_run_config' => (isa => 'Maybe[HashRef]', is => 'rw', predicate => 'has_cxgn_tools_run_config');

=head2 cmd()

The command submitted to be run.

=cut

has 'cmd' => (isa => 'Str', is => 'rw');

=head2 logfile()

The logfile used to store and retrieve finish timestamps. Required for job creation. 

=cut

has 'finish_logfile' => (isa => 'Str', is => 'rw', predicate => 'has_finish_logfile');

=head2 name()

The name of the job.

=cut

has 'name' => (isa => 'Maybe[Str]', is => 'rw');

=head2 additional_args()

Hashref for additional arguments that may be tailored to a specific job. Not standardized in any way. 

=cut

has 'additional_args' => (isa => 'Maybe[HashRef]', is => 'rw');

=head1 INSTANCE METHODS

=cut

sub BUILD {
    my $self = shift;
    my $args = shift;

    my $bcs_schema = $args->{schema};
    my $people_schema = $args->{people_schema};

    if (!$self->has_sp_job_id()) { # New job, no ID yet.
        my $cvterm_row = $self->schema()->resultset("Cv::Cvterm")->find({name => $self->job_type()});
        $self->type_id($cvterm_row->cvterm_id());
        my $logfile;
        if (!$self->has_finish_logfile()) {
            $logfile = `cat /home/production/volume/cxgn/sgn/sgn.conf | grep job_finish_log | sed 's/\\w+\\s//'`;
            $self->finish_logfile($logfile);
        }
        $self->create_timestamp(DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M:%S'));
        if (!$self->has_cxgn_tools_run_config()) {
            $self->cxgn_tools_run_config($self->get_default_cxgn_tools_run_config());
        }
        
    } else { #existing job, retrieve from DB
        my $row = $self->people_schema()->resultset("SpJob")->find({ sp_job_id => $self->sp_job_id() });
        if (!$row) { die "The job with id ".$self->sp_job_id()." does not exist"; }
        my $job_args = $row->args() ? JSON::Any->decode($row->args()) : undef;
        $self->type_id($row->type_id());
        my $cvterm_row;
        if ($row->type_id()) {
            $cvterm_row = $self->schema()->resultset("Cv::Cvterm")->find({cvterm_id => $row->type_id()});
            $self->job_type($cvterm_row->name());
        }
        $self->create_timestamp($row->create_timestamp());
        $self->finish_timestamp($row->finish_timestamp());
        $self->sp_person_id($row->sp_person_id());
        $self->backend_id($row->backend_id());
        $self->status($row->status());
        $self->submit_page($job_args->{submit_page});
        $self->results_page($job_args->{results_page});
        $self->name($job_args->{name});
        $self->additional_args($job_args->{additional_args});
        $self->cxgn_tools_run_config($job_args->{cxgn_tools_run_config});
        $self->cmd($job_args->{cmd});
        my $logfile = $job_args->{finish_logfile} ? $job_args->{finish_logfile} : `cat /home/production/volume/cxgn/sgn/sgn.conf | grep job_finish_log | sed 's/\\w+\\s//'`;
        $self->finish_logfile($logfile);
    }
}

=head2 check_status()

Checks the status of the job and updates it (including finish_timestamp) as necessary. Returns current job status, or nothing if job is not yet submitted.

=cut

sub check_status {
    my $self = shift;

    my $backend_id = $self->backend_id();
    my $logfile = $self->finish_logfile();

    if ($self->status() eq "canceled") {
        return $self->status();
    }

    if (!$backend_id || !$self->has_sp_job_id()) {
        my $finish_timestamp = $self->read_finish_timestamp();
        if ($finish_timestamp && $self->status() ne "canceled") {
            $self->status("finished");
            $self->store();
        }
        return $self->status() ? $self->status() : "";
    } else {
        if ($self->status() eq "submitted") {
            my $squeue = `squeue --job=$backend_id`;
            my @job_results = split("\n", $squeue);
            if (scalar(@job_results) < 2) { #Squeue gives only header line if no job to show
                my $finish_timestamp = $self->read_finish_timestamp();

                if (!$finish_timestamp) {
                    $self->status("failed");
                    $self->store();
                } else {
                    $self->status("finished");
                    $self->store();
                }

            } else { #job is live 
                my ($JOBID,$PARTITION,$NAME,$USER,$ST,$TIME,$NODES,$NODELIST) = split(/\s+/, $job_results[1]);
                my @timestamp = split("-", $TIME);#squeue time outputs look like Days-Hours:Mins:Seconds, but days are ommitted for short lived jobs. 

                if (scalar(@timestamp) > 1) {#The length will be greater than one if the job has been running greater than 24 hours

                    if (int($timestamp[0]) >= 2) { #job is timed out!
                        $self->status("timed_out");
                        system("scancel $backend_id");
                        $self->store();
                    }
                }
            }
        } 
        return $self->status()
    }
}

=head2 read_finish_timestamp()

Returns the finish timestamp if already recorded. Otherwise, reads the logfile, stores the timestamp, and returns the time.

=cut

sub read_finish_timestamp {
    my $self = shift;
    my $logfile = $self->finish_logfile();

    if ($self->finish_timestamp()) {
        return $self->finish_timestamp();
    }

    if (!$logfile) {
        return "";
    }

    my @rows = read_file( $logfile, { binmode => ':utf8' } );

    my $db_id = $self->sp_job_id();
    my @finish_row = grep {/$db_id\s+/} @rows;
    my $finish_row = pop(@finish_row);

    $finish_row =~ m/$db_id\s+(?<FINISH_TIMESTAMP>\d+-\d+-\d+ \d+:\d+:\d+.*)/;

    if ($+{FINISH_TIMESTAMP}) {
        $self->finish_timestamp($+{FINISH_TIMESTAMP});
        $self->store();
        return $+{FINISH_TIMESTAMP};
    }

    return "";
}

=head2 delete()

Deletes the job from the database and the log finish file

=cut

sub delete {
    my $self = shift;

    if (!$self->has_sp_job_id()) {
        die "Deletion has no meaning for jobs that have not yet been stored.\n";
    } 

    my $logfile = $self->finish_logfile();

    my $row = $self->people_schema()->resultset("SpJob")->find({ sp_job_id => $self->sp_job_id() });

    if (!$row){
        die "The specified job does not exist in the database.\n";
    }

    eval {
        $row->delete();
    };
    if ($@) {
        die "An error occurred deleting job from database: $@\n";
    }
    my $job_id = $self->sp_job_id();
    my @rows = read_file( $logfile, { binmode => ':utf8' } );
    @rows = grep {!m/$job_id\s+\d+-\d+-\d+ \d+:\d+:\d+/} @rows;
    write_file($logfile,{binmode => ':utf8'},@rows);
}

=head2 cancel()

If the job is still alive and running, runs scancel to kill it. 

=cut

sub cancel {
    my $self = shift;

    if (!$self->has_backend_id()) {
        die "Cannot cancel a job without a backend ID.\n";
    }
    my $logfile = $self->finish_logfile();

    my $backend_id = $self->backend_id();

    eval {
        system("scancel $backend_id");

        $self->status('canceled');
        my $formatted_time = DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M:%S');
        $self->finish_timestamp($formatted_time);
        system('echo "'.$self->sp_job_id().'    '.$formatted_time.'" >> '.$logfile);
        $self->store();
    };
    if ($@){
        die "Error canceling job: $@\n";
    }
}

=head2 submit()

Creates a CXGN::Tools::Run object and runs the current job. Stores job data in a new db row. Returns sp_job_id

=cut

sub submit {
    my $self = shift;

    if ($self->has_sp_job_id()) {
        die "This job has already been submitted!\n";
    }

    if (!$self->cmd()) {
        die "Background jobs must have a command to run.\n";
    }

    my $logfile = $self->finish_logfile();
    my $cmd = $self->cmd();
    my $cxgn_tools_run_config;
    
    if (!$self->has_cxgn_tools_run_config()) {
        $cxgn_tools_run_config = $self->get_default_cxgn_tools_run_config();
    } else {
        $cxgn_tools_run_config = $self->cxgn_tools_run_config();
    }

    my $sp_job_id = $self->store();

    my $finish_timestamp_cmd = $self->generate_finish_timestamp_cmd();

    my $job;
    my $backend_id;
    my $status;

    eval {

        $job = CXGN::Tools::Run->new($cxgn_tools_run_config);
        print STDERR "Submitting job: \n$cmd\n";
        if ($self->cxgn_tools_run_config->{is_cluster} == 1){
            $job->run_cluster($cmd.$finish_timestamp_cmd);
        } else {
            $job->run_async($cmd.$finish_timestamp_cmd);
        }
        
        $backend_id = $job->cluster_job_id();
        $status = 'submitted';
    };

    if ($@) {
        $self->status('failed');
        $self->store();
        die "An error occured trying to submit a background job.\n$@\n";
    } 

    $self->backend_id($backend_id);
    $self->status($status);
    $self->store();

    return $sp_job_id;
}

=head2 store()

Stores job data in a new db row.

=cut

sub store {
    my $self = shift;
    eval {
        
        if ($self->has_sp_job_id()) {
            my $row = $self->people_schema()->resultset("SpJob")->find( { sp_job_id => $self->sp_job_id() });
            $row->backend_id($self->backend_id());
            $row->create_timestamp($self->create_timestamp() ? $self->create_timestamp() : DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M:%S'));
            $row->finish_timestamp($self->finish_timestamp());
            $row->args(JSON::Any->encode({
                cxgn_tools_run_config => $self->cxgn_tools_run_config(),
                name => $self->name(),
                finish_logfile => $self->finish_logfile(),
                cmd => $self->cmd(),
                results_page => $self->results_page(),
                submit_page => $self->submit_page(),
                additional_args => $self->additional_args(),
                job_type => $self->job_type()
            }));
            $row->sp_person_id($self->sp_person_id());
            $row->status($self->status());
            $row->type_id($self->type_id());
            $row->update();
        } else {
            my $cvterm_row = $self->schema->resultset('Cv::Cvterm')->find({ name => $self->job_type() });
            my $cvterm_id = $cvterm_row->cvterm_id();
            my $row = $self->people_schema()->resultset("SpJob")->create({
                backend_id => $self->backend_id(),
                args => JSON::Any->encode({
                    cxgn_tools_run_config => $self->cxgn_tools_run_config(),
                    name => $self->name(),
                    finish_logfile => $self->finish_logfile(),
                    cmd => $self->cmd(),
                    results_page => $self->results_page(),
                    submit_page => $self->submit_page(),
                    additional_args => $self->additional_args(),
                    job_type => $self->job_type()
                }),
                sp_person_id => $self->sp_person_id(),
                status => $self->status(),
                finish_timestamp => $self->finish_timestamp(),
                type_id => $cvterm_id,
                create_timestamp => DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M:%S')
            });
            $self->sp_job_id($row->sp_job_id());
        }
    };

    if ($@) {
        die "Error storing job in database!$@\n";
    } 
    
    return $self->sp_job_id();
}

=head2 generate_finish_timestamp_cmd();

Generates a command that gives the finish timestamp. Use to append to a cmd before submitting a job. 

=cut

sub generate_finish_timestamp_cmd {
    my $self = shift;

    my $logfile = $self->finish_logfile();

    if (!$self->has_sp_job_id()) {
        die "Can't generate a finish timestamp if job has no id.\n";
    } 

    my $sp_job_id = $self->sp_job_id();

    return ' ;

FINISH_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S%z"); 
echo "'.$sp_job_id.'    $FINISH_TIMESTAMP" >> '.$logfile.' ;

';
}

=head2 update_status($status)

Update the status of the job and store with the new value. 

=cut

sub update_status {
    my $self = shift;
    my $new_status = shift;

    $self->status($new_status);
    $self->store();
}

=head2 get_default_cxgn_tools_run_config()

Returns a hashref of the default config options for cxgn tools run. Used when no cxgn_tools_run_config found.

=cut

sub get_default_cxgn_tools_run_config {
    my $self = shift;

    my $cxgn_tools_run_config;
    my $user_id = $self->sp_person_id();
    my $name = $self->name() =~ s/ /_/gr;
    if (!$name) {
        $name = "job_".DateTime->now(time_zone => 'local')->strftime('%Y_%m_%d_%H_%M_%S');
    }
    my $temp_base = "/home/production/volume/tmp/user_$user_id/$name";
    my $err_file = "$temp_base/job.err";
    my $out_file = "$temp_base/job.out";
    $cxgn_tools_run_config = {
        #'err_file' => $err_file,
        'submit_host' => 'localhost',
        #'out_file' => $out_file,
        'temp_base' => $temp_base, 
        'queue' => 'batch',
        'max_cluster_jobs' => 1000000000,
        'is_cluster' => 1,
        'do_cleanup' => 0,
        'sleep' => undef,
        'backend' => 'Slurm'
    };

    return $cxgn_tools_run_config;
}

=head1 CLASS METHODS

=head2 get_user_submitted_jobs(bcs_schema, people_schema, user_id)

Returns a listref of sp_job_ids submitted by the given user id

=cut

sub get_user_submitted_jobs {
    my $class = shift;
    my $bcs_schema = shift;
    my $people_schema = shift;
    my $sp_person_id = shift;

    if (!$sp_person_id) {
        die "Need a user id\n";
    }

    my @user_jobs = ();

    my $rs = $people_schema->resultset("SpJob")->search( { sp_person_id => $sp_person_id });
    while (my $row = $rs->next()){
        push @user_jobs, $row->sp_job_id();
    }

    return \@user_jobs;
}

=head2 delete_dead_jobs(bcs_schema, people_schema, user_id)

Deletes dead jobs (failed or timed out) belonging to a user_id

=cut

sub delete_dead_jobs {
    my $class = shift;
    my $bcs_schema = shift;
    my $people_schema = shift;
    my $sp_person_id = shift;

    if (!$sp_person_id) {
        die "Need to supply a user id.\n";
    } 

    eval {
        my @job_ids;
        my $rs = $people_schema->resultset("SpJob")->search( { sp_person_id => $sp_person_id, status => { in => ['failed', 'timed_out'] } });
        while(my $row = $rs->next()) {
            push @job_ids, $row->sp_job_id();
        }
        foreach my $job_id (@job_ids){
            my $job = $class->new({
                people_schema => $people_schema,
                schema => $bcs_schema,
                sp_job_id => $job_id
            });
            $job->delete();
        }
    };

    if ($@) {
        die "Encountered an error trying to delete jobs: $@\n";
    }
} 

=head2 delete_jobs_older_than(bcs_schema, people_schema, user_id, time_limit)

Deletes jobs belonging to user_id older than the given time string.

=cut

sub delete_jobs_older_than {
    my $class = shift;
    my $bcs_schema = shift;
    my $people_schema = shift;
    my $sp_person_id = shift;
    my $time_limit = shift;

    if (!$sp_person_id || !$time_limit) {
        die "Need to supply a user id and a time interval.\n";
    } 

    my $timetable = {
        'one_week' => 7,
        'one_month' => 30,
        'six_months' => 180,
        'one_year' => 365
    };

    $time_limit = $timetable->{$time_limit};

    eval {
        my @job_ids;
        my $rs = $people_schema->resultset("SpJob")->search( { sp_person_id => $sp_person_id });
        while(my $row = $rs->next()) {
            my $create_timestamp = $row->create_timestamp();
            $create_timestamp =~ s/ /T/;
            my $start_time = DateTime::Format::ISO8601->parse_datetime($create_timestamp);
            my $now = DateTime->now();
            my $age = ( $now->epoch - $start_time->epoch ) / 86400;

            if ($age > $time_limit) {
                push @job_ids, $row->sp_job_id();
            }
        }
        foreach my $job_id (@job_ids) {
            my $job = $class->new({
                people_schema => $people_schema,
                schema => $bcs_schema,
                sp_job_id => $job_id
            });
            $job->delete();
        }
    };

    if ($@) {
        die "Encountered an error trying to delete jobs: $@\n";
    }
}

1;
package solGS::JobSubmission;

use Moose;
use namespace::autoclean;

use CXGN::Tools::Run;

use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;
use solGS::queryJobs;
use Bio::Chado::Schema;
use CXGN::People::Schema;
use CXGN::Job;
use DateTime;
use Try::Tiny;

with 'MooseX::Getopt';
with 'MooseX::Runnable';

has "prerequisite_jobs" => (
    is  => 'ro',
    isa => 'Str',
);

has "dependent_jobs" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has "analysis_report_job" => (
    is  => 'ro',
    isa => 'Str',
);

has "config_file" => (
    is  => 'ro',
    isa => 'Str',
);

has "analysis_start_timestamp" => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

has "job_records_by_slurm_id" => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

has "prepared_job_records" => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

has "analysis_job_records" => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
);



sub run {
    my $self = shift;
    my $secs = 30; #60 * 4;

    $self->analysis_start_timestamp(
        DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M:%S')
    );

    $self->prepare_analysis_job_records();

    my $analysis_error;
    try {
        my $pre_jobs = $self->run_prerequisite_jobs();
        sleep($secs);
        print STDERR
"\nCompleted prerequisite jobs. After waiting $secs sec...Now running the set of dependent jobs...\n";

        my $dep_jobs = $self->run_dependent_jobs();
        sleep($secs);
        print STDERR
"\nCompleted dependent jobs. After waiting $secs sec...Now checking results and emailing the results...\n";
    }
    catch {
        $analysis_error = $_;
        warn "Analysis job failed: $analysis_error";

        foreach my $job_record (@{$self->analysis_job_records}) {
            my $status = $job_record->status();
            if (!defined($status) || $status eq 'submitted') {
                $job_record->update_status('failed');
            }
        }
    };


    print STDERR "\nSubmitting the analysis report job...\n";
    $self->send_analysis_report();
    print STDERR "\nGot done submitting the analysis report job...\n";
    
    return 0;
}

sub connect_job_schemas {
    my ($self, $args) = @_;

    my $dsn =
        'dbi:Pg:database=' . $args->{dbname}
      . ';host=' . $args->{dbhost}
      . ';port=' . ($args->{dbport} || 5432);

    my $schema = Bio::Chado::Schema->connect(
        $dsn,
        $args->{dbuser},
        $args->{dbpass},
    );

    my $people_schema = CXGN::People::Schema->connect(
        $dsn,
        $args->{dbuser},
        $args->{dbpass},
        {
            on_connect_do => [
                'SET search_path TO sgn_people, public, sgn'
            ]
        },
    );

    return ($schema, $people_schema);
}


sub job_record_key {
    my ($self, $args) = @_;

    return join("\0", $args->{analysis_name} || '', $args->{cmd} || '');
}

sub prepare_analysis_job_records {
    my $self = shift;

    my $jobs_file = $self->dependent_jobs;
    return if !$jobs_file || !-s $jobs_file;

    my $dependent_jobs = retrieve($jobs_file);
    $dependent_jobs = [$dependent_jobs] if reftype($dependent_jobs) ne 'ARRAY';

    foreach my $args (@$dependent_jobs) {
        next if ref($args) ne 'HASH';

        my $job_records = $self->build_job_records($args);
        next if !@$job_records;

        foreach my $job_record (@$job_records) {
            $job_record->update_status('submitted');
            push @{$self->analysis_job_records}, $job_record;
        }

        my $key = $self->job_record_key($args);
        push @{$self->prepared_job_records->{$key}}, $job_records;
    }
}

sub record_job_submission {
    my ($self, $args) = @_;

    my $key = $self->job_record_key($args);
    my $prepared_records = $self->prepared_job_records->{$key};
    if ($prepared_records && @$prepared_records) {
        return shift @$prepared_records;
    }

    return $self->build_job_records($args);
}

sub build_job_records {
    my ($self, $args) = @_;

    if (!$args->{analysis_name}) {
        return [] ;
    }

    my $jobs_record_args = $args->{job_record_args} || [];
    if (!@$jobs_record_args) {
        return [];
    }

    my ($schema, $people_schema) = $self->connect_job_schemas($args);

    my @job_records;

    foreach my $job_record_args (@$jobs_record_args) {
        my $additional_args = $job_record_args->{additional_args} || {};
        my $job_type = $job_record_args->{job_type} || $additional_args->{analysis_type};

        if (!$job_type) {
            die "Cannot record a job without an analysis type.\n";
        }

        my $job_record = CXGN::Job->new({
            %$job_record_args,
            schema        => $schema,
            people_schema => $people_schema,
            job_type      => $job_type,
        });

        if ($self->analysis_start_timestamp) {
            $job_record->create_timestamp($self->analysis_start_timestamp);
        }

        push @job_records, $job_record;
    }

    return \@job_records;
}

sub run_prerequisite_jobs {
    my $self = shift;

    my $remaining_jobs;
    my $pre_jobs = $self->prerequisite_jobs;
    if ( $pre_jobs !~ /none/ ) {
        $pre_jobs = retrieve($pre_jobs);
        my $type = reftype $pre_jobs;

        if ( reftype $pre_jobs eq 'HASH' ) {

            my $submitted_priority_jobs;
            foreach my $rank ( sort keys %$pre_jobs ) {
                my $js = $pre_jobs->{$rank};

                $submitted_priority_jobs = $self->submit_jobs($js);
            }
            $remaining_jobs = $self->wait_till_jobs_end($submitted_priority_jobs);
        }
        else {
            if ( reftype($pre_jobs) eq 'SCALAR' ) {
                $pre_jobs = [$pre_jobs];
            }

            my $submitted_jobs = $self->submit_jobs($pre_jobs);

            $remaining_jobs = $self->wait_till_jobs_end($submitted_jobs);
	    if (defined $remaining_jobs) {
                print STDERR "\nremaining jobs: $remaining_jobs\n";
	    }
        }
    }

    return $remaining_jobs;

}

sub wait_till_jobs_end {
    my ( $self, $jobs, $sleep_time ) = @_;

    $sleep_time = 30 if !$sleep_time;
    while (@$jobs) {
        for my $i (reverse 0 .. $#$jobs) {
            if (!$jobs->[$i]->alive()) {
                $self->record_terminal_job_status($jobs->[$i]);
                splice(@$jobs, $i, 1);
            }
        }

        sleep $sleep_time if @$jobs;

    }

    my $remaining_jobs = $jobs ? $jobs->[0] : 0;
    return $remaining_jobs;
}

sub record_terminal_job_status {
    my ($self, $job) = @_;

    my $slurm_job_id = $job->cluster_job_id();
    my $job_records = $self->job_records_by_slurm_id->{$slurm_job_id} || [];

    if (!@$job_records) {
        return;
    }

    my ($job_status, $state) = $job_records->[0]->update_status_from_slurm();

    for my $index (1 .. $#$job_records) {
        $job_records->[$index]->update_status($job_status);
    }
    delete $self->job_records_by_slurm_id->{$slurm_job_id};

    if ($job_status eq 'submitted') {
        warn "Slurm job $slurm_job_id has no confirmed terminal state; "
          . "leaving its database status as submitted.\n";
    }
    elsif ($job_status ne 'finished') {
        my $reported_state = defined($state) ? $state : 'UNKNOWN';
        die "Slurm job $slurm_job_id ended with state $reported_state \n";
    }
}

sub submit_jobs {
    my ( $self, $jobs ) = @_;

    my @submitted_jobs;

    if ( $jobs->[0] ) {
        foreach my $job (@$jobs) {
            my $submitted_job = $self->submit_job($job);
            push @submitted_jobs, $submitted_job;
        }
    }

    return \@submitted_jobs;
}

sub run_dependent_jobs {
    my $self = shift;

    my $jobs_file = $self->dependent_jobs;
    my $dep_jobs  = retrieve($jobs_file);

    if ( reftype($dep_jobs) ne 'ARRAY' ) {
        $dep_jobs = [$dep_jobs];
    }

    my $submitted_jobs = $self->submit_jobs($dep_jobs);

    my $remaining_jobs = $self->wait_till_jobs_end($submitted_jobs);
    if (defined $remaining_jobs) {
        print STDERR "\nremaining jobs: $remaining_jobs\n";
    }
    return $remaining_jobs;

}

sub send_analysis_report {
    my $self = shift;

    my $report_file = $self->analysis_report_job;

    unless ( $report_file =~ /none/ ) {
        my $report_job = retrieve($report_file);
        my $job        = $self->submit_job($report_job);
        return $job;
    }

}

sub submit_job {
    my ( $self, $args ) = @_;

    my $job;
    my $job_records = [];

    print STDERR "submitting job... $args->{cmd}\n";

    try {
        if (!exists($args->{record_job}) || $args->{record_job}) {
            $job_records = $self->record_job_submission($args);
        }

        $job = CXGN::Tools::Run->new( $args->{config} );
        $job->do_not_cleanup(1);
        $job->is_cluster(1);

        $job->run_cluster('(' . $args->{cmd} . ')');

        my $slurm_job_id = $job->cluster_job_id();

        foreach my $job_record (@$job_records) {
            $job_record->backend_id($slurm_job_id);
            $job_record->update_status('submitted');
        }

        if (@$job_records) {
            $self->job_records_by_slurm_id->{$slurm_job_id} = $job_records;
        }

        if (!$args->{background_job}) {
            $job->wait();
            $self->record_terminal_job_status($job);
        }
    }
    catch {
        my $error = $_;

        foreach my $job_record (@$job_records) {
            if (!$job_record)  {
                next;
            }

            my $status = $job_record->status();
            my $status_options = qr/^(?:finished|failed|canceled|timed_out)$/;
            if (defined($status) && $status =~ $status_options) {
                next;
            }
        
            $job_record->update_status('failed');
            
        }

        die "An error occurred running job $args->{cmd}\n$error";
    };

    return $job;

}

__PACKAGE__->meta->make_immutable;

####
1;    #
####

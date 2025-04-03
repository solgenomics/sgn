package solGS::JobSubmission;

use Moose;
use namespace::autoclean;

use CXGN::Tools::Run;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;
use solGS::queryJobs;

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


sub run {
    my $self = shift;
    my $secs = 30; #60 * 4;

    my $pre_jobs = $self->run_prerequisite_jobs();
    sleep($secs);
    print STDERR
"\nCompleted prerequisite jobs. After waiting $secs sec...Now running the set of dependent jobs...\n";

    my $dep_jobs = $self->run_dependent_jobs();
    sleep($secs);
    print STDERR
"\nCompleted dependent jobs. After waiting $secs sec...Now checking results and emailing the results...\n";

    $self->send_analysis_report();
    print STDERR "\nGot done checking results and emailing the results...\n";

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
        for ( my $i = 0 ; $i < scalar(@$jobs) ; $i++ ) {
            splice( @$jobs, $i, 1 ) if !$jobs->[$i]->alive();
        }

        sleep $sleep_time;

    }

    my $remaining_jobs = $jobs ? $jobs->[0] : 0;
    return $remaining_jobs;
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
    ###my $config = $self->config_file;
    ###$config = retrieve($config);

    print STDERR "[SERVER] submitting job... $args->{cmd}\n";

    eval {
        $job = CXGN::Tools::Run->new( $args->{config} );
        $job->do_not_cleanup(1);

        $job->is_cluster(1);
        $job->run_cluster( $args->{cmd} );

        if ( !$args->{background_job} ) {
            print STDERR "\n WAITING job to finish\n";
            $job->wait();
            print STDERR "\n job COMPLETED\n";
        }
    };

    if ($@) {
        print STDERR "An error occurred submitting job $args->{cmd} \n$@\n";
    }

    return $job;

}

__PACKAGE__->meta->make_immutable;

####
1;    #
####

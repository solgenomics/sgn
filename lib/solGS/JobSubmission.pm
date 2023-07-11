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

    my $secs = 60 * 4;

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

    my @jobs;
    my $jobs = $self->prerequisite_jobs;
    if ( $jobs !~ /none/ ) {
        $jobs = retrieve($jobs);
        my $type = reftype $jobs;

        if ( reftype $jobs eq 'HASH' ) {
            my @priority_jobs;
            foreach my $rank ( sort keys %$jobs ) {
                my $js = $jobs->{$rank};
                foreach my $jb (@$js) {
                    my $sj = $self->submit_job($jb);
                    push @priority_jobs, $sj;
                }
            }


            while (@priority_jobs) {
                for ( my $i = 0 ; $i < scalar(@priority_jobs) ; $i++ ) {
                    splice( @priority_jobs, $i, 1 )
                      if !$priority_jobs[$i]->alive();
                }

                sleep 30;

            }
        }
        else {
            if ( reftype $jobs eq 'SCALAR' ) {
                $jobs = [$jobs];
            }

            if ( $jobs->[0] ) {
                foreach my $job (@$jobs) {
                    my $job = $self->submit_job($job);
                    push @jobs, $job;
                }
            }
        }

        while (@jobs) {
            for ( my $i = 0 ; $i < scalar(@jobs) ; $i++ ) {
                splice( @jobs, $i, 1 ) if !$jobs[$i]->alive();
            }

            sleep 30;

        }

    }

    return \@jobs;

}

sub run_dependent_jobs {
    my $self = shift;

    my @dep_jobs;
    my $jobs_file     = $self->dependent_jobs;
    my $dep_jobs_cmds = retrieve($jobs_file);

    if ( reftype $dep_jobs_cmds ne 'ARRAY' ) {
        $dep_jobs_cmds = [$dep_jobs_cmds];
    }

    foreach my $dep_job_cmd (@$dep_jobs_cmds) {
        my $dep_job = $self->submit_job($dep_job_cmd);
        push @dep_jobs, $dep_job;
    }

    while (@dep_jobs) {
        for ( my $i = 0 ; $i < scalar(@dep_jobs) ; $i++ ) {
            splice( @dep_jobs, $i, 1 ) if !$dep_jobs[$i]->alive();
        }

        sleep 30;

    }

    return \@dep_jobs;

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

    print STDERR "submitting job... $args->{cmd}\n";

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

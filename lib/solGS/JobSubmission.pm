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
    is       => 'ro',
    isa      =>  'Str',
    );

has "dependent_jobs" => (
    is       => 'ro',
    isa      =>  'Str',
    required  => 1,
    );

has "analysis_report_job" => (
    is       => 'ro',
    isa      => 'Str',
    );

has "config_file" => (
    is       => 'ro',
    isa      => 'Str',
    );



sub run {
    my $self = shift;

    my $pre_jobs = $self->run_prerequisite_jobs;
    my $dep_jobs = $self->run_dependent_jobs($pre_jobs);
    $self->send_analysis_report($dep_jobs);

}


sub run_prerequisite_jobs {
    my $self = shift;

    my @jobs;
    my $jobs = $self->prerequisite_jobs;
    if ($jobs !~ /none/)
    {
    	$jobs = retrieve($jobs);
        my $type = reftype $jobs;

    	if (reftype $jobs eq 'HASH')
    	{
    	    my @priority_jobs;
    	    foreach my $rank (sort keys %$jobs)
    	    {
        		my $js = $jobs->{$rank};
        		foreach my $jb (@$js)
        		{
        		    my $sj = $self->submit_job($jb);
        		    push @priority_jobs, $sj;
        		}
    	    }

    	    foreach my $priority_job (@priority_jobs)
    	    {
    		while (1)
    		{
    		    last if !$priority_job->alive();
    		    sleep 30 if $priority_job->alive();
    		}
    	    }
    	}
    	else
    	{
    	    if (reftype $jobs eq 'SCALAR' )
    	    {
    		    $jobs = [$jobs];
    	    }

            if ($jobs->[0])
            {
        	    foreach my $job (@$jobs)
        	    {
        		my $job = $self->submit_job($job);
        		push @jobs, $job;
        	    }
            }
    	}
    }

    return \@jobs;

}


sub run_dependent_jobs {
    my $self = shift;
    my $pre_jobs = shift;

    if ($pre_jobs->[0]) {
        foreach my $pre_job (@$pre_jobs)
        {
        	while (1)
        	{
        	    last if !$pre_job->alive();
        	    sleep 30 if $pre_job->alive();
        	}
        }
    }

    my @jobs;
    my $jobs_file = $self->dependent_jobs;
    my $jobs = retrieve($jobs_file);

    if (reftype $jobs ne 'ARRAY')
    {
	    $jobs = [$jobs];
    }

    foreach my $job (@$jobs)
    {
	   my $job = $self->submit_job($job);
	   push @jobs, $job;
    }

    return \@jobs;

}



sub send_analysis_report {
    my $self = shift;
    my $dep_jobs = shift;

    my @jobs;
    foreach my $dep_job (@$dep_jobs)
    {
	while (1)
	{
	    last if !$dep_job->alive();
	    sleep 30 if $dep_job->alive();
	}
    }

    my $report_file    = $self->analysis_report_job;
    unless ($report_file =~ /none/)
    {
	my $report_job = retrieve($report_file);
	my $job = $self->submit_job($report_job);
	return $job;
    }

}


sub submit_job {
     my ($self, $args) = @_;

     my $job;
     ###my $config = $self->config_file;
     ###$config = retrieve($config);

     print STDERR "submitting job... $args->{cmd}\n";

    eval
     {
     	$job = CXGN::Tools::Run->new($args->{config});
     	$job->do_not_cleanup(1);

	$job->is_cluster(1);
	$job->run_cluster($args->{cmd});


	if (!$args->{background_job})
	{
	    print STDERR "\n WAITING job to finish\n";
	    $job->wait();
	    print STDERR "\n job COMPLETED\n";
	}
     };

     if ($@)
     {
     	print STDERR "An error occurred submitting job $args->{cmd} \n$@\n";
     }

     return $job;

 }



__PACKAGE__->meta->make_immutable;




####
1; #
####

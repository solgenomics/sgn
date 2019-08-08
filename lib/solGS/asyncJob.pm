package solGS::asyncJob;


use Moose;
use namespace::autoclean;

use CXGN::Tools::Run;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;

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



sub run {
    my $self = shift;
   
    $self->run_jobs;
          
}


sub run_jobs {
    my $self = shift;

    my $jobs = [];
      
    my $prerequisite_jobs = $self->prerequisite_jobs;
	     
    if ($prerequisite_jobs !~ /none/)
    {
	$jobs =  $self->run_prerequisite_jobs;    	  
    }

    foreach my $job (@$jobs)
    {
	while (1) 
	{	  		  
	    last if !$job->alive();
	    sleep 30 if $job->alive();
	}
    }

    $jobs = $self->run_dependent_jobs;  
    $self->send_analysis_report($jobs);
    
}


sub run_prerequisite_jobs {
    my $self = shift;

    my $jobs_file = $self->prerequisite_jobs;
    my $jobs = retrieve($jobs_file);

    if (reftype $jobs ne 'ARRAY') 
    {
	$jobs = [$jobs];
    }
   
    my @jobs;
    foreach my $job (@$jobs) 
    {
	my $job = $self->submit_job($job);
	push @jobs, $job;
    }
    
    return \@jobs;
   
}


sub run_dependent_jobs {
    my $self = shift;
    
    my $jobs_file = $self->dependent_jobs;
    my $jobs = retrieve($jobs_file);
    
    if (reftype $jobs ne 'ARRAY') 
    {
	$jobs = [$jobs];
    }

    my @jobs;
    foreach my $job (@$jobs) 
    {
	my $job = $self->submit_job($job);
	push @jobs, $job;
    }
    
    return \@jobs;

}



sub send_analysis_report {
    my $self = shift;
    my $jobs = shift;
    
    if (reftype $jobs ne 'ARRAY') 
    {
	$jobs = [$jobs];
    }
    
    foreach my $job (@$jobs) 
    {
	while (1)
	{
	    last if !$job->alive();
	    sleep 30 if $job->alive();
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
    
    eval 
    {		
    	$job = CXGN::Tools::Run->new($args->{config});
    	$job->do_not_cleanup(1);
	 
    	$job->is_async(1);
	$job->run_cluster($args->{cmd});

	print STDERR "Submitted job... $args->{cmd}\n";	   
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

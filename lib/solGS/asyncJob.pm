package solGS::asyncJob;


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
    # 	    my $st = $self->check_job_status($job_id);
     #	    last if $st =~ /done/;
     #	    sleep if $st =~ /runnning/;
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
     print STDERR "\n sending analyis report\n";
     foreach my $job (@$jobs) 
     {
     	while (1)
     	{
    # 	    my $st = $self->check_job_status($job);
     #	    last if $st =~ /done/;
    # 	    sleep if $st =~ /runnning/;
	    
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


sub check_job_status {
    my ($self, $job_id) = @_;

    my $status = qx /squeue -j $job_id 2>&1/;
   
    
    my $check = 'slurm_load_jobs error: Invalid job id specified';

 print STDERR "\njob_id: $job_id - status: $status\n";   

    if ($status =~ /$check/) {
	return 'done';
    } else {
	return 'running';
    }
    
}


#sub submit_job {
 #   my ($self, $args) = @_;
#
 #   my $job_id;
  #  print STDERR "\nasync submit_job\n";
   # eval 
    #{		
#	my $job = qx /$args->{cmd}/;
 #   };
#
 #    print STDERR "\nasync submit_job: jobid - $job_id\n";
  #  if ($@) 
   # {
    #	print STDERR "An error occurred submitting job $args->{cmd} \n$@\n";
    #}

    #return $job_id;
    
#}

sub submit_job {
     my ($self, $args) = @_;

     my $job;
     my $config = $self->config_file;
     $config = retrieve($config);
    eval 
     {		
     	$job = CXGN::Tools::Run->new($args->{config});
     	$job->do_not_cleanup(1);
	if ($args->{background}) {
     	$job->is_async(1);
 	$job->run_cluster($args->{cmd});

 	print STDERR "Submitted job... $args->{cmd}\n";	   
	} else {
	    
	    
		print STDERR "\n submit_job_cluster sync job\n";
		#$job->is_async(0);
		$job->is_cluster(1);
		$job->run_cluster($args->{cmd});
		$job->wait();
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

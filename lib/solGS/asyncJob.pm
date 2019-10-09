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

    foreach my $job_id (@$jobs)
    {
	while (1) 
	{
	    my $st = $self->check_job_status($job_id);
	    last if $st =~ /done/;
	    sleep if $st =~ /runnning/;
	    #last if !$job->alive();	    
	    #sleep 30 if $job->alive();
	    
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
	my $job_id = $self->submit_job($job);
	push @jobs, $job_id;
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
	my $job_id = $self->submit_job($job);
	push @jobs, $job_id;
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
	    my $st = $self->check_job_status($job_id);
	    last if $st =~ /done/;
	    sleep if $st =~ /runnning/;
	    
	   # last if !$job->alive();
	   # sleep 30 if $job->alive();
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

    my $status= qx /squeue -j $job_id 2>&1/;
    #my $check = 'qstat: Unknown Job Id ' . $job_id;

 print STDERR "\njob_id: $job_id - status: $status\n";   

    if (!$status) {
	return 'done';
    } else {
	return 'running';
    }
    
}


sub submit_job {
    my ($self, $args) = @_;

    my $job_id;
    
    eval 
    {	# print STDERR "\n\nSubmitted job... $args->{cmd}\n\n";	
	my $cmd = $args->{cmd};
        # my $job = qx /$cmd 2>&1/;

	# ($job_id) = split(/\t/, $job); 

	# print STDERR "\n\nSubmitted job... $args->{cmd}\n\n";	
	# print STDERR "\n $job -- id: $job_id\n";

	if ($cmd =~ /Rscript/) {
	    print STDERR "\n\nSubmitted job... $cmd\n\n";	
	      #my $cmd = $args->{cmd};
	    my $job = qx /$cmd 2>&1/;

	    my ($job_id) = split(/\t/, $job); 

	    print STDERR "\n\nSubmitted job... $args->{cmd}\n\n";	
	    print STDERR "\n job: $job -- id: $job_id\n"; 
	  } else {
	      print STDERR "\n run: $cmd\n";
	      $cmd->run;
	      print STDERR "\n run job done\n";
	  }


	
    };

    if ($@) 
    {
    	print STDERR "An error occurred submitting job $args->{cmd} \n$@\n";
    }

    return $job_id;
    
}

# sub submit_job {
#     my ($self, $args) = @_;

#     my $job;
    
#     eval 
#     {		
#     	$job = CXGN::Tools::Run->new($args->{config});
#     	$job->do_not_cleanup(1);
	 
#     	$job->is_async(1);
# 	$job->run_cluster($args->{cmd});

# 	print STDERR "Submitted job... $args->{cmd}\n";	   
#     };

#     if ($@) 
#     {
#     	print STDERR "An error occurred submitting job $args->{cmd} \n$@\n";
#     }

#     return $job;
    
# }



__PACKAGE__->meta->make_immutable;




####
1; #
####

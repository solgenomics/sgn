package solGS::DependentJob;


use Moose;
use namespace::autoclean;

use CXGN::Tools::Run;
use File::Slurp qw /write_file read_file/;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use Try::Tiny;
use Storable qw/ nstore retrieve /;

use solGS::AnalysisReport;
use solGS::Cluster;
use Carp qw/ carp confess croak /;

use SGN::Controller::solGS::Files;


with 'MooseX::Getopt';
with 'MooseX::Runnable';


has "prerequisite_jobs" => (
    is       => 'ro',
    isa      =>  'Str',
    default  => 0,
    );

has "prerequisite_type" => (
    is       => 'ro',
    isa      =>  'Str',
    default  => 0,
    );

has "dependent_jobs" => (
    is       => 'ro',
    isa      =>  'Str',
    required  => 1,
    );

has "analysis_report_job" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "temp_dir" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );



sub run {
    my $self = shift;
    
    my $prerequisite_jobs  = $self->prerequisite_jobs;
    my $prerequisite_type  = $self->prerequisite_type;
    my $dependent_jobs     = $self->dependent_jobs;    
    my $temp_dir           = $self->temp_dir;
    my $report_file        = $self->analysis_report_job;
    
     
    print STDERR "\nrun prerequisite jobs: $prerequisite_jobs\n";
    print STDERR "\nrun prerequisite type: $prerequisite_type\n";
    print STDERR "\nrun report file: $report_file\n";
    print STDERR "\nrun dependent job : $dependent_jobs  \n";
        
    my $job_done = $self->run_job();
          
}


sub run_job {
    my $self = shift;

    my $job;
    
    eval
    {
	my $prerequisite_type = $self->prerequisite_type;
     
	if ($prerequisite_type =~ /combine_populations/)
	{
	    my $job = $self->run_combine_populations();

	    sleep 30;
	    while (1) 
	    {	 
		last if !$job->alive();
		sleep 30 if $job->alive();
	    }
	  
	    $job = $self->run_model();
	  
	}
	elsif ($prerequisite_type =~ /selection_pop_download_data/) 
	{      
	    $job =  $self->query_genotype_data();
	    
	    if ($job)
	    {	  
		print STDERR "\n querying data...\n";
		sleep 30;
		while (1)
		{
		    last if !$job->alive();
		    sleep 30 if $job->alive();
		    print STDERR "\n waiting for query job to complete..\n";
		}
	      
	      
	      
		#if ($self->r_script =~ /gs/)
		#{
		print STDERR "\nrunning model\n";
		$job = $self->run_model();
		
		#}
	    }
	    else
	    {
	      print STDERR "\nrunning model\n";
	      $job = $self->run_model();
	    }


	    if ($job)
	    {	  
		sleep 30;
		while (1)
		{
		    last if !$job->alive();
		    sleep 30 if $job->alive();
		    print STDERR "\n waiting for modeling job to complete..\n";
		}
	      
	      
		$self->send_analysis_report();
	    } 
	}
    };

  
    if ($@) {
	$self->send_analysis_report();
    }

    return $job;
    
}


sub run_combine_populations {
    my $self = shift;

    my $args_file = $self->combine_pops_args_file;
    my $args  = retrieve($args_file);
    my $cmd   = $args->{cmd};
    my $temp_template = $args->{temp_file_template};

    my $cluster_files = $self->create_cluster_accesible_tmp_files($temp_template);
    my $out_file      = $cluster_files->{out_file_temp};
    my $err_file      = $cluster_files->{err_file_temp};

    my $temp_dir      = $self->temp_dir;    
    my $config = $self->create_cluster_config($temp_dir, $out_file, $err_file);

    my $job;
    eval 
    {
	$job = CXGN::Tools::Run->new($config);
	$job->do_not_cleanup(1);	 
	$job->is_async(1);
	$job->run_cluster($cmd);
    };

    if ($@) {
	print STDERR "An error occurred! $@\n";
    }
  
    return $job;
}


sub query_genotype_data {
    my $self = shift;

    my $query_job_file = $self->prerequisite_jobs;
    my $query_job = retrieve($query_job_file);
   
    my $selection_pop_geno_file = $query_job->{args}->{selection_pop_geno_file};
    my $job;
   
    if (!-s $selection_pop_geno_file)
    {
	$job = $self->submit_job($query_job);
    }
    
    return $job;    
}


sub run_model {
    my $self = shift;
    
    my $model_job_file = $self->dependent_jobs;
    my $model_job = retrieve($model_job_file);
   
    my $job = $self->submit_job($model_job);
    
    return $job;

}



sub send_analysis_report {
    my $self = shift;

    my $report_file    = $self->analysis_report_job;
    my $report_job = retrieve($report_file);  

    my $job = $self->submit_job($report_job);

    return $job;

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
	   
    };

    if ($@) {
    	print STDERR "An error occurred submitting job $args->{cmd} \n$@\n";
    }

    return $job;
    
}



__PACKAGE__->meta->make_immutable;




####
1; #
####

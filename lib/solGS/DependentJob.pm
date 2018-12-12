package solGS::DependentJob;


use Moose;
use namespace::autoclean;

use CXGN::Tools::Run;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use Try::Tiny;
use Storable qw/ nstore retrieve /;
use solGS::AnalysisReport;
use Carp qw/ carp confess croak /;



with 'MooseX::Getopt';
with 'MooseX::Runnable';


has "dependency_jobs" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "dependency_type" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "dependent_type" => (
    is       => 'ro',
    isa      => 'Str',
    required  => 1,
    );

has "temp_file_template" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "analysis_report_args_file" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "temp_dir" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "r_script"   => (
     is       => 'ro',
     isa      => 'Str',
     required => 0, 
 );

has "script_args" => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 0, 
 );

has "gs_model_args_file" => (
    is       => 'ro',
    isa      => 'Str',
    required => 0, 
    );

has "job_config_file" => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    );


sub run {
    my $self = shift;
    
    my $dependency_jobs    = $self->dependency_jobs;
    my $dependent_job      = $self->r_script;
    my $temp_dir           = $self->temp_dir;
    my $temp_file_template = $self->temp_file_template;
    my $report_file        = $self->analysis_report_args_file;
    my $model_file         = $self->gs_model_args_file;
    my $job_type           = $self->dependent_type;
    my $dependency_type    = $self->dependency_type;
    my $args               = $self->script_args;
   
    print STDERR "\nrun dependency type: $dependency_type\n";
    print STDERR "\nrun tmpdir: $temp_dir -- template $temp_file_template\n";
    print STDERR "\nrun report file: $report_file\n";
    print STDERR "\nrun gs model file: $model_file\n";
    print STDERR "\nrun dependent job : $dependent_job -- pid: $$\n";
    print STDERR "\nrun job_type : $job_type\n";       
    print STDERR "\nrun r script args : $args->[0] -- $args->[1]\n";
    
    sleep 60;

    my $all_pre_jobs_done = $self->check_prerequisite_jobs();
    my $all_jobs_done;
     
    if ($all_pre_jobs_done)
    {
	unless ($job_type =~ /send_analysis_report/) 
	{ 
	    $all_jobs_done = $self->run_dependent_job();
	}
    }
   
    if ($all_jobs_done || $job_type =~ /send_analysis_report/) 
    {
	  $self->send_analysis_report();	  	  
    }
    
}


sub check_prerequisite_jobs {
    my $self = shift;
    
    my $prerequisite_jobs = $self->dependency_jobs;
  
    my @prerequisite_jobs;

    if ($prerequisite_jobs =~ /:/g) 
    {	
	@prerequisite_jobs = split(':', $prerequisite_jobs);	
    }
    else 
    {
	push @prerequisite_jobs, $prerequisite_jobs;
    }
   
    my $all_pre_jobs_done;
    sleep 10;

    my ($sec, $min, $start_hr) = localtime();
    my $job_type = $self->dependent_type;
   
    while (1) 
    {
	no warnings 'uninitialized';
	foreach my $prerequisite_job (@prerequisite_jobs) 
	{
	    my $job_stdout = qx /squeue --job=$prerequisite_job 2>&1/;
	    my $check = "squeue: error: Invalid job id: $prerequisite_job";
	 
	    if ($job_stdout =~ /^($check)/) 
	    {
		@prerequisite_jobs = grep {$_ ne $prerequisite_job} @prerequisite_jobs;
	    }
	}

	if (scalar(@prerequisite_jobs) == 0) 
	{
	    $all_pre_jobs_done = 1;
	    last;
	} 
	else
	{
	    my ($sec, $min, $now_hr) = localtime();
	    if ($now_hr == $start_hr + 4) 
	    { 
		last;
	    }
	    else
	    {
		sleep 60; 
	    }    
	}	
    }

    return $all_pre_jobs_done;
}


sub create_cluster_accesible_tmp_files {
    my ($self, $temp_file_template)  = @_;

    $temp_file_template = $self->temp_file_template if !$temp_file_template;
    my $working_dir     = $self->temp_dir;

    my ( $in_file_temp, $out_file_temp, $err_file_temp) =
        map 
    {
        my ( undef, $filename ) =
            tempfile(
                catfile(
                    $working_dir,
                    "${temp_file_template}-$_-XXXXXX",
                ),
            );
        $filename
    } 
    qw / in out err/;

    my $files = {
	'in_file_temp'  => $in_file_temp,
	'out_file_temp' => $out_file_temp,
	'err_file_temp' => $err_file_temp,
	};

    return $files;

}


sub run_dependent_job {
  my $self = shift;

  my $dependency_type = $self->dependency_type;
  my $job_type        = $self->dependent_type;
 
  my $combine_done;
  if ( $job_type =~ /combine_populations/) 
  { 
      my $combine_job = $self->combine_populations();

      sleep 30;
      while (1) 
      {	 
	  last if !$combine_job->alive();
	  sleep 30 if $combine_job->alive();
      }
     
      $combine_done = 1;
  }
 
  my $modeling_done;
  if ($combine_done || $dependency_type =~ /combine_populations/)
  {
      sleep 30;
      my $model_job = $self->run_model();
     
      while (1) 
      {	 
	  last if !$model_job->alive();
	  sleep 30 if $model_job->alive();
      } 
      
      $modeling_done = 1;          
  } 
  elsif ($dependency_type =~ /download_data/)
  {     
      if ($self->r_script =~ /gs/) {
      sleep 30;
      my $model_job = $self->run_model();
     
      while (1) 
      {	 
	  last if !$model_job->alive();
	  sleep 30 if $model_job->alive();
      } 
      
      $modeling_done = 1;  
      } else {
	  $self->send_analysis_report();	  
      }        
  } 
  else
  {
      print STDERR "\nNo depedent job provided. Exiting program.\n";
      exit();
  }
    
   return $modeling_done;

}


sub combine_populations {
    my $self = shift;
    
    my $temp_dir      = $self->temp_dir;     
    my $r_script      = $self->r_script;
    my $args          = $self->script_args;
    
    my $cluster_files = $self->create_cluster_accesible_tmp_files();
    my $out_file      = $cluster_files->{out_file_temp};
    my $err_file      = $cluster_files->{err_file_temp};

    my $config = $self->create_cluster_config($temp_dir, $out_file, $err_file);

    my $cmd = "Rscript --slave $r_script $out_file --args $args->[0] $args->[1]";

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


sub run_model {
    my $self = shift;

    my $temp_dir      = $self->temp_dir;
    my $gs_model_file = $self->gs_model_args_file;
    my $gs_args       = retrieve($gs_model_file);
 
    ## add checks for gs-args
    my $cluster_files = $self->create_cluster_accesible_tmp_files();
    my $out_file      = $cluster_files->{out_file_temp};
    my $err_file      = $cluster_files->{err_file_temp};
    
    my $config = $self->create_cluster_config($temp_dir, $out_file, $err_file);

    my $script_file  = $gs_args->{r_command_file};
    my $script_out   = $gs_args->{r_output_file};
    my $input_files  = $gs_args->{input_files};
    my $output_files = $gs_args->{output_files};
    
    my $cmd = "Rscript --slave  $script_file $script_out "
	. " --args $input_files $output_files";
					        
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


sub create_cluster_config {
    my ($self, $temp_dir, $out_file, $err_file) = @_;

    my $job_config_file = $self->job_config_file;
    my $job_config      = retrieve($job_config_file);
 
    my $config = {
	backend          => $job_config->{backend},
	temp_base        => $temp_dir,
	queue            => $job_config->{web_cluster_queue},
	max_cluster_jobs => 1_000_000_000,
	out_file         => $out_file,
	err_file         => $err_file,
	is_async         => 0,
	do_cleanup       => 0,
    };

    return $config;
}


sub check_analysis_status {
    my $self = shift;

    my $temp_dir       = $self->temp_dir;
    my $report_file    = $self->analysis_report_args_file;
    my $output_details = retrieve($report_file);   

    my $cluster_files = $self->create_cluster_accesible_tmp_files('analysis-status');
    my $out_file      = $cluster_files->{out_file_temp};
    my $err_file      = $cluster_files->{err_file_temp};
   
    #my $config = $self->create_cluster_config($temp_dir, $out_file, $err_file);

    my $cmd = "mx-run solGS::AnalysisReport --output_details_file $report_file";
    
    my $job; 
    eval 
    {
    	$job = CXGN::Tools::Run->new();
    	$job->do_not_cleanup(1);
	 
    	$job->is_async(1);
    	$job->run_async($cmd);
	   
    };

    if ($@) {
    	print STDERR "An error occurred! $@\n";
    }

    return $job;

}


sub send_analysis_report {
    my $self = shift;
   
    sleep 10;
    my $report_job = $self->check_analysis_status();
 
    while (1) 
    {	 
	last if !$report_job->alive();
	sleep 30 if $report_job->alive();
    } 
      
    return 1;
 
}   




__PACKAGE__->meta->make_immutable;




####
1; #
####

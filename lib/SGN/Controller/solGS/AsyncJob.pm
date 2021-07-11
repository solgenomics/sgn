package SGN::Controller::solGS::AsyncJob;

use Moose;
use namespace::autoclean;

use Storable qw/ nstore retrieve /;
use Carp qw/ carp confess croak /;
use File::Copy;
use File::Basename;
use CXGN::Tools::Run;

BEGIN {extends 'Catalyst::Controller'}


sub get_pheno_data_query_job_args_file {
    my ($self, $c, $trials) = @_;

    $self->get_cluster_phenotype_query_job_args($c, $trials);
    my $pheno_query_args = $c->stash->{cluster_phenotype_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $pheno_query_args_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'phenotype_data_query_args_file');

    nstore $pheno_query_args, $pheno_query_args_file
	or croak "pheno  data query job : $! serializing selection pop data query details to $pheno_query_args_file";

    $c->stash->{pheno_data_query_job_args_file} = $pheno_query_args_file;
}


sub get_geno_data_query_job_args_file {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->get_cluster_genotype_query_job_args($c, $trials, $protocol_id);
    my $geno_query_args = $c->stash->{cluster_genotype_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $geno_query_args_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'genotype_data_query_args_file');

    nstore $geno_query_args, $geno_query_args_file
	or croak "geno  data query job : $! serializing selection pop data query details to $geno_query_args_file";

    $c->stash->{geno_data_query_job_args_file} = $geno_query_args_file;
}


sub submit_cluster_phenotype_query {
    my ($self, $c, $trials) = @_;

    $self->get_pheno_data_query_job_args_file($c, $trials);
    $c->stash->{dependent_jobs} =  $c->stash->{pheno_data_query_job_args_file};
    $self->run_async($c);
}


sub submit_cluster_genotype_query {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->get_geno_data_query_job_args_file($c, $trials, $protocol_id);
    $c->stash->{dependent_jobs} =  $c->stash->{geno_data_query_job_args_file};
    $self->run_async($c);
}


sub submit_cluster_training_pop_data_query {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->get_training_pop_data_query_job_args_file($c, $trials, $protocol_id);
    $c->stash->{dependent_jobs} = $c->stash->{training_pop_data_query_job_args_file};
    $self->run_async($c);
}


sub training_pop_data_query_job_args {
    my ($self, $c, $trials, $protocol_id) = @_;

    my @queries;

    foreach my $trial (@$trials)
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $trial);

	if (!-s $c->stash->{phenotype_file_name})
	{
	    $self->get_cluster_phenotype_query_job_args($c, [$trial]);
	    my $pheno_query = $c->stash->{cluster_phenotype_query_job_args};
	    push @queries, @$pheno_query if $pheno_query;
	}

	$c->controller('solGS::Files')->genotype_file_name($c, $trial, $protocol_id);

	if (!-s $c->stash->{genotype_file_name})
	{
	    $self->get_cluster_genotype_query_job_args($c, [$trial], $protocol_id);
	    my $geno_query = $c->stash->{cluster_genotype_query_job_args};
	    push @queries, @$geno_query if $geno_query;
	}
    }


    $c->stash->{training_pop_data_query_job_args} = \@queries;
}


sub get_training_pop_data_query_job_args_file {
    my ($self, $c, $trials, $protocol_id) = @_;

    $self->training_pop_data_query_job_args($c, $trials, $protocol_id);
    my $training_query_args = $c->stash->{training_pop_data_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $training_query_args_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'training_pop_data_query_args');

    nstore $training_query_args, $training_query_args_file
	or croak "training pop data query job : $! serializing selection pop data query details to $training_query_args_file";

    $c->stash->{training_pop_data_query_job_args_file} = $training_query_args_file;
}


sub get_cluster_genotype_query_job_args {
    my ($self, $c, $trials, $protocol_id) = @_;

    my @queries;

    foreach my $trial_id (@$trials)
    {
	my $geno_file;
	if ($c->stash->{check_data_exists})
	{
	    $c->controller('solGS::Files')->first_stock_genotype_file($c, $trial_id, $protocol_id);
	    $geno_file = $c->stash->{first_stock_genotype_file};
	}
	else
	{
	    $c->controller('solGS::Files')->genotype_file_name($c, $trial_id, $protocol_id);
	    $geno_file = $c->stash->{genotype_file_name};
	}

	if (!-s $geno_file)
	{
	    my $args = $self->genotype_trial_query_args($c, $trial_id, $protocol_id);

	    $c->stash->{r_temp_file} = "genotype-data-query-${trial_id}";
	    $self->create_cluster_accessible_tmp_files($c);
	    my $out_temp_file = $c->stash->{out_file_temp};
	    my $err_temp_file = $c->stash->{err_file_temp};

	    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	    my $background_job = $c->stash->{background_job};

	    my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "geno-data-args_file-${trial_id}");

	    nstore $args, $args_file
		or croak "data queryscript: $! serializing model details to $args_file ";

	    my $check_data_exists =  $c->stash->{check_data_exists} ? 1 : 0;

	    my $cmd = 'mx-run solGS::queryJobs '
	    	. ' --data_type genotype '
	    	. ' --population_type trial '
	    	. ' --args_file ' . $args_file
		. ' --check_data_exists ' . $check_data_exists;

	    my $config_args = {
		'temp_dir' => $temp_dir,
		'out_file' => $out_temp_file,
		'err_file' => $err_temp_file,
		'cluster_host' => 'localhost'
	    };

	    my $config = $self->create_cluster_config($c, $config_args);

	    my $job_args = {
		'cmd' => $cmd,
		'config' => $config,
		'background_job'=> $background_job,
		'temp_dir' => $temp_dir,
	    };

	    push @queries, $job_args;
	}
    }

    $c->stash->{cluster_genotype_query_job_args} = \@queries;
}


sub get_cluster_phenotype_query_job_args {
    my ($self, $c, $trials) = @_;

    my @queries;
    
    $c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, $trials);
    $c->stash->{phenotype_files_list} = $c->stash->{multi_pops_pheno_files};

    foreach my $trial_id (@$trials)
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $trial_id);

	if (!-s $c->stash->{phenotype_file_name})
	{
	    my $args = $self->phenotype_trial_query_args($c, $trial_id);

	    $c->stash->{r_temp_file} = "phenotype-data-query-${trial_id}";
	    $self->create_cluster_accessible_tmp_files($c);
	    my $out_temp_file = $c->stash->{out_file_temp};
	    my $err_temp_file = $c->stash->{err_file_temp};

	    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	    my $background_job = $c->stash->{background_job};

	    my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "pheno-data-args_file-${trial_id}");

	    nstore $args, $args_file
		or croak "data query script: $! serializing phenotype data query details to $args_file ";

	    my $cmd = 'mx-run solGS::queryJobs '
	    	. ' --data_type phenotype '
	    	. ' --population_type trial '
	    	. ' --args_file ' . $args_file;


	    my $config_args = {
		'temp_dir' => $temp_dir,
		'out_file' => $out_temp_file,
		'err_file' => $err_temp_file,
		'cluster_host' => 'localhost'
	    };

	    my $config = $self->create_cluster_config($c, $config_args);

	    my $job_args = {
		'cmd' => $cmd,
		'config' => $config,
		'background_job'=> $background_job,
		'temp_dir' => $temp_dir,
	    };

	    push @queries, $job_args;
	}
    }

    $c->stash->{cluster_phenotype_query_job_args} = \@queries if @queries;

}


sub genotype_trial_query_args {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    my $geno_file;
    my $check_data_exists = $c->stash->{check_data_exists};

    if ($c->stash->{check_data_exists})
    {
	$c->controller('solGS::Files')->first_stock_genotype_file($c, $pop_id, $protocol_id);
	$geno_file = $c->stash->{first_stock_genotype_file};
    }
    else
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
	$geno_file = $c->stash->{genotype_file_name};
    }

    my $args = {
	'trial_id' => $pop_id,
	'genotype_file'       => $geno_file,
	'genotyping_protocol_id' => $protocol_id,
	'cache_dir'     => $c->stash->{solgs_cache_dir},
    };

    return $args;

}


sub phenotype_trial_query_args {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{pop_id} if !$pop_id;

    $c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
    my $pheno_file = $c->stash->{phenotype_file_name};

    $c->controller('solGS::Files')->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    no warnings 'uninitialized';

    $c->controller('solGS::Files')->traits_list_file($c);
    my $traits_file =  $c->stash->{traits_list_file};

    my $args = {
	'population_id'    => $pop_id,
	'phenotype_file'   => $pheno_file,
	'traits_list_file' => $traits_file,
	'metadata_file'    => $metadata_file,
    };

    return $args;
}


sub create_cluster_accessible_tmp_files {
    my ($self, $c, $template) = @_;

    my $temp_file_template = $template || $c->stash->{r_temp_file};

    my $temp_dir = $c->stash->{analysis_tempfiles_dir} || $c->stash->{solgs_tempfiles_dir};

    my $in_file  = $c->controller('solGS::Files')->create_tempfile($temp_dir, "${temp_file_template}-in");
    my $out_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "${temp_file_template}-out");
    my $err_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "${temp_file_template}-err");

    $c->stash(
	in_file_temp  => $in_file,
	out_file_temp => $out_file,
	err_file_temp => $err_file,
	);

}


sub run_async {
    my ($self, $c) = @_;

    my $prerequisite_jobs  = $c->stash->{prerequisite_jobs} || 'none';
    my $background_job     = $c->stash->{background_job};
    my $dependent_jobs     = $c->stash->{dependent_jobs};

    my $temp_dir            = $c->stash->{analysis_tempfiles_dir} || $c->stash->{solgs_tempfiles_dir};

    $c->stash->{r_temp_file} = 'run-async';
    $self->create_cluster_accessible_tmp_files($c);
    my $err_temp_file = $c->stash->{err_file_temp};
    my $out_temp_file = $c->stash->{out_file_temp};

    my $referer = $c->req->referer;

    my $report_file = 'none';

    if ($background_job)
    {
	$c->stash->{async} = 1;
	$c->controller('solGS::AnalysisQueue')->get_analysis_report_job_args_file($c, 2);
	$report_file = $c->stash->{analysis_report_job_args_file};
    }

    my $config_args = {
	'temp_dir' => $temp_dir,
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file,
	'cluster_host' => 'localhost'
    };

    my $job_config = $self->create_cluster_config($c, $config_args);
    my $job_config_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'job_config_file');

    nstore $job_config, $job_config_file
	or croak "job config file: $! serializing job config to $job_config_file ";

    my $cmd = 'mx-run solGS::JobSubmission'
	. ' --prerequisite_jobs '   . $prerequisite_jobs
	. ' --dependent_jobs '      . $dependent_jobs
    	. ' --analysis_report_job ' . $report_file
	. ' --config_file '         . $job_config_file;


    my $cluster_job_args = {
	'cmd' => $cmd,
	'config' => $job_config,
	'background_job'  => $background_job,
	'temp_dir'     => $temp_dir,
	'async'        => $c->stash->{async},
    };

    my $job = $self->submit_job_cluster($c, $cluster_job_args);

}


sub get_selection_pop_query_args {
    my ($self, $c) = @_;

    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $selection_pop_geno_file;
    my $pop_type;

    if ($selection_pop_id)
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $selection_pop_id, $protocol_id);
	$selection_pop_geno_file = $c->stash->{genotype_file_name};
    }

    my $genotypes_ids;
    if ($selection_pop_id =~ /list/)
    {
	$c->controller('solGS::List')->get_genotypes_list_details($c);
	$genotypes_ids = $c->stash->{genotypes_ids};
	$pop_type = 'list';
    }
    elsif ($selection_pop_id =~ /dataset/)
    {
	$pop_type = 'dataset';
    }
    else
    {
	$pop_type = 'trial';
    }

    $c->stash->{population_type} = $pop_type;
    my $temp_file_template = "genotype-data-query-${selection_pop_id}";
    $self->create_cluster_accessible_tmp_files($c, $temp_file_template);
    my $in_file   = $c->stash->{in_file_temp};
    my $out_temp_file  = $c->stash->{out_file_temp};
    my $err_temp_file  = $c->stash->{err_file_temp};

    my $selection_pop_query_args = {
	'trial_id' => $selection_pop_id,
	'genotype_file' => $selection_pop_geno_file,
	'genotypes_ids'  => $genotypes_ids,
	'dataset_id'    => $c->stash->{dataset_id},
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file,
	'population_type' => $pop_type,
	'genotyping_protocol_id' => $protocol_id
    };

    $c->stash->{selection_pop_query_args} = $selection_pop_query_args;

}


sub get_cluster_query_job_args {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{selection_pop_id};
    my $protocol_id =  $c->stash->{genotyping_protocol_id};

    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    my $geno_file = $c->stash->{genotype_file_name};

    my @queries;

    if (!-s $geno_file)
    {
	$c->stash->{r_temp_file} = "genotype-data-query-${pop_id}";
	$self->create_cluster_accessible_tmp_files($c);
	my $out_temp_file = $c->stash->{out_file_temp};
	my $err_temp_file = $c->stash->{err_file_temp};

	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	my $background_job = $c->stash->{background_job};

	$self->get_selection_pop_query_args($c);
	my $query_args = $c->stash->{selection_pop_query_args};
	my $genotype_file = $query_args->{genotype_file};
	my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "geno-data-args_file-${pop_id}");

	my $pop_type = $query_args->{population_type};
	my $data_type = 'genotype';

	nstore $query_args, $args_file
	    or croak "data query script: $! serializing model details to $args_file ";

	my $cmd = 'mx-run solGS::queryJobs '
	    . ' --data_type ' . $data_type
	    . ' --population_type ' . $pop_type
	    . ' --args_file ' . $args_file;

	my $config_args = {
	    'temp_dir' => $temp_dir,
	    'out_file' => $out_temp_file,
	    'err_file' => $err_temp_file,
	    'cluster_host' => 'localhost'
	};

	my $config = $self->create_cluster_config($c, $config_args);

	my $job_args = {
	    'cmd' => $cmd,
	    'config' => $config,
	    'background_job'=> $background_job,
	    'temp_dir' => $temp_dir,
	    'genotype_file' => $genotype_file
	};

	push @queries, $job_args;

    }

    $c->stash->{cluster_query_job_args} = \@queries;
}


sub get_selection_pop_query_args_file {
    my ($self, $c) = @_;

    $self->get_cluster_query_job_args($c);
    my $selection_pop_query_args = $c->stash->{cluster_query_job_args};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $selection_pop_query_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'selection_pop_query_args');

    nstore $selection_pop_query_args, $selection_pop_query_file
	or croak "selection pop query job : $! serializing selection pop data query details to $selection_pop_query_file";

    $c->stash->{selection_pop_query_args_file} = $selection_pop_query_file;
}


sub get_gs_modeling_jobs_args_file {
    my ($self, $c) = @_;

    my $modeling_jobs = [];

    if ($c->stash->{training_traits_ids})
    {
	$modeling_jobs =  $self->modeling_jobs($c);
    }

    if ($modeling_jobs)
    {
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
	my $model_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'gs_model_args');

	nstore $modeling_jobs, $model_file
	    or croak "gs r script: $! serializing model details to $model_file";

	$c->stash->{gs_modeling_jobs_args_file} = $model_file;
    }

}


sub get_cluster_r_job_args {
    my ($self, $c) = @_;

    my $r_script     = $c->stash->{r_script};
    my $input_files  = $c->stash->{input_files};
    my $output_files = $c->stash->{output_files};

    if ($r_script =~ /gs/)
    {
	$self->get_gs_r_temp_file($c);
    }

    $self->create_cluster_accessible_tmp_files($c);
    my $in_file   = $c->stash->{in_file_temp};
    my $out_temp_file  = $c->stash->{out_file_temp};
    my $err_temp_file  = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{analysis_tempfiles_dir} || $c->stash->{solgs_tempfiles_dir};

    {
        my $r_cmd_file = $c->path_to($r_script);
        copy($r_cmd_file, $in_file)
            or die "could not copy '$r_cmd_file' to '$in_file'";
    }

    my $config_args = {
	'temp_dir' => $temp_dir,
	'out_file' => $out_temp_file,
	'err_file' => $err_temp_file
    };

    my $config = $self->create_cluster_config($c, $config_args);

    my $cmd = 'Rscript --slave '
	. "$in_file $out_temp_file "
	. '--args ' .  $input_files
	. ' ' . $output_files;

    my $job_args = {
	'cmd' => $cmd,
	'background_job' => $c->stash->{background_job},
	'config' => $config,
    };

    $c->stash->{cluster_r_job_args} = $job_args;

}


sub create_cluster_config {
    my ($self, $c, $args) = @_;

    my $config = {
	temp_base        => $args->{temp_dir},
	queue            => $c->config->{'web_cluster_queue'},
	max_cluster_jobs => 1_000_000_000,
	out_file         => $args->{out_file},
	err_file         => $args->{err_file},
	is_async         => 0,
	do_cleanup       => 0,
	sleep            => $args->{sleep}
    };

    if ($args->{cluster_host} =~ /localhost/ || !$c->config->{cluster_host})
    {
	$config->{backend} = 'Slurm';
	$config->{submit_host} = 'localhost';
    }
    else
    {
	$config->{backend} = $c->config->{backend};
	$config->{submit_host} = $c->config->{cluster_host};
    }

    return $config;
}


sub submit_job_cluster {
    my ($self, $c, $args) = @_;

    my $job;

    eval
    {
	$job = CXGN::Tools::Run->new($args->{config});
	$job->do_not_cleanup(1);

	if ($args->{background_job})
	{
	    $job->is_async(1);
	    $job->run_async($args->{cmd});

	    $c->stash->{r_job_tempdir} = $job->job_tempdir();
	    $c->stash->{r_job_id}      = $job->jobid();
	    $c->stash->{cluster_job_id} = $job->cluster_job_id();
	    $c->stash->{cluster_job}   = $job;
	}
	else
	{
	    $job->run_async($args->{cmd});
	    $job->wait();
	}
    };

    if ($@)
    {
	$c->stash->{Error} =  'Error occured submitting the job ' . $@ . "\nJob: " . $args->{cmd};
	$c->stash->{status} = 'Error occured submitting the job ' . $@ . "\nJob: " . $args->{cmd};
    }

    return $job;

}


sub modeling_jobs {
    my ($self, $c) = @_;

    my $modeling_traits = $c->stash->{training_traits_ids} || [$c->stash->{trait_id}];
    my $training_pop_id = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};

    my @modeling_jobs;

    if ($modeling_traits) {

	foreach my $trait_id (@$modeling_traits)
	{
	    $c->stash->{trait_id} = $trait_id;
	    $c->controller('solGS::solGS')->get_trait_details($c);

	    $c->controller('solGS::solGS')->input_files($c);
	    $c->controller('solGS::solGS')->output_files($c);

	    my $selection_pop_gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
	    my $training_pop_gebvs_file = $c->stash->{rrblup_training_gebvs_file};

	    if (($training_pop_id && !-s $training_pop_gebvs_file) ||
		($selection_pop_id && !-s $selection_pop_gebvs_file))
	    {
		$self->get_gs_r_temp_file($c);
		$c->stash->{r_script} = 'R/solGS/gs.r';
		$self->get_cluster_r_job_args($c);

		push @modeling_jobs, $c->stash->{cluster_r_job_args};
	    }
	}
    }

    return \@modeling_jobs;
}


sub get_gs_r_temp_file {
    my ($self, $c) = @_;

    my $pop_id   = $c->stash->{training_pop_id};
    my $trait_id = $c->stash->{trait_id};

    my $data_set_type = $c->stash->{data_set_type};

    my $selection_pop_id = $c->stash->{selection_pop_id};
    $c->stash->{selection_pop_id} = $selection_pop_id;

    $pop_id = $c->stash->{combo_pops_id} if !$pop_id;
    my $identifier = $selection_pop_id ? $pop_id . '-' . $selection_pop_id : $pop_id;

    if ($data_set_type =~ /combined populations/)
    {
	my $combo_identifier = $c->stash->{combo_pops_id};
        $c->stash->{r_temp_file} = "gs-rrblup-combo-${identifier}-${trait_id}";
    }
    else
    {
       $c->stash->{r_temp_file} = "gs-rrblup-${identifier}-${trait_id}";
    }

}


sub run_r_script {
    my ($self, $c) = @_;

    if ($c->stash->{background_job})
    {
	$self->get_gs_modeling_jobs_args_file($c);
	$c->stash->{dependent_jobs} =  $c->stash->{gs_modeling_jobs_args_file};
	$self->run_async($c);
    }
    else
    {
	$self->get_cluster_r_job_args($c);
	my $cluster_job_args = $c->stash->{cluster_r_job_args};
	$self->submit_job_cluster($c, $cluster_job_args);
    }

}


sub submit_cluster_compare_trials_markers {
    my ($self, $c, $geno_files) = @_;

    $c->stash->{r_temp_file} = 'compare-trials-markers';
    $self->create_cluster_accessible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;

    try
    {
        my $compare_trials_job = CXGN::Tools::Run->run_cluster_perl({

            method        => ["SGN::Controller::solGS::Search" => "compare_genotyping_platforms"],
    	    args          => ['SGN::Context', $geno_files],
    	    load_packages => ['SGN::Controller::solGS::Search', 'SGN::Context'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },

         });

	$c->stash->{r_job_tempdir} = $compare_trials_job->tempdir();

	$c->stash->{r_job_id} = $compare_trials_job->job_id();
	$c->stash->{cluster_job} = $compare_trials_job;

	unless ($background_job)
	{
	    $compare_trials_job->wait();
	}

    }
    catch
    {
	$status = $_;
	$status =~ s/\n at .+//s;
    };

}


######
1;
#####

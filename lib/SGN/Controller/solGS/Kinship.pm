package SGN::Controller::solGS::Kinship;


use Moose;
use namespace::autoclean;

use JSON;
use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;
use File::Copy;
use File::Basename;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;


BEGIN { extends 'Catalyst::Controller' }


__PACKAGE__->config(
    default   => 'application/json' => 'JSON',
    map       => { 'application/json' => 'JSON'},
    );


sub kinship_analysis :Path('/kinship/analysis/') Args() {
    my ($self, $c) = @_;

    $c->stash->{template} = '/solgs/tools/kinship/analysis.mas';

}


sub kinship_run_analysis :Path('/kinship/run/analysis') Args() {
    my ($self, $c) = @_;

    my $pop_id        = $c->req->param('kinship_pop_id');
    my $protocol_id   = $c->req->param('genotyping_protocol_id'); ;
    my $trait_id      = $c->req->param('trait_id');
    my $combo_pops_id = $c->req->param('combo_pops_id');
    my $data_str      = $c->req->param('data_structure');
    my $pop_name      = $c->req->param('kinship_pop_name');

    $c->stash->{data_structure} = $data_str;

    $self->stash_data_str_kinship_pop_id($c, $pop_id, $data_str);
    my $kinship_pop_id = $c->stash->{kinship_pop_id};
    my $file_id = $c->controller('solGS::Files')->create_file_id($c);
    $c->stash->{file_id} = $file_id;

    my $list_id = $c->stash->{list_id};

    if ($list_id)
    {
	$c->controller('solGS::List')->create_list_population_metadata_file($c, $file_id);
	$c->controller('solGS::List')->stash_list_metadata($c, $list_id);
    }

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    if ($combo_pops_id)
    {
	$c->stash->{combo_pops_id} = $combo_pops_id;
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
	$c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
    }

    if ($trait_id)
    {
	$c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    }

    $self->run_kinship($c);

    my $res = {};

    if ($c->stash->{error})
    {
	$res->{result} = $c->stash->{error};
    }
    else
    {
	$res->{kinship_pop_name} = $pop_name;

	my $kinship_files = $self->get_kinship_coef_files($c, $kinship_pop_id, $protocol_id, $trait_id);
	#my $json_file;
	#if ($trait_id)
	#{
	  my  $json_file = $kinship_files->{json_file_adj};
#	}
#	else
#	{
#	  $json_file = $kinship_files->{json_file_raw};
#	}

	$res->{data} = read_file($json_file);
	$self->add_output_links($c, $res);
    }

    $res = to_json($res);
    $c->res->body($res);

}


sub kinship_result :Path('/solgs/kinship/result/') Args() {
    my ($self, $c) = @_;

    my $kinship_pop_id = $c->req->param('kinship_pop_id');
    my $protocol_id = $c->req->param('genotyping_protocol_id');
    my $trait_id = $c->req->param('trait_id');
    my $data_str = $c->req->param('data_structure');

    $self->stash_data_str_kinship_pop_id($c, $kinship_pop_id, $data_str);
    $kinship_pop_id = $c->stash->{kinship_pop_id};

    my $pop_name;
    if ($kinship_pop_id =~ /dataset/)
    {
	$pop_name = $c->controller('solGS::Dataset')->get_dataset_name($c, $c->stash->{dataset_id});
    }
    elsif ($kinship_pop_id =~ /list/)
    {
	$c->controller('solGS::List')->stash_list_metadata($c, $c->stash->{dataset_id});
	$pop_name = $c->stash->{list_name};
    }

    if ($trait_id)
    {
	$c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    }

    my $kinship_files = $self->get_kinship_coef_files($c, $kinship_pop_id, $protocol_id, $trait_id);
    my $json_file  = $kinship_files->{json_file_adj};

    my $res = {};

    if (-s $json_file)
    {
    	$res->{kinship_pop_name} = $pop_name;
    	$res->{data} = read_file($json_file);
    	$self->add_output_links($c, $res);
    }

    $res = to_json($res);
    $c->res->body($res);
}


sub stash_data_str_kinship_pop_id {
    my ($self, $c, $pop_id, $data_str) = @_;

    $pop_id = $c->stash->{kinship_pop_id} if !$pop_id;
    $data_str = $c->stash->{data_structure} if !$data_str;

    $pop_id =~ s/dataset_|list_//g;

    if ($data_str =~ /dataset/)
    {
	$c->stash->{dataset_id} = $pop_id;
    }
    elsif ($data_str =~ /list/)
    {
	$c->stash->{list_id} = $pop_id;
    }

    if ($data_str =~ /dataset|list/)
    {
	$pop_id = $data_str . '_' . $pop_id;
    }

    $c->stash->{kinship_pop_id} = $pop_id;
}


sub get_kinship_coef_files {
    my ($self, $c, $pop_id, $protocol_id, $trait_id) = @_;

    $c->stash->{pop_id} = $pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;

    if ($trait_id)
    {
    	$c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    }

    $c->controller('solGS::Files')->relationship_matrix_adjusted_file($c);
    my $json_file_adj = $c->stash->{relationship_matrix_adjusted_json_file};
    my $matrix_file_adj = $c->stash->{relationship_matrix_adjusted_table_file};

    $c->controller('solGS::Files')->relationship_matrix_file($c);
    my $matrix_file_raw = $c->stash->{relationship_matrix_table_file};
    my $json_file_raw = $c->stash->{relationship_matrix_json_file};

    return {'json_file_raw' => $json_file_raw,
	    'matrix_file_raw' => $matrix_file_raw,
	    'json_file_adj' => $json_file_adj,
	    'matrix_file_adj' => $matrix_file_adj,

    };
}


sub kinship_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{kinship_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $data_str = $c->stash->{data_structure};

    $c->stash->{pop_id} = $pop_id;
    $c->controller('solGS::Files')->inbreeding_coefficients_file($c);
    my $inbreeding_file = $c->stash->{inbreeding_coefficients_file};

    $c->controller('solGS::Files')->average_kinship_file($c);
    my $ave_kinship_file = $c->stash->{average_kinship_file};

    my $coef_files = $self->get_kinship_coef_files($c, $pop_id, $protocol_id);

    my $file_list = join ("\t",
                          $coef_files->{json_file_raw},
			  $coef_files->{matrix_file_raw},
			  $coef_files->{json_file_adj},
			  $coef_files->{matrix_file_adj},
			  $inbreeding_file,
			  $ave_kinship_file
	);

    my $tmp_dir = $c->stash->{kinship_temp_dir};
    my $name = "kinship_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, $file_list);

    $c->stash->{kinship_output_files} = $tempfile;

}


sub kinship_input_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{kinship_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $data_str = $c->stash->{data_structure};

    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);
    #my $geno_file = $c->stash->{genotype_file_name};

    	my $files = $c->stash->{genotype_files_list}
	|| $c->stash->{genotype_file}
	|| $c->stash->{genotype_file_name};


    my $tmp_dir = $c->stash->{kinship_temp_dir};
    my $name = "kinship_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, $files);

    $c->stash->{kinship_input_files} = $tempfile;


}


sub run_kinship {
    my ($self, $c) = @_;

    $self->kinship_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{kinship_query_jobs_file};

    $self->kinship_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{kinship_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub kinship_r_jobs_file {
    my ($self, $c) = @_;

    $self->kinship_r_jobs($c);
    my $jobs = $c->stash->{kinship_r_jobs};

    my $temp_dir = $c->stash->{kinship_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'kinship-r-jobs-file');

    nstore $jobs, $jobs_file
	or croak "kinship r jobs : $! serializing kinship r jobs to $jobs_file";

    $c->stash->{kinship_r_jobs_file} = $jobs_file;

}


sub kinship_r_jobs {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{kinship_pop_id};

    $self->kinship_output_files($c);
    my $output_file = $c->stash->{kinship_output_files};

    $self->kinship_input_files($c);
    my $input_file = $c->stash->{kinship_input_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{kinship_temp_dir};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "kinship-${file_id}";
    $c->stash->{r_script}     = 'R/solGS/kinship.r';

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{kinship_r_jobs} = $jobs;

}


sub kinship_query_jobs_file {
    my ($self, $c) = @_;

    $self->kinship_query_jobs($c);
    my $jobs = $c->stash->{kinship_query_jobs};

    my $temp_dir = $c->stash->{kinship_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'kinship-query-jobs-file');

    nstore $jobs, $jobs_file
	or croak "kinship query jobs : $! serializing kinship query jobs to $jobs_file";

    $c->stash->{kinship_query_jobs_file} = $jobs_file;

}


sub kinship_query_jobs {
    my ($self, $c) = @_;

    $self->create_kinship_genotype_data_query_jobs($c);
    my $jobs = $c->stash->{kinship_geno_query_jobs};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{kinship_query_jobs} = $jobs;
}


sub create_kinship_genotype_data_query_jobs {
    my ($self, $c) = @_;

    my $data_str = $c->stash->{data_structure};

    if ($data_str =~ /list/)
    {
	my $list_id = $c->stash->{list_id};
#	$c->controller('solGS::List')->stash_list_metadata($c);
    #my $list_type = $c->stash->{list_type};
	my $file_id = $c->controller('solGS::Files')->create_file_id($c);
	$c->stash->{file_id} = $file_id;

	$c->controller('solGS::List')->create_list_population_metadata_file($c, $file_id);
	$c->controller('solGS::List')->stash_list_metadata($c, $list_id);

	$c->controller('solGS::List')->create_list_geno_data_query_jobs($c);
	$c->stash->{kinship_geno_query_jobs} = $c->stash->{list_geno_data_query_jobs};
    }
    elsif ($data_str =~ /dataset/)
    {
	$c->controller('solGS::Dataset')->create_dataset_geno_data_query_jobs($c);
	$c->stash->{kinship_geno_query_jobs} = $c->stash->{dataset_geno_data_query_jobs};
    }
    else
    {
	if ($c->req->referer =~ /solgs\/selection\//)
	{
	    $c->stash->{pops_ids_list} = [$c->stash->{training_pop_id}, $c->stash->{selection_pop_id}];
	}

	my $trials = $c->stash->{pops_ids_list} || [$c->stash->{kinship_pop_id}];
	my $protocol_id = $c->stash->{genotyping_protocol_id};

	$c->controller('solGS::AsyncJob')->get_cluster_genotype_query_job_args($c, $trials, $protocol_id);
	$c->stash->{kinship_geno_query_jobs} = $c->stash->{cluster_genotype_query_job_args};
    }

}


sub add_output_links {
    my ($self, $c, $res) = @_;

    $self->prep_download_kinship_files($c);

    $res->{kinship_table_file} = $c->stash->{download_kinship_table};
    $res->{kinship_averages_file} = $c->stash->{download_kinship_averages};
    $res->{inbreeding_file} = $c->stash->{download_inbreeding};

}


sub prep_download_kinship_files {
  my ($self, $c) = @_;

  my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'kinship');
  my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);

  mkpath ([$base_tmp_dir], 0, 0755);

  $c->controller('solGS::Files')->relationship_matrix_adjusted_file($c);
  my $kinship_txt_file  = $c->stash->{relationship_matrix_adjusted_table_file};

  $c->controller('solGS::Files')->inbreeding_coefficients_file($c);
  my $inbreeding_file = $c->stash->{inbreeding_coefficients_file};

  $c->controller('solGS::Files')->average_kinship_file($c);
  my $ave_kinship_file = $c->stash->{average_kinship_file};

  $c->controller('solGS::Files')->copy_file($kinship_txt_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($inbreeding_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($ave_kinship_file, $base_tmp_dir);

  $kinship_txt_file = fileparse($kinship_txt_file);
  $kinship_txt_file = catfile($tmp_dir, $kinship_txt_file);

  $inbreeding_file = fileparse($inbreeding_file);
  $inbreeding_file = catfile($tmp_dir, $inbreeding_file);

  $ave_kinship_file = fileparse($ave_kinship_file);
  $ave_kinship_file = catfile($tmp_dir, $ave_kinship_file);

  $c->stash->{download_kinship_table} = $kinship_txt_file;
  $c->stash->{download_kinship_averages} = $ave_kinship_file;
  $c->stash->{download_inbreeding} = $inbreeding_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

#####
1;
#####

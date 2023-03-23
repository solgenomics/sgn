package SGN::Controller::solGS::Correlation;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use Cache::File;
use CXGN::Tools::Run;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use CXGN::Phenome::Population;
use JSON;
use Try::Tiny;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;


BEGIN { extends 'Catalyst::Controller' }


sub check_pheno_corr_result :Path('/phenotype/correlation/check/result/') Args() {
    my ($self, $c) = @_;

    my $corre_pop_id = $c->req->param('corre_pop_id');
    $c->stash->{corre_pop_id} = $corre_pop_id;

    $self->pheno_correlation_output_files($c);
    my $corre_output_file = $c->stash->{pheno_corr_json_file};

    my $ret->{result} = undef;

    if (-s $corre_output_file && $corre_pop_id =~ /\d+/)
    {
	$ret->{result} = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub correlation_phenotype_data :Path('/correlation/phenotype/data/') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $data_exists = $self->check_phenotype_data($c);

    unless ($data_exists)
    {
        $self->create_correlation_phenodata_file($c);
        $data_exists = $self->check_phenotype_data($c);
    }

    my $ret->{result} = undef;

    if ($data_exists)
    {
        $ret->{result} = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}

sub pheno_correlation_analysis_output :Path('/phenotypic/correlation/analysis/output') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    $self->pheno_correlation_output_files($c);
    my $corre_json_file = $c->stash->{pheno_corr_json_file};

    my $ret->{status} = 'Correlation analysis failed.';

    if (!-s $corre_json_file)
    {
	    $c->controller('solGS::Utils')->save_metadata($c);
        $self->run_pheno_correlation_analysis($c);
    }

    if (-s $corre_json_file)
    {
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file, {binmode => ':utf8'});
        $ret->{corre_table_file} = $self->download_pheno_correlation_file($c);
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub genetic_correlation_analysis_output :Path('/genetic/correlation/analysis/output') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $corre_pop_id = $c->stash->{corre_pop_id};
    my $pop_type = $c->stash->{pop_type};
    my $gebvs_file = $c->stash->{gebvs_file};

    $c->stash->{selection_pop_id} = $corre_pop_id if $pop_type =~ /selection/;
    $self->genetic_correlation_output_files($c);
    my $corre_json_file = $c->stash->{genetic_corr_json_file};

    if (!-s $corre_json_file)
    {
        $self->run_genetic_correlation_analysis($c);
    }

    my $ret->{status} = 'failed';
   
    if (-s $corre_json_file)
    {
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file, {binmode => ':utf8'});
        $ret->{corre_table_file} = $self->download_genetic_correlation_file($c);
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub download_phenotypic_correlation : Path('/download/phenotypic/correlation/population') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

	my $corre_table_file = $self->download_pheno_correlation_file($c);

	my $ret = {'corre_table_file' => $corre_table_file};
	$ret = to_json($ret);

	$c->res->content_type("text/plain");
	$c->res->body($ret);
}


sub correlation_genetic_data :Path('/correlation/genetic/data/') Args() {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $corre_pop_id = $c->stash->{corre_pop_id};
    my $pop_type = $c->stash->{pop_type};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $selection_index_file = $c->stash->{selection_index_file};
    $c->stash->{selection_pop_id} = $corre_pop_id if $pop_type =~ /selection/;

    $self->genetic_correlation_output_files($c);
    my $genetic_corr_file = $c->stash->{genetic_corr_json_file};
print STDERR "\ngenetic corr file: $genetic_corr_file\n";
    if (!-s $genetic_corr_file) 
    {
        $c->controller('solGS::Gebvs')->run_combine_traits_gebvs($c);
    }
    
    $c->controller('solGS::Gebvs')->combined_gebvs_file($c);
    my $combined_gebvs_file = $c->stash->{combined_gebvs_file};

    my $ret->{status} = undef;
    my $json = JSON->new();
    if ( -s $combined_gebvs_file )
    {
        my $args_hash = $json->decode($args);
        $args_hash->{gebvs_file} = $combined_gebvs_file;
        $args_hash->{selection_index_file} = $selection_index_file;
        $args_hash->{genotyping_protocol_id} = $protocol_id;
        $ret->{status} = 'success';
        $ret->{corre_args} = $json->encode($args_hash);
    }

    $ret = $json->encode($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}

sub check_phenotype_data {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    my $data_set_type = $c->stash->{data_set_type};

    my @pheno_files;

    my $referer = $c->req->referer;
    if ($referer =~ /qtl/)
    {
  	    my $phenotype_dir = $c->stash->{solqtl_cache_dir};
        my $phenotype_file   = 'phenodata_' . $pop_id;
        $phenotype_file   = $c->controller('solGS::Files')->grep_file($phenotype_dir, $phenotype_file);
        push @pheno_files, $phenotype_file;
    }
    else
    {
        if ($data_set_type =~ /combined/)
        {
            $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $pop_id);
            my $trials_ids = $c->stash->{combined_pops_list};

            $c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, $trials_ids);
            my $pheno_files = $c->stash->{multi_pops_pheno_files};
            @pheno_files = split(/\t/, $pheno_files);
       }
       else
       {
            $c->controller("solGS::Files")->phenotype_file_name($c, $pop_id);
            push @pheno_files, $c->stash->{phenotype_file_name};
        }
    }

    my $exists;
    foreach my $pheno_file (@pheno_files)
    {
        $exists = 1, if -s $pheno_file;
        last if !-s $pheno_file;
    }

    return $exists;

}

sub create_correlation_phenodata_file {
    my ($self, $c)  = @_;

    my $referer = $c->req->referer;

    my $phenotype_file;
    my $pop_id = $c->stash->{corre_pop_id};

    if ($referer =~ /qtl/)
    {
        my $pheno_exp = "phenodata_${pop_id}";
        my $dir       = $c->stash->{solqtl_cache_dir};

        $phenotype_file = $c->controller('solGS::Files')->grep_file($dir, $pheno_exp);

        unless ($phenotype_file)
	    {
            my $pop =  CXGN::Phenome::Population->new($c->dbc->dbh, $pop_id);
            $phenotype_file =  $pop->phenotype_file($c);
        }

    }
    else
    {
    	$self->corr_query_jobs_file($c);
    	my $queries =$c->stash->{corr_query_jobs_file};

    	$c->stash->{dependent_jobs} = $queries;
    	$c->controller('solGS::AsyncJob')->run_async($c);

    	$c->controller("solGS::Files")->phenotype_file_name($c, $pop_id);
    	$phenotype_file = $c->stash->{phenotype_file_name};
    }

    my $corre_cache_dir = $c->stash->{correlation_cache_dir};

    copy($phenotype_file, $corre_cache_dir)
	or die "could not copy $phenotype_file to $corre_cache_dir";

    my $file = basename($phenotype_file);
    $c->stash->{phenotype_file_name} = catfile($corre_cache_dir, $file);

}


sub pheno_correlation_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    my $corre_cache_dir = $c->stash->{correlation_cache_dir};

    my $table_cache_data = {key    => 'pheno_corr_table_' . $pop_id,
		      file      => "pheno_corr_table_${pop_id}" . '.txt',
		      stash_key => 'pheno_corr_table_file',
		      cache_dir => $corre_cache_dir
    };

    $c->controller('solGS::Files')->cache_file($c, $table_cache_data);

    my $json_cache_data = {key    => 'pheno_corr_json_' . $pop_id,
		      file      => "pheno_corr_json_${pop_id}" . '.txt',
		      stash_key => 'pheno_corr_json_file',
		      cache_dir => $corre_cache_dir
    };

   $c->controller('solGS::Files')->cache_file($c, $json_cache_data);

}


sub genetic_correlation_output_files {
    my ($self, $c) = @_;

    my $corre_pop_id = $c->stash->{corre_pop_id};
    my $pop_type         = $c->stash->{pop_type};
    my $traits_code = $c->stash->{training_traits_code};
    my $sindex_name = $c->stash->{sindex_name};

    my $model_id    = $c->stash->{training_pop_id};
    my $identifier;
    if ($sindex_name) 
    {
        $identifier  =  $sindex_name;
    }
    else 
    {
        $identifier  =  $pop_type =~ /selection/ ? "$model_id-${corre_pop_id}-${traits_code}" :  "${corre_pop_id}-${traits_code}";
    }

    my $corre_cache_dir = $c->stash->{correlation_cache_dir};

    my $table_cache_data = {key    => 'genetic_corr_table_' . $identifier,
		      file      => "genetic_corr_table_${identifier}",
		      stash_key => 'genetic_corr_table_file',
		      cache_dir => $corre_cache_dir
    };

    $c->controller('solGS::Files')->cache_file($c, $table_cache_data);

    my $json_cache_data = {key    => 'genetic_corr_json_' . $identifier,
		      file      => "genetic_corr_json_${identifier}",
		      stash_key => 'genetic_corr_json_file',
		      cache_dir => $corre_cache_dir
    };

   $c->controller('solGS::Files')->cache_file($c, $json_cache_data);


}


sub run_genetic_correlation_analysis {
    my ($self, $c) = @_;

    $self->temp_genetic_corr_input_file($c);
    $self->temp_genetic_corr_output_file($c);

    $c->stash->{corre_input_files}  = $c->stash->{temp_genetic_corr_input_file};
    $c->stash->{corre_output_files} = $c->stash->{temp_genetic_corr_output_file};

    $c->stash->{correlation_type} = "genetic-correlation";
    $c->stash->{correlation_script} = "R/solGS/genetic_correlation.r";

    $self->run_correlation_analysis($c);

}


sub download_pheno_correlation_file {
    my ($self, $c) = @_;

    $self->pheno_correlation_output_files($c);
    my $file = $c->stash->{pheno_corr_table_file};

    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'correlation');

    return $file;
}


sub download_genetic_correlation_file {
    my ($self, $c) = @_;

    $self->genetic_correlation_output_files($c);
    my $file = $c->stash->{genetic_corr_table_file};

    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'correlation');

    return $file;
}


sub temp_pheno_corr_output_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    $self->pheno_correlation_output_files($c);

    my $files = join ("\t",
			  $c->stash->{pheno_corr_table_file},
			  $c->stash->{pheno_corr_json_file},
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "pheno_corr_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);

    $c->stash->{temp_pheno_corr_output_file} = $tempfile;

}


sub temp_pheno_corr_input_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    my $data_set_type = $c->stash->{data_set_type};

    my $pheno_file;
    my $formatted_pheno_file;

    if ($data_set_type =~ /combined/)
    {
        $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $pop_id);
        my $trials_ids = $c->stash->{combined_pops_list};

        $c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, $trials_ids);
        $pheno_file = $c->stash->{multi_pops_pheno_files};
    }
    else
    {
        $c->controller("solGS::Files")->phenotype_file_name($c, $pop_id);
        $pheno_file = $c->stash->{phenotype_file_name};
    }

    $c->controller("solGS::Files")->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    my $files = join ("\t",
		      $pheno_file,
		      $metadata_file,
		      $c->req->referer,
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "pheno_corr_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);
    $c->stash->{temp_pheno_corr_input_file} = $tempfile;

}


sub temp_genetic_corr_output_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    $self->genetic_correlation_output_files($c);

    my $files = join ("\t",
			  $c->stash->{genetic_corr_table_file},
			  $c->stash->{genetic_corr_json_file},
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "genetic_corr_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);

    $c->stash->{temp_genetic_corr_output_file} = $tempfile;

}


sub temp_genetic_corr_input_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    my $gebvs_file = $c->stash->{gebvs_file};
    my $index_file = $c->stash->{selection_index_file};

    my $files = join ("\t",
		      $gebvs_file,
		      $index_file
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "genetic_corr_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);

    $c->stash->{temp_genetic_corr_input_file} = $tempfile;

}


sub run_pheno_correlation_analysis {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};

    $self->temp_pheno_corr_input_file($c);
    $self->temp_pheno_corr_output_file($c);

    $c->stash->{corre_input_files}  = $c->stash->{temp_pheno_corr_input_file};
    $c->stash->{corre_output_files} = $c->stash->{temp_pheno_corr_output_file};

    $c->stash->{correlation_type} = "pheno-correlation";
    $c->stash->{correlation_script} = "R/solGS/phenotypic_correlation.r";

    $self->run_correlation_analysis($c);


}


sub run_correlation_analysis {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    my $corre_type = $c->stash->{correlation_type};
    $self->corr_query_jobs_file($c);
    my $queries_file = $c->stash->{corr_query_jobs_file};

    $self->corr_r_jobs_file($c);
    my $r_jobs_file = $c->stash->{corr_r_jobs_file};
    $c->stash->{prerequisite_jobs} = $queries_file if $queries_file;
    $c->stash->{dependent_jobs} = $r_jobs_file;

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub corr_r_jobs {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corre_pop_id};
    my $input_file = $c->stash->{corre_input_files};
    my $output_file = $c->stash->{corre_output_files};
    my $corre_type = $c->stash->{correlation_type};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "${corre_type}-${pop_id}";
    $c->stash->{r_script}     = $c->stash->{correlation_script};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{correlation_temp_dir};

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{corr_r_jobs} = $jobs;

}


sub corr_r_jobs_file {
    my ($self, $c) = @_;

    $self->corr_r_jobs($c);
    my $jobs = $c->stash->{corr_r_jobs};

    my $temp_dir = $c->stash->{correlation_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'corre-r-jobs-file');

    nstore $jobs, $jobs_file
	or croak "correlation r jobs : $! serializing correlation r jobs to $jobs_file";

    $c->stash->{corr_r_jobs_file} = $jobs_file;

}

sub corr_query_jobs {
    my ($self, $c) = @_;

    my $corre_pop_id = $c->stash->{corre_pop_id};
    my $data_set_type = $c->stash->{data_set_type};
    my $trials_ids = [];

    if ($data_set_type =~ /combined/)
    {
        $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $corre_pop_id);
    	$trials_ids = $c->stash->{combined_pops_list};
    }
    else
    {
        $trials_ids =  [ $c->stash->{corre_pop_id}];
    }

    $c->controller('solGS::AsyncJob')->get_cluster_phenotype_query_job_args($c, $trials_ids);
    my $jobs = $c->stash->{cluster_phenotype_query_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	    $jobs = [$jobs];
    }

    $c->stash->{corr_query_jobs} = $jobs;

}


sub corr_query_jobs_file {
    my ($self, $c) = @_;

    $self->corr_query_jobs($c);
    my $jobs = $c->stash->{corr_query_jobs};

    my $corr_type = $c->stash->{correlation_type};
    my $jobs_file;

    if ($jobs->[0])
    {
    	my $temp_dir = $c->stash->{correlation_temp_dir};
    	$jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, "${corr_type}-query-jobs-file");

    	nstore $jobs, $jobs_file
    	    or croak "correlation pheno query jobs : $! serializing correlation ${corr_type} query jobs to $jobs_file";
    }

    $c->stash->{corr_query_jobs_file} = $jobs_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



####
1;
####

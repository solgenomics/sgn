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


sub check_pheno_corr_result :Path('/phenotype/correlation/check/result/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;
    $c->stash->{training_pop_id} = $pop_id;

    $self->pheno_correlation_output_files($c);
    my $corre_output_file = $c->stash->{corre_coefficients_json_file};

    my $ret->{result} = undef;

    if (-s $corre_output_file && $pop_id =~ /\d+/)
    {
	$ret->{result} = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub correlation_phenotype_data :Path('/correlation/phenotype/data/') Args(0) {
    my ($self, $c) = @_;

    my $pop_id = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{training_pop_id} = $pop_id;

    my $phenotype_file;
    my $referer = $c->req->referer;
    if ($referer =~ /qtl/)
    {
  	my $phenotype_dir = $c->stash->{solqtl_cache_dir};
        $phenotype_file   = 'phenodata_' . $pop_id;
        $phenotype_file   = $c->controller('solGS::Files')->grep_file($phenotype_dir, $phenotype_file);
    }
    else
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
	$phenotype_file = $c->stash->{phenotype_file_name};
    }

    unless (-s $phenotype_file)
    {
        $self->create_correlation_phenodata_file($c);
        $phenotype_file =  $c->stash->{phenotype_file_name};
    }

    my $ret->{result} = undef;

    if (-s $phenotype_file)
    {
        $ret->{result} = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub correlation_genetic_data :Path('/correlation/genetic/data/') Args(0) {
    my ($self, $c) = @_;

    my $corr_pop_id = $c->req->param('corr_population_id');
    my $pop_type    = $c->req->param('type');
    my $model_id    = $c->req->param('model_id');
    my @traits_ids  = $c->req->param('traits_ids[]');
    my $index_file  = $c->req->param('index_file');
    my $protocol_id  = $c->req->param('genotyping_protocol_id');
    my $training_traits_code  = $c->req->param('training_traits_code');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $c->stash->{selection_index_only_file} = $index_file;
    $c->stash->{model_id} = $model_id;
    $c->stash->{pop_id}   = $model_id;
    $c->stash->{training_pop_id} = $model_id;
    $c->stash->{training_traits_ids} = \@traits_ids;
    $c->stash->{training_traits_code} = $training_traits_code;

    $c->stash->{selection_pop_id} = $corr_pop_id if $pop_type =~ /selection/;

    #$c->controller('solGS::Files')->selection_index_file($c);

    # $c->controller('solGS::Gebvs')->combine_gebvs_of_traits($c);
    $c->controller('solGS::Gebvs')->run_combine_traits_gebvs($c);
    my $combined_gebvs_file = $c->stash->{combined_gebvs_file};

    print STDERR "\ncombined_gebvs_file: $combined_gebvs_file\n";
    my $tmp_dir = $c->stash->{correlation_temp_dir};
    $combined_gebvs_file = $c->controller('solGS::Files')->copy_file($combined_gebvs_file, $tmp_dir);

    my $ret->{status} = undef;

    if ( -s $combined_gebvs_file )
    {
        $ret->{status} = 'success';
        $ret->{gebvs_file} = $combined_gebvs_file;
	$ret->{index_file} = $index_file;
	$ret->{genotyping_protocol_id} = $protocol_id;

    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub trait_acronyms {
    my ($self, $c) = @_;

    $c->controller('solGS::solGS')->get_all_traits($c);
    my $acronyms = $c->controller('solGS::solGS')->get_acronym_pairs($c, $c->stash->{pop_id});
    return $acronyms;
}


sub create_correlation_phenodata_file {
    my ($self, $c)  = @_;

    my $referer = $c->req->referer;

    my $phenotype_file;
    my $pop_id = $c->stash->{pop_id};

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
	$self->corre_pheno_query_jobs_file($c);
	my $queries =$c->stash->{corre_pheno_query_jobs_file};

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


sub create_correlation_dir {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}


sub pheno_correlation_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    $self->create_correlation_dir($c);
    my $corre_cache_dir = $c->stash->{correlation_cache_dir};

    my $file_cache  = Cache::File->new(cache_root => $corre_cache_dir);
    $file_cache->purge();

    my $key_table = 'corre_coefficients_table_' . $pop_id;
    my $key_json  = 'corre_coefficients_json_' . $pop_id;
    my $corre_coefficients_file      = $file_cache->get($key_table);
    my $corre_coefficients_json_file = $file_cache->get($key_json);

    unless ($corre_coefficients_file && $corre_coefficients_json_file )
    {
        $corre_coefficients_file = catfile($corre_cache_dir, "corre_coefficients_table_${pop_id}");

        write_file($corre_coefficients_file, {binmode => ':utf8'});
        $file_cache->set($key_table, $corre_coefficients_file, '30 days');

        $corre_coefficients_json_file = catfile($corre_cache_dir, "corre_coefficients_json_${pop_id}");

        write_file($corre_coefficients_json_file, {binmode => ':utf8'});
        $file_cache->set($key_json, $corre_coefficients_json_file, '30 days');
    }

    $c->stash->{corre_coefficients_table_file} = $corre_coefficients_file;
    $c->stash->{corre_coefficients_json_file}  = $corre_coefficients_json_file;
}


sub genetic_correlation_output_files {
    my ($self, $c) = @_;

    my $corre_pop_id = $c->stash->{corre_pop_id};
    my $model_id     = $c->stash->{model_id};
    my $type         = $c->stash->{type};

    my $selection_pop_id = $c->stash->{selection_pop_id};

    $model_id    = $c->stash->{model_id};
    my $identifier  =  $type =~ /selection/ ? $model_id . "_" . $corre_pop_id :  $corre_pop_id;

    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};
    my $corre_json_file  = $c->controller('solGS::Files')->create_tempfile($tmp_dir, "genetic_corre_json_${identifier}");
    my $corre_table_file = $c->controller('solGS::Files')->create_tempfile($tmp_dir, "genetic_corre_table_${identifier}");

    $c->stash->{genetic_corre_table_file} = $corre_table_file;
    $c->stash->{genetic_corre_json_file}  = $corre_json_file;

}


sub pheno_correlation_analysis_output :Path('/phenotypic/correlation/analysis/output') Args(0) {
    my ($self, $c) = @_;

    my $pop_id = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{training_pop_id} = $pop_id;

    $self->pheno_correlation_output_files($c);
    my $corre_json_file = $c->stash->{corre_coefficients_json_file};

    my $ret->{status} = 'failed';

    if (!-s $corre_json_file)
    {
	$c->controller('solGS::Utils')->save_metadata($c);
        $self->run_pheno_correlation_analysis($c);
        $corre_json_file = $c->stash->{corre_coefficients_json_file};
    }

    if (-s $corre_json_file)
    {
	# $ret->{acronyms} =  $self->trait_acronyms($c);
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file, {binmode => ':utf8'});
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub genetic_correlation_analysis_output :Path('/genetic/correlation/analysis/output') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{corre_pop_id} = $c->req->param('corr_population_id');
    $c->stash->{model_id}     = $c->req->param('model_id');
    $c->stash->{type}         = $c->req->param('type');

    my $corr_pop_id = $c->req->param('corr_population_id');
    my $model_id    = $c->req->param('model_id');
    my $type        = $c->req->param('type');

    my $gebvs_file = $c->req->param('gebvs_file');
    my $index_file = $c->req->param('index_file');

    my $protocol_id  = $c->req->param('genotyping_protocol_id');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $c->stash->{data_input_file} = $gebvs_file;

    $c->stash->{selection_index_file} = $index_file;
    $c->stash->{gebvs_file} = $gebvs_file;

    $c->stash->{pop_id} = $corr_pop_id;

    if (-s $gebvs_file)
    {
        $self->run_genetic_correlation_analysis($c);
    }

    my $ret->{status} = 'failed';
    my $corre_json_file = $c->stash->{genetic_corre_json_file};

    if (-s $corre_json_file)
    {
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file, {binmode => ':utf8'});
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub run_genetic_correlation_analysis {
    my ($self, $c) = @_;

    $self->temp_geno_corre_input_file($c);
    $self->temp_geno_corre_output_file($c);

    $c->stash->{corre_input_files}  = $c->stash->{temp_geno_corre_input_file};
    $c->stash->{corre_output_files} = $c->stash->{temp_geno_corre_output_file};

    $c->stash->{correlation_type} = "genetic-correlation";
    $c->stash->{correlation_script} = "R/solGS/genetic_correlation.r";

    $self->run_correlation_analysis($c);

}


sub download_phenotypic_correlation : Path('/download/phenotypic/correlation/population') Args(1) {
    my ($self, $c, $id) = @_;

    $self->create_correlation_dir($c);
    my $corr_dir = $c->stash->{correlation_cache_dir};
    my $corr_file = catfile($corr_dir,  "corre_coefficients_table_${id}");

    unless (!-e $corr_file || -s $corr_file <= 1)
    {
	my @corr_data;
	my $count=1;

	foreach my $row ( read_file($corr_file, {binmode => ':utf8'}) )
	{
	    if ($count==1) {  $row = 'Traits,' . $row;}
	    $row =~ s/NA//g;
	    $row = join(",", split(/\s/, $row));
	    $row .= "\n";

	    push @corr_data, [ $row ];
	    $count++;
	}

	$c->res->content_type("text/plain");
	$c->res->body(join "",  map{ $_->[0] } @corr_data);
    }
}


sub temp_pheno_corre_output_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    $self->pheno_correlation_output_files($c);

    my $files = join ("\t",
			  $c->stash->{corre_coefficients_table_file},
			  $c->stash->{corre_coefficients_json_file},
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "pheno_corre_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);

    $c->stash->{temp_pheno_corre_output_file} = $tempfile;

}


sub temp_pheno_corre_input_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    $c->controller("solGS::Files")->phenotype_file_name($c, $pop_id);
    #$self->create_correlation_phenodata_file($c);

    my $pheno_file = $c->stash->{phenotype_file_name};

    $c->controller("solGS::Files")->formatted_phenotype_file($c);
    my $formatted_pheno_file = $c->stash->{formatted_phenotype_file};

    $c->controller("solGS::Files")->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    my $files = join ("\t",
		      $pheno_file,
		      $formatted_pheno_file,
		      $metadata_file,
		      $c->req->referer,
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "pheno_corre_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);
    $c->stash->{temp_pheno_corre_input_file} = $tempfile;

}


sub temp_geno_corre_output_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    $self->genetic_correlation_output_files($c);

    my $files = join ("\t",
			  $c->stash->{genetic_corre_table_file},
			  $c->stash->{genetic_corre_json_file},
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "geno_corre_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);

    $c->stash->{temp_geno_corre_output_file} = $tempfile;

}


sub temp_geno_corre_input_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    my $gebvs_file = $c->stash->{gebvs_file}; #$c->stash->{data_input_file};
    my $index_file = $c->stash->{selection_index_file};

    my $files = join ("\t",
		      $gebvs_file,
		      $index_file
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "geno_corre_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $files);

    $c->stash->{temp_geno_corre_input_file} = $tempfile;

}


sub run_pheno_correlation_analysis {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    $self->temp_pheno_corre_input_file($c);
    $self->temp_pheno_corre_output_file($c);

    $c->stash->{corre_input_files}  = $c->stash->{temp_pheno_corre_input_file};
    $c->stash->{corre_output_files} = $c->stash->{temp_pheno_corre_output_file};

    #$self->trait_acronyms($c);

    $c->stash->{correlation_type} = "pheno-correlation";
    $c->stash->{correlation_script} = "R/solGS/phenotypic_correlation.r";

    $self->run_correlation_analysis($c);


}


sub run_correlation_analysis {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $corre_type = $c->stash->{correlation_type};
    $self->corre_pheno_query_jobs_file($c);
    my $queries_file = $c->stash->{corre_pheno_query_jobs_file};

    $self->corre_pheno_r_jobs_file($c);
    my $r_jobs_file = $c->stash->{corre_pheno_r_jobs_file};
    $c->stash->{prerequisite_jobs} = $queries_file if $queries_file;
    $c->stash->{dependent_jobs} = $r_jobs_file;

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub corre_pheno_r_jobs {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{trial_id} || $c->stash->{pop_id};

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

    $c->stash->{corre_pheno_r_jobs} = $jobs;

}


sub corre_pheno_r_jobs_file {
    my ($self, $c) = @_;

    $self->corre_pheno_r_jobs($c);
    my $jobs = $c->stash->{corre_pheno_r_jobs};

    my $temp_dir = $c->stash->{correlation_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'corre-r-jobs-file');

    nstore $jobs, $jobs_file
	or croak "correlation r jobs : $! serializing correlation r jobs to $jobs_file";

    $c->stash->{corre_pheno_r_jobs_file} = $jobs_file;

}

sub corre_pheno_query_jobs {
    my ($self, $c) = @_;


    my $trial_id = $c->stash->{pop_id} || $c->stash->{trial_id};
    $c->controller('solGS::AsyncJob')->get_cluster_phenotype_query_job_args($c, [$trial_id]);
    my $jobs = $c->stash->{cluster_phenotype_query_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{corre_pheno_query_jobs} = $jobs;

}


sub corre_pheno_query_jobs_file {
    my ($self, $c) = @_;

    $self->corre_pheno_query_jobs($c);
    my $jobs = $c->stash->{corre_pheno_query_jobs};

    my $jobs_file;

    if ($jobs->[0])
    {
	my $temp_dir = $c->stash->{correlation_temp_dir};
	$jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'pheno-corre-query-jobs-file');

	nstore $jobs, $jobs_file
	    or croak "correlation pheno query jobs : $! serializing correlation phenoquery jobs to $jobs_file";
    }

    $c->stash->{corre_pheno_query_jobs_file} = $jobs_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



####
1;
####

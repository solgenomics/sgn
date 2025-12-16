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

sub cluster_analysis : Path('/correlation/analysis/') Args() {
    my ( $self, $c, $id ) = @_;

    if ( $id && !$c->user ) {
        $c->controller('solGS::Utils')->require_login($c);
    }

    $c->stash->{template} = '/solgs/tools/correlation/analysis.mas';

}


sub pheno_correlation_analysis :Path('/phenotypic/correlation/analysis') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);
    
    $self->cache_pheno_corr_output_files($c);
    my $corre_json_file = $c->stash->{pheno_corr_json_file};

    my $ret->{status} = 'Correlation analysis failed.';

    if (!-s $corre_json_file) {
	    $c->controller('solGS::Utils')->save_metadata($c);
        $self->run_correlation_analysis($c);
    }
    
    if (-s $corre_json_file) {
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file, {binmode => ':utf8'});
        $ret->{corre_table_file} = $self->download_pheno_correlation_file($c);
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub genetic_correlation_analysis :Path('/genetic/correlation/analysis') Args() {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $corr_pop_id = $c->stash->{corr_pop_id};
    my $pop_type = $c->stash->{pop_type};
    $c->stash->{selection_pop_id} = $corr_pop_id if $pop_type =~ /selection/;
    
    $self->cache_genetic_corr_output_files($c);
    my $corre_json_file = $c->stash->{genetic_corr_json_file};

    if (!-s $corre_json_file) {
        $c->controller('solGS::Gebvs')->run_combine_traits_gebvs($c);
    }
    
    $c->controller('solGS::Gebvs')->combined_gebvs_file($c);
    my $combined_gebvs_file = $c->stash->{combined_gebvs_file};

    my $ret->{status} = undef;
    my $json = JSON->new();
    if ( !-s $combined_gebvs_file ) {
        $ret->{status} = "There is no GEBVs input. Error occured combining the GEBVs of the traits.";
    } else {   
        $self->run_correlation_analysis($c);
    }

    if (-s $corre_json_file) {
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file, {binmode => ':utf8'});
        $ret->{corre_table_file} = $self->download_genetic_correlation_file($c);
    } else {
        $ret->{status}   = 'There is no correlation output. Error occured running the correlation. ';
    }

    $ret = $json->encode($ret);
    $c->res->content_type('application/json');
    $c->res->body($ret);

}

sub cache_pheno_corr_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corr_pop_id};
    my $corre_cache_dir = $c->stash->{correlation_cache_dir};

    my $table_cache_data = {key    => 'pheno_corr_table_' . $pop_id,
		      file      => "pheno_corr_table_${pop_id}" . '.txt',
		      stash_key => 'pheno_corr_table_file',
		      cache_dir => $corre_cache_dir
    };

    $c->controller('solGS::Files')->cache_file($c, $table_cache_data);

    my $json_cache_data = {
        key  => 'pheno_corr_json_' . $pop_id,
		file => "pheno_corr_json_${pop_id}" . '.txt',
	    stash_key => 'pheno_corr_json_file',
		cache_dir => $corre_cache_dir
    };

   $c->controller('solGS::Files')->cache_file($c, $json_cache_data);

}


sub cache_genetic_corr_output_files {
    my ($self, $c) = @_;

    my $corr_pop_id = $c->stash->{corr_pop_id};
    my $pop_type         = $c->stash->{pop_type};
    my $traits_code = $c->stash->{training_traits_code};
    my $sindex_name = $c->stash->{sindex_name};

    my $model_id    = $c->stash->{training_pop_id};
    my $identifier;
    if ($sindex_name) {
        $identifier  =  $sindex_name;
    } else {
        $identifier  =  $pop_type =~ /selection/ ? "$model_id-${corr_pop_id}-${traits_code}" :  "${corr_pop_id}-${traits_code}";
    }

    my $corre_cache_dir = $c->stash->{correlation_cache_dir};

    my $table_cache_data = {key    => 'genetic_corr_table_' . $identifier,
		      file      => "genetic_corr_table_${identifier}",
		      stash_key => 'genetic_corr_table_file',
		      cache_dir => $corre_cache_dir
    };

    $c->controller('solGS::Files')->cache_file($c, $table_cache_data);

    my $json_cache_data = {
        key => 'genetic_corr_json_' . $identifier,
		file => "genetic_corr_json_${identifier}",
		stash_key => 'genetic_corr_json_file',
		cache_dir => $corre_cache_dir
    };

   $c->controller('solGS::Files')->cache_file($c, $json_cache_data);

}


sub download_pheno_correlation_file {
    my ($self, $c) = @_;

    $self->cache_pheno_corr_output_files($c);
    my $file = $c->stash->{pheno_corr_table_file};

    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'correlation');

    return $file;
}


sub download_genetic_correlation_file {
    my ($self, $c) = @_;

    $self->cache_genetic_corr_output_files($c);
    my $file = $c->stash->{genetic_corr_table_file};

    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'correlation');

    return $file;
}


sub pheno_corr_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corr_pop_id};
    $self->cache_pheno_corr_output_files($c);

    my $output_files = join ("\t",
			  $c->stash->{pheno_corr_table_file},
			  $c->stash->{pheno_corr_json_file},
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "pheno_corr_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $output_files);

    $c->stash->{pheno_corr_output_files} = $tempfile;

}


sub pheno_corr_input_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corr_pop_id};
    my $data_type = $c->stash->{data_type} || 'phenotype';
    my $input_files;

    if ( $data_type =~ /phenotype/i ) {
        $input_files = $c->stash->{phenotype_files_list}
        || $c->stash->{phenotype_file_name};

        if (!$input_files) {
            if ($c->stash->{data_set_type} =~ /combined_populations/) {
                $c->controller('solGS::combinedTrials')->get_combined_pops_list( $c, $pop_id );
                $c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, $c->stash->{combined_pops_list});
            } else {
                $c->controller('solGS::Files')->phenotype_file_name( $c, $pop_id);
            }
        }

        $c->controller('solGS::Files')->phenotype_metadata_file($c);
        my $metadata_file = $c->stash->{phenotype_metadata_file};
        $input_files .= "\t" . $metadata_file;
    }

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "pheno_corr_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $input_files);
    $c->stash->{pheno_corr_input_files} = $tempfile;

}


sub geno_corr_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corr_pop_id};
    $self->cache_genetic_corr_output_files($c);

    my $output_files = join ("\t",
        $c->stash->{genetic_corr_table_file},
        $c->stash->{genetic_corr_json_file},
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "genetic_corr_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $output_files);

    $c->stash->{geno_corr_output_files} = $tempfile;

}


sub geno_corr_input_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{corr_pop_id};
    my $gebvs_file = $c->stash->{combined_gebvs_file};
    my $index_file = $c->stash->{selection_index_file};

    my $input_files = join ("\t",
		      $gebvs_file,
		      $index_file
	);

    my $tmp_dir = $c->stash->{correlation_temp_dir};
    my $name = "genetic_corr_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $input_files);

    $c->stash->{geno_corr_input_files} = $tempfile;

}


sub corr_input_files {
    my ($self, $c) = @_;

    $c->stash->{correlation_script} = "R/solGS/correlation.r";
    if ($c->stash->{correlation_type} =~ /pheno/) {
        $self->pheno_corr_input_files($c);
        $c->stash->{corre_input_files}  = $c->stash->{pheno_corr_input_files}; 
    } elsif ($c->stash->{correlation_type} =~ /genetic/) {
        $self->geno_corr_input_files($c);
        $c->stash->{corre_input_files}  = $c->stash->{geno_corr_input_files};
    }

}

sub corr_output_files {
    my ($self, $c) = @_;

    if ($c->stash->{correlation_type} =~ /pheno/) {
        $self->pheno_corr_output_files($c);
        $c->stash->{corre_output_files} = $c->stash->{pheno_corr_output_files};
    } elsif ($c->stash->{correlation_type} =~ /genetic/) {
        $self->geno_corr_output_files($c);
        $c->stash->{corre_output_files} = $c->stash->{geno_corr_output_files};
    } 

}

sub run_correlation_analysis {
    my ($self, $c) = @_;

    my $queries_file;
    if ($c->stash->{correlation_type} =~ /pheno/) {
        $self->corr_query_jobs_file($c);
        $queries_file = $c->stash->{corr_query_jobs_file};
    }

    $self->corr_r_jobs_file($c);
    my $r_jobs_file = $c->stash->{corr_r_jobs_file};
    $c->stash->{prerequisite_jobs} = $queries_file if $queries_file;
    $c->stash->{dependent_jobs} = $r_jobs_file;

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub corr_r_jobs {
    my ($self, $c) = @_;

    $self->corr_input_files($c);
    $c->stash->{input_files} = $c->stash->{corre_input_files};

    $self->corr_output_files($c);
    $c->stash->{output_files} = $c->stash->{corre_output_files};

    my $corre_type = $c->stash->{correlation_type};
    my $pop_id = $c->stash->{corr_pop_id};

    $c->stash->{r_temp_file}  = "${corre_type}-${pop_id}";
    $c->stash->{r_script}     = $c->stash->{correlation_script};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{correlation_temp_dir};

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY') {
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

    my $corr_pop_id = $c->stash->{corr_pop_id};
    my $data_set_type = $c->stash->{data_set_type};
    my $data_str = $c->stash->{data_structure};
    my $trials_ids = [];

    my $jobs = $c->controller('solGS::AsyncJob')->create_phenotype_data_query_jobs($c, $corr_pop_id);

    if (reftype $jobs ne 'ARRAY') {
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

    if ($jobs->[0]) {
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

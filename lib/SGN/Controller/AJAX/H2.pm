package SGN::Controller::AJAX::H2;

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


sub check_pheno_h2_result :Path('/phenotype/heritability/check/result/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;

    $self->pheno_heritability_output_files($c);
    my $h2_output_file = $c->stash->{h2_coefficients_json_file};

    my $ret->{result} = undef;

    if (-s $h2_output_file && $pop_id =~ /\d+/)
    {
    $ret->{result} = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub heritability_phenotype_data :Path('/heritability/phenotype/data/') Args(0) {
    my ($self, $c) = @_;

    my $pop_id = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;

    my $referer = $c->req->referer;

    my $phenotype_file;

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
        $self->create_heritability_phenodata_file($c);
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



sub trait_acronyms {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    $c->controller('solGS::Trait')->get_all_traits($c, $pop_id);
    $c->controller('solGS::Trait')->get_acronym_pairs($c, $pop_id);

}


sub create_heritability_phenodata_file {
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
    $self->h2_pheno_query_jobs_file($c);
    my $queries =$c->stash->{h2_pheno_query_jobs_file};

    $c->stash->{dependent_jobs} = $queries;
    $c->controller('solGS::AsyncJob')->run_async($c);

    $c->controller("solGS::Files")->phenotype_file_name($c, $pop_id);
    $phenotype_file = $c->stash->{phenotype_file_name};
    }


    my $h2_cache_dir = $c->stash->{heritability_cache_dir};

    copy($phenotype_file, $h2_cache_dir)
    or die "could not copy $phenotype_file to $h2_cache_dir";

    my $file = basename($phenotype_file);
    $c->stash->{phenotype_file_name} = catfile($h2_cache_dir, $file);

}


sub create_heritability_dir {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}


sub pheno_heritability_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    $self->create_heritability_dir($c);
    my $h2_cache_dir = $c->stash->{heritability_cache_dir};

    my $file_cache  = Cache::File->new(cache_root => $h2_cache_dir);
    $file_cache->purge();

    my $key_table = 'h2_coefficients_table_' . $pop_id;
    my $key_json  = 'h2_coefficients_json_' . $pop_id;
    my $h2_coefficients_file      = $file_cache->get($key_table);
    my $h2_coefficients_json_file = $file_cache->get($key_json);

    unless ($h2_coefficients_file && $h2_coefficients_json_file )
    {
        $h2_coefficients_file = catfile($h2_cache_dir, "h2_coefficients_table_${pop_id}");

        write_file($h2_coefficients_file);
        $file_cache->set($key_table, $h2_coefficients_file, '30 days');

        $h2_coefficients_json_file = catfile($h2_cache_dir, "h2_coefficients_json_${pop_id}");

        write_file($h2_coefficients_json_file);
        $file_cache->set($key_json, $h2_coefficients_json_file, '30 days');
    }

    $c->stash->{h2_coefficients_table_file} = $h2_coefficients_file;
    $c->stash->{h2_coefficients_json_file}  = $h2_coefficients_json_file;
}



sub pheno_heritability_analysis_output :Path('/phenotypic/heritability/analysis/output') Args(0) {
    my ($self, $c) = @_;

    my $pop_id = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;

    $self->pheno_heritability_output_files($c);
    my $h2_json_file = $c->stash->{h2_coefficients_json_file};
    my $h2_table_file = $c->stash->{h2_coefficients_table_file};
    my $ret->{status} = 'failed';

    if (!-s $h2_json_file)
    {
        $self->run_pheno_heritability_analysis($c);
        $h2_json_file = $c->stash->{h2_coefficients_json_file};
        $h2_table_file = $c->stash->{h2_coefficients_table_file};
    }

    if (-s $h2_json_file)
    {
    # $self->trait_acronyms($c);
    # my $acronyms = $c->stash->{acronym};

    # $ret->{acronyms} = $acronyms;
    $ret->{status}   = 'success';

    my $data = $c->controller('solGS::Utils')->read_file_data($h2_table_file);
    $ret->{data} = $data;
    #$ret->{data}     = read_file($h2_json_file);
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}



sub download_phenotypic_heritability : Path('/download/phenotypic/heritability/population') Args(1) {
    my ($self, $c, $id) = @_;

    $self->create_heritability_dir($c);
    my $h2_dir = $c->stash->{heritability_cache_dir};
    my $h2_file = catfile($h2_dir,  "h2_coefficients_table_${id}");

    unless (!-e $h2_file || -s $h2_file <= 1)
    {
    my @h2_data;
    my $count=1;

    foreach my $row ( read_file($h2_file) )
    {
        if ($count==1) {  $row = 'Traits,' . $row;}
        $row =~ s/NA//g;
        $row = join(",", split(/\s/, $row));
        $row .= "\n";

        push @h2_data, [ $row ];
        $count++;
    }

    $c->res->content_type("text/plain");
    $c->res->body(join "",  map{ $_->[0] } @h2_data);
    }
}


sub temp_pheno_h2_output_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    $self->pheno_heritability_output_files($c);

    my $files = join ("\t",
              $c->stash->{h2_coefficients_table_file},
              $c->stash->{h2_coefficients_json_file},
    );

    my $tmp_dir = $c->stash->{heritability_temp_dir};
    my $name = "pheno_h2_output_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, $files);

    $c->stash->{temp_pheno_h2_output_file} = $tempfile;

}


sub temp_pheno_h2_input_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    $c->controller("solGS::Files")->phenotype_file_name($c, $pop_id);
    #$self->create_heritability_phenodata_file($c);

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

    my $tmp_dir = $c->stash->{heritability_temp_dir};
    my $name = "pheno_h2_input_files_${pop_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, $files);
    $c->stash->{temp_pheno_h2_input_file} = $tempfile;

}



sub run_pheno_heritability_analysis {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};

    $self->temp_pheno_h2_input_file($c);
    $self->temp_pheno_h2_output_file($c);

    $c->stash->{h2_input_files}  = $c->stash->{temp_pheno_h2_input_file};
    $c->stash->{h2_output_files} = $c->stash->{temp_pheno_h2_output_file};

    $c->stash->{heritability_type} = "pheno-heritability";

    $c->stash->{heritability_script} = "R/heritability/h2_rscript.R";

    $self->run_heritability_analysis($c);

    $self->trait_acronyms($c);
}


sub run_heritability_analysis {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $h2_type = $c->stash->{heritability_type};

    $self->h2_pheno_query_jobs_file($c);
    my $queries_file = $c->stash->{h2_pheno_query_jobs_file};

    $self->h2_pheno_r_jobs_file($c);
    my $r_jobs_file = $c->stash->{h2_pheno_r_jobs_file};

    $c->stash->{prerequisite_jobs} = $queries_file if $queries_file;
    $c->stash->{dependent_jobs} = $r_jobs_file;

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub h2_pheno_r_jobs {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{trial_id} || $c->stash->{pop_id};

    my $input_file = $c->stash->{h2_input_files};
    my $output_file = $c->stash->{h2_output_files};

    my $h2_type = $c->stash->{heritability_type};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "${h2_type}-${pop_id}";
    $c->stash->{r_script}     = $c->stash->{heritability_script};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{heritability_temp_dir};

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
    $jobs = [$jobs];
    }

    $c->stash->{h2_pheno_r_jobs} = $jobs;

}


sub h2_pheno_r_jobs_file {
    my ($self, $c) = @_;

    $self->h2_pheno_r_jobs($c);
    my $jobs = $c->stash->{h2_pheno_r_jobs};

    my $temp_dir = $c->stash->{heritability_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'h2-r-jobs-file');

    nstore $jobs, $jobs_file
    or croak "heritability r jobs : $! serializing heritability r jobs to $jobs_file";

    $c->stash->{h2_pheno_r_jobs_file} = $jobs_file;

}

sub h2_pheno_query_jobs {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{pop_id} || $c->stash->{trial_id};

    $c->controller('solGS::AsyncJob')->get_trials_phenotype_query_jobs_args($c, [$trial_id]);
    my $jobs = $c->stash->{trials_phenotype_query_jobs_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{h2_pheno_query_jobs} = $jobs;

}


sub h2_pheno_query_jobs_file {
    my ($self, $c) = @_;

    $self->h2_pheno_query_jobs($c);
    my $jobs = $c->stash->{h2_pheno_query_jobs};

    my $jobs_file;

    if ($jobs->[0])
    {
	my $temp_dir = $c->stash->{heritability_temp_dir};
	$jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'pheno-h2-query-jobs-file');

	nstore $jobs, $jobs_file
	    or croak "heritability pheno query jobs : $! serializing heritability phenoquery jobs to $jobs_file";
    }

    $c->stash->{h2_pheno_query_jobs_file} = $jobs_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



####
1;
####

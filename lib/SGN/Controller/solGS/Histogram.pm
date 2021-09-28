package SGN::Controller::solGS::Histogram;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use File::Temp qw / tempfile tempdir /;
use JSON;
use Storable qw/ nstore retrieve /;

BEGIN { extends 'Catalyst::Controller' }


sub trait_pheno_means_data :Path('/trait/pheno/means/data/') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{pop_id} = $c->req->param('training_pop_id');
    $c->stash->{training_pop_id} = $c->req->param('training_pop_id');
    $c->stash->{trait_id} = $c->req->param('trait_id');

    my $protocol_id = $c->req->param('genotyping_protocol_id');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    if ($c->req->referer =~ /combined/)
    {
	$c->stash->{data_set_type} = 'combined populations';
	$c->stash->{combo_pops_id} = $c->req->param('combo_pops_id');
    }

    $c->controller('solGS::solGS')->get_trait_details($c, $c->stash->{trait_id});

    my $data = $self->get_trait_pheno_means_data($c);
    my $raw_data = $self->get_trait_pheno_raw_data($c);
    $c->controller('solGS::solGS')->model_phenotype_stat($c);
    my $stat = $c->stash->{descriptive_stat};

    my $ret->{status} = 'failed';

    if (@$data)
    {
        $ret->{data} = $data;
	$ret->{stat} = $stat;
        $ret->{status} = 'success';
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}

sub trait_pheno_raw_data :Path('/trait/pheno/raw/data/') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{pop_id} = $c->req->param('training_pop_id');
    $c->stash->{training_pop_id} = $c->req->param('training_pop_id');
    $c->stash->{trait_id} = $c->req->param('trait_id');

    my $protocol_id = $c->req->param('genotyping_protocol_id');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    if ($c->req->referer =~ /combined/)
    {
	$c->stash->{data_set_type} = 'combined populations';
	$c->stash->{combo_pops_id} = $c->req->param('combo_pops_id');
    }

    $c->controller('solGS::solGS')->get_trait_details($c, $c->stash->{trait_id});

    my $data = $self->get_trait_pheno_raw_data($c);

    $c->controller('solGS::solGS')->model_phenotype_stat($c);
    my $stat = $c->stash->{descriptive_stat};

    my $ret->{status} = 'failed';

    if (@$data)
    {
        $ret->{data} = $data;
	$ret->{stat} = $stat;
        $ret->{status} = 'success';
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_trait_pheno_means_data {
    my ($self, $c) = @_;

    my $trait_id = $c->stash->{trait_id};
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    $c->controller('solGS::Files')->model_phenodata_file($c);
    my $model_pheno_file = $c->stash->{model_phenodata_file};

    my $data = $c->controller('solGS::Utils')->read_file_data($model_pheno_file);

   return $data;

}


sub get_trait_pheno_raw_data {
    my ($self, $c) = @_;

    my $trait_id = $c->stash->{trait_id};
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    $c->controller('solGS::Files')->trait_raw_phenodata_file($c);
    my $trait_raw_pheno_file = $c->stash->{trait_raw_phenodata_file};
    my $trait_abbr = $c->stash->{trait_abbr};
    my @cols = ('observationUnitName', $trait_abbr);
    my $data = $c->controller('solGS::Utils')->read_file_data_cols($trait_raw_pheno_file, \@cols);

   return $data;

}



sub run_histogram {
    my ($self, $c) = @_;

    $self->histogram_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{histogram_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub histogram_r_jobs {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} ? $c->stash->{pop_id} : $c->stash->{combo_pops_id};
    my $trait_abbr = $c->stash->{trait_abbr};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{histogram_temp_dir};

    my $input_file = $self->histogram_input_files($c);
    my $output_file = $self->histogram_output_files($c);
    #my $trait_file = $c->controller('solGS::Files')->model_phenodata_file($c);

    $c->stash->{r_temp_file}  = "histogram-data-${pop_id}-${trait_abbr}";
    $c->stash->{r_script}     = 'R/solGS/histogram.r';
    $c->stash->{input_file} = $input_file;
    $c->stash->{output_file} = $output_file;

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{histogram_r_jobs} = $jobs;

}


sub histogram_r_jobs_file {
    my ($self, $c) = @_;

    $self->histogram_r_jobs($c);
    my $jobs = $c->stash->{histogram_r_jobs};

    my $temp_dir = $c->stash->{histogram_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'histo-r-jobs-file');

    nstore $jobs, $jobs_file
	or croak "histogram r jobs : $! serializing histogram r jobs to $jobs_file";

    $c->stash->{histogram_r_jobs_file} = $jobs_file;

}


sub histogram_input_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{combo_pops_id};
    my $trait_id = $c->stash->{trait_id};

    $c->controller('solGS::Files')->phenotype_file_name($c);
    my $pheno_file = $c->stash->{phenotype_file_name};

    $self->histogram_traits_file($c);
    my $traits_file = $c->stash->{histogram_traits_file};

    $c->controller("solGS::Files")->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    my $file_list = join ("\t",
                          $pheno_file,
                          $traits_file,
			  $metadata_file
	);

    my $tmp_dir = $c->stash->{histogram_temp_dir};
    my $name = "histogram_input_files_${pop_id}_${trait_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $file_list);

    $c->stash->{histogram_input_files} = $tempfile;

}


sub histogram_output_files {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{training_pop_id} || $c->stash->{combo_pops_id};
    my $trait_id = $c->stash->{trait_id};

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);

    $c->controller('solGS::Files')->trait_raw_phenodata_file($c);
    my $raw_pheno_file = $c->stash->{trait_raw_phenodata_file};

    my $means_pheno_file = $c->controller('solGS::Files')->model_phenodata_file($c);

    my $file_list = join ("\t",
                          $raw_pheno_file,
                          $means_pheno_file,
	);

    my $tmp_dir = $c->stash->{histogram_temp_dir};
    my $name = "histogram_output_files_${pop_id}_${trait_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $file_list);

    $c->stash->{histogram_output_files} = $tempfile;

}


sub histogram_traits_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{combo_pops_id};

    my $traits   = $c->stash->{trait_abbr};

    my $tmp_dir = $c->stash->{histogram_temp_dir};
    my $name    = "histogram_traits_file_${pop_id}";
    my $traits_file =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($traits_file, {binmode => ':utf8'}, $traits);

    $c->stash->{histogram_traits_file} = $traits_file;

}



sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}
####
1;
####

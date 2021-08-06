=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 Name

SGN::Controller::solGS::Anova - a controller for ANOVA. For now, this implements a one-way
single trial ANOVA with a possibility for simultanously running anova for multiple traits.

=cut


package SGN::Controller::solGS::Anova;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;
use JSON;
use CXGN::Trial;
use File::Copy;
use File::Basename;
use File::Spec::Functions;
use File::Path qw / mkpath  /;
use URI::FromHash 'uri';

use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;


BEGIN { extends 'Catalyst::Controller::REST' }



__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON'},
    );


sub anova_check_design :Path('/anova/check/design/') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{trial_id} = $c->req->param('trial_id');

    $self->check_trial_design($c);

}


sub anova_traits_list :Path('/anova/traits/list/') Args(0) {
    my ($self, $c) = @_;

    my $trial_id = $c->req->param('trial_id');

    $c->stash->{trial_id} = $trial_id;

    $self->anova_traits($c);

}


sub anova_phenotype_data :Path('/anova/phenotype/data/') Args(0) {
    my ($self, $c) = @_;

    my $trial_id = $c->req->param('trial_id');
    my @traits_ids   = $c->req->param('traits_ids[]');

    $c->stash->{rest}{trial_id} = $trial_id;

    $c->stash->{trial_id} = $trial_id;
    $c->stash->{traits_ids} = \@traits_ids;

    $self->create_anova_phenodata_file($c);
    $self->get_traits_abbrs($c);

}


sub anova_traits {
     my ($self, $c) = @_;

     my $trial_id = $c->stash->{trial_id};

     my $traits = $c->model('solGS::solGS')->trial_traits($trial_id);
     my $clean_traits = $c->controller('solGS::Utils')->remove_ontology($traits);

     $c->stash->{rest}{anova_traits} = $clean_traits;

}


sub create_anova_phenodata_file {
    my ($self, $c)  = @_;

    $c->stash->{pop_id} = $c->stash->{trial_id};

    $c->controller('solGS::Files')->phenotype_file_name($c, $c->stash->{pop_id});
    my $pheno_file = $c->stash->{phenotype_file_name};

    if (!-s $pheno_file)
    {
	$self->anova_query_jobs_file($c);
	my $queries =$c->stash->{anova_query_jobs_file};

	$c->stash->{dependent_jobs} = $queries;
	$c->controller('solGS::AsyncJob')->run_async($c);
    }

    if (!-s $pheno_file)
    {
	$c->stash->{rest}{'Error'} = 'There is no phenotype data for this  trial.';
    }
    else
    {
	$c->stash->{rest}{'success'} = 'Success.';
    }

    if (@{$c->error})
    {
	$c->stash->{rest}{'Error'} = 'There was error querying for the phenotype data.';
    }

}


sub check_trial_design {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};

    my $trial = CXGN::Trial->new({bcs_schema => $self->schema($c),
				 trial_id => $trial_id});

    my $design = $trial->get_design_type();
    my $supported = $self->check_support($design) if $design;

    if (!$design)
    {
	$c->stash->{rest}{'Error'} = 'This trial has no design to apply ANOVA.';
    }
    elsif ($design && !$supported)
    {
	$c->stash->{rest}{'Error'} = $design . ' design is not supported yet. Please report this to the database team. ';
    }
    else
    {
	$c->stash->{rest}{'Design'} = $design;
    }

}


sub check_support {
    my ($self, $design) = @_;

    my $supported_designs = $self->supported_designs;

    my ($match) = grep(/$design/, @$supported_designs);

    return $match;

}


sub supported_designs {
    my $self= shift;

    my $supported_designs = [qw(Alpha, Augmented, RCBD, CRD)];

    return $supported_designs;

}


sub get_traits_abbrs {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $traits_ids = $c->stash->{traits_ids};

    $c->stash->{pop_id} = $trial_id;
    $c->controller('solGS::solGS')->get_all_traits($c, $trial_id);
    $c->controller('solGS::Files')->all_traits_file($c, $trial_id);
    my $traits_file = $c->stash->{all_traits_file};

    my @traits = read_file($traits_file, {binmode => ':utf8'});

    my @traits_abbrs;

    foreach my $id (@$traits_ids) {
	my ($tr) = grep(/$id/, @traits);
	chomp($tr);
	my $abbr = (split('\t', $tr))[2] if $tr;
	my $id_abbr = {'trait_id' => $id, 'trait_abbr' => $abbr};
	push @traits_abbrs, $id_abbr;
    }

   $c->stash->{rest}{traits_abbrs} = \@traits_abbrs;

}


sub anova_analyis :Path('/anova/analysis/') Args(0) {
    my ($self, $c) = @_;

    my $trial_id = $c->req->param('trial_id');
    my $traits   = $c->req->param('traits[]');

    $c->stash->{trial_id} = $trial_id;

    my $json = JSON->new();
    $traits  = $json->decode($traits);

    foreach my $tr (@$traits)
    {
	foreach my $k (keys %$tr)
	{
	    $c->stash->{$k} = $tr->{$k};


	    # my $tr_test = $tr->{$k};
	    # my $trait_id = $c->stash->{trait_id};
	    # print STDERR "\nanova_analysis k $k -- tr test: $tr_test -- trait_id: $trait_id\n";
	    # if ($k =~ /trait_abbr/)
	    # {
	    # 	#$tr->{$k} = undef;
	    # 	if (!$tr->{$k})
	    # 	{

	    # 	    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
	    # 	    my $trait_abbr = $c->stash->{trait_abbr};
	    # 	    print STDERR "\nanova analysis : trait id: $trait_id -- tr abbr: $trait_abbr\n";
	    # 	}
	    # }

	}

	my $anova_result = $self->check_anova_output($c);

	unless ($anova_result)
	{
	    $self->run_anova($c);
	    $anova_result = $self->check_anova_output($c);
	}
    }
}


sub check_anova_output {
    my ($self, $c) = @_;

    $self->anova_table_file($c);
    my $html_file = $c->stash->{anova_table_html_file};

    if (-s $html_file) {

	my $html_table = read_file($html_file, {binmode => ':utf8'});

	$self->prep_download_files($c);
	my $anova_table_file = $c->stash->{download_anova};
	my $model_file       = $c->stash->{download_model};
	my $means_file       = $c->stash->{download_means};
	my $diagnostics_file = $c->stash->{download_diagnostics};

	$c->stash->{rest}{anova_html_table}         =  $html_table;
	$c->stash->{rest}{anova_table_file}         =  $anova_table_file;
	$c->stash->{rest}{anova_model_file}         =  $model_file;
	$c->stash->{rest}{adj_means_file}           =  $means_file;
	$c->stash->{rest}{anova_diagnostics_file}   =  $diagnostics_file;

	return 1;

    } else {
	$self->anova_error_file($c);
	my $error_file = $c->stash->{anova_error_file};

	my $error = read_file($error_file, {binmode => ':utf8'});
	$c->stash->{rest}{Error} = $error;

	return 0;
    }

}


sub prep_download_files {
  my ($self, $c) = @_;

  my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'anova');
  my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);

  mkpath ([$base_tmp_dir], 0, 0755);

  $self->anova_table_file($c);
  my $anova_txt_file  = $c->stash->{anova_table_txt_file};
  my $anova_html_file = $c->stash->{anova_table_html_file};

  $self->anova_model_file($c);
  my $model_file = $c->stash->{anova_model_file};

  $self->adj_means_file($c);
  my $means_file = $c->stash->{adj_means_file};

  $self->anova_diagnostics_file($c);
  my $diagnostics_file = $c->stash->{anova_diagnostics_file};

  $self->anova_error_file($c);
  my $error_file = $c->stash->{anova_error_file};

  $c->controller('solGS::Files')->copy_file($anova_txt_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($model_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($means_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($diagnostics_file, $base_tmp_dir);
  $c->controller('solGS::Files')->copy_file($error_file, $base_tmp_dir);

  $anova_txt_file = fileparse($anova_txt_file);
  $anova_txt_file = catfile($tmp_dir, $anova_txt_file);

  $model_file = fileparse($model_file);
  $model_file = catfile($tmp_dir, $model_file);

  $means_file = fileparse($means_file);
  $means_file = catfile($tmp_dir, $means_file);

  $diagnostics_file = fileparse($diagnostics_file);
  $diagnostics_file = catfile($tmp_dir, $diagnostics_file);

  $error_file = fileparse($error_file);
  $error_file = catfile($tmp_dir, $error_file);

  $c->stash->{download_anova}       = $anova_txt_file;
  $c->stash->{download_model}       = $model_file;
  $c->stash->{download_means}       = $means_file;
  $c->stash->{download_diagnostics} = $diagnostics_file;
  $c->stash->{download_error}       = $error_file;

}

sub run_anova {
    my ($self, $c) = @_;

    $self->anova_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{anova_query_jobs_file};

    $self->anova_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{anova_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}

sub run_anova_single_core {
    my ($self, $c) = @_;

    $self->anova_query_jobs($c);
    my $queries =$c->stash->{anova_query_jobs};

    $self->anova_r_jobs($c);
    my $r_jobs = $c->stash->{anova_r_jobs};

    foreach my $job (@$queries)
    {
	$c->controller('solGS::AsyncJob')->submit_job_cluster($c, $job);
    }

    foreach my $job (@$r_jobs)
    {
	$c->controller('solGS::AsyncJob')->submit_job_cluster($c, $job);
    }

}


sub run_anova_multi_cores {
    my ($self, $c) = @_;

    $self->anova_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{anova_query_jobs_file};

    $self->anova_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{anova_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub anova_r_jobs {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $self->anova_input_files($c);
    my $input_file = $c->stash->{anova_input_files};

    $self->anova_output_files($c);
    my $output_file = $c->stash->{anova_output_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{anova_temp_dir};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "anova-${trial_id}-${trait_id}";
    $c->stash->{r_script}     = 'R/solGS/anova.r';

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{anova_r_jobs} = $jobs;

}


sub anova_r_jobs_file {
    my ($self, $c) = @_;

    $self->anova_r_jobs($c);
    my $jobs = $c->stash->{anova_r_jobs};

    my $temp_dir = $c->stash->{anova_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'anova-r-jobs-file');

    nstore $jobs, $jobs_file
	or croak "anova r jobs : $! serializing anova r jobs to $jobs_file";

    $c->stash->{anova_r_jobs_file} = $jobs_file;

}


sub anova_query_jobs {
    my ($self, $c) = @_;

    $self->create_anova_phenotype_data_query_jobs($c);
    my $jobs = $c->stash->{anova_pheno_query_jobs};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{anova_query_jobs} = $jobs;
}


sub anova_query_jobs_file {
    my ($self, $c) = @_;

    $self->anova_query_jobs($c);
    my $jobs = $c->stash->{anova_query_jobs};

    if ($jobs->[0])
    {
	my $temp_dir = $c->stash->{anova_temp_dir};
	my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, 'anova-query-jobs-file');

	nstore $jobs, $jobs_file
	    or croak "anova query jobs : $! serializing anova query jobs to $jobs_file";

	$c->stash->{anova_query_jobs_file} = $jobs_file;
    }

}


sub create_anova_phenotype_data_query_jobs {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{pop_id} || $c->stash->{trial_id};

    $c->controller('solGS::AsyncJob')->get_cluster_phenotype_query_job_args($c, [$trial_id]);
    my $jobs = $c->stash->{cluster_phenotype_query_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{anova_pheno_query_jobs} = $jobs;

}


sub copy_pheno_file_to_anova_dir {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};

    $c->controller('solGS::Files')->phenotype_file_name($c, $trial_id);
    my $pheno_file = $c->stash->{phenotype_file_name};

    my $anova_cache = $c->stash->{anova_cache_dir};

    $c->controller('solGS::Files')->copy_file($pheno_file, $anova_cache);

    my $file = basename($pheno_file);
    $c->stash->{phenotype_file} = catfile($anova_cache, $file);

}


sub anova_input_files {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->controller('solGS::Files')->phenotype_file_name($c, $trial_id);
    my $pheno_file = $c->stash->{phenotype_file_name};

    $self->anova_traits_file($c);
    my $traits_file = $c->stash->{anova_traits_file};

    $c->controller("solGS::Files")->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    my $file_list = join ("\t",
                          $pheno_file,
                          $traits_file,
			  $metadata_file
	);

    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name = "anova_input_files_${trial_id}_${trait_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $file_list);

    $c->stash->{anova_input_files} = $tempfile;

}


# sub anova_pheno_file {
#     my ($self, $c) = @_;

#     $self->create_anova_phenodata_file($c);

# }


sub anova_traits_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $traits   = $c->stash->{trait_abbr};

    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name    = "anova_traits_file_${trial_id}";
    my $traits_file =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($traits_file, {binmode => ':utf8'}, $traits);

    $c->stash->{anova_traits_file} = $traits_file;

}


sub anova_output_files {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $self->anova_table_file($c);
    $self->anova_model_file($c);
    $self->adj_means_file($c);
    $self->anova_diagnostics_file($c);
    $self->anova_error_file($c);

    my @files = $c->stash->{anova_table_file};

    my $file_list = join ("\t",
                          $c->stash->{anova_model_file},
                          $c->stash->{anova_table_html_file},
			  $c->stash->{anova_table_txt_file},
			  $c->stash->{adj_means_file},
			  $c->stash->{anova_diagnostics_file},
			  $c->stash->{anova_error_file},
	);

    my $tmp_dir = $c->stash->{anova_temp_dir};
    my $name = "anova_output_files_${trial_id}_${trait_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $file_list);

    $c->stash->{anova_output_files} = $tempfile;

}


sub anova_table_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    my $cache_data = {key       => "anova_table_${trial_id}_${trait_id}_html",
                      file      => "anova_table_${trial_id}_${trait_id}.html",
                      stash_key => "anova_table_html_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    $cache_data = {key       => "anova_table_${trial_id}_${trait_id}_txt",
		   file      => "anova_table_${trial_id}_${trait_id}.txt",
		   stash_key => "anova_table_txt_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub anova_diagnostics_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};

    my $cache_data = {key       => "anova_diagnosics_${trial_id}_${trait_id}",
                      file      => "anova_diagnostics_${trial_id}_${trait_id}.png",
                      stash_key => "anova_diagnostics_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub anova_model_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};;

    my $cache_data = {key       => "anova_model_${trial_id}_${trait_id}",
                      file      => "anova_model_${trial_id}_${trait_id}.txt",
                      stash_key => "anova_model_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub anova_error_file {
    my ($self, $c) = @_;

    $c->stash->{file_id} = $c->stash->{trait_id} . '_' . $c->stash->{trial_id};
    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};
    $c->stash->{analysis_type} = 'anova';

    $c->controller('solGS::Files')->analysis_error_file($c);

}


sub adj_means_file {
    my ($self, $c) = @_;

    my $trial_id = $c->stash->{trial_id};
    my $trait_id = $c->stash->{trait_id};

    $c->stash->{cache_dir} = $c->stash->{anova_cache_dir};;

    my $cache_data = {key       => "adj_means_${trial_id}_${trait_id}",
                      file      => "adj_means_${trial_id}_${trait_id}.txt",
                      stash_key => "adj_means_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub schema {
    my ($self, $c) = @_;

    return $c->dbic_schema("Bio::Chado::Schema");

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



__PACKAGE__->meta->make_immutable;

1;

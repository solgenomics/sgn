package SGN::Controller::solGS::Cluster;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Basename;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file/;
use JSON;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;

use CXGN::List;


BEGIN { extends 'Catalyst::Controller' }


# __PACKAGE__->config(
#     default   => 'application/json',
#     stash_key => 'rest',
#     map       => { 'application/json' => 'JSON'},
#     );


sub cluster_analysis :Path('/cluster/analysis/') Args() {
    my ($self, $c, $id) = @_;

    if ($id && !$c->user)
    {
        $c->controller('solGS::Utils')->require_login($c);
    }

    $c->stash->{template} = '/solgs/tools/cluster/analysis.mas';

}


sub check_cluster_output_files {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->create_file_id($c);
    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};
    my $cluster_result_file;
    my $cluster_plot_file;

    if ($cluster_type =~ /k-means/i)
    {
	$self->kcluster_result_file($c);
	$cluster_result_file = $c->stash->{"${cluster_type}_result_file"};

	$self->kcluster_plot_kmeans_file($c);
	$cluster_plot_file = $c->stash->{"${cluster_type}_plot_file"};
    }
    else
    {
	$self->hierarchical_result_file($c);
	$cluster_plot_file = $c->stash->{hierarchical_dendrogram_file};
    }

    if (-s $cluster_plot_file)
    {
	$c->stash->{"${cluster_type}_plot_exists"} = 1;
    }

}


sub run_cluster_analysis :Path('/run/cluster/analysis/') Args() {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $list_id = $c->stash->{list_id};
    if ($list_id)
    {
        $c->controller('solGs::List')->stash_list_metadata($c, $list_id);
    }

    my $file_id = $c->controller('solGS::Files')->create_file_id($c);
    $c->stash->{file_id} = $file_id;

    $c->stash->{pop_id} = $c->stash->{cluster_pop_id};
    my $cluster_type = $c->stash->{cluster_type};

    $self->check_cluster_output_files($c);
    my $cluster_plot_exists = $c->stash->{"${cluster_type}_plot_exists"};

    my $ret->{result} = 'Cluster analysis failed.';

    if (!$cluster_plot_exists)
    {
	    $self->run_cluster($c);
    }

    $ret = $self->_prepare_response($c);

    $ret = to_json($ret);
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub cluster_genotypes_list :Path('/cluster/genotypes/list') Args(0) {
    my ($self, $c) = @_;

    my $list_id   = $c->req->param('list_id');
    my $list_name = $c->req->param('list_name');
    my $list_type = $c->req->param('list_type');
    my $pop_id    = $c->req->param('population_id');

    $c->stash->{list_name} = $list_name;
    $c->stash->{list_id}   = $list_id;
    $c->stash->{pop_id}    = $pop_id;
    $c->stash->{list_type} = $list_type;

    $c->stash->{data_structure} = 'list';
    $self->create_cluster_genotype_data($c);

    my $geno_file = $c->stash->{genotype_file};

    my $ret->{status} = 'failed';
    if (-s $geno_file )
    {
        $ret->{status} = 'success';
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);
}


sub cluster_gebvs_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Gebvs')->combined_gebvs_file($c);
    my $combined_gebvs_file = $c->stash->{combined_gebvs_file};

    $c->stash->{cluster_gebvs_file} = $combined_gebvs_file;

}


sub _prepare_response {
    my ($self, $c) = @_;

    $self->prep_cluster_download_files($c);
    my $cluster_plot_file = $c->stash->{download_plot};
    my $clusters_file     = $c->stash->{download_clusters};
    my $report            = $c->stash->{download_cluster_report};

    my $output_link = $c->controller('solGS::Files')->format_cluster_output_url($c, 'cluster/analysis');

    my $result_name = $c->stash->{dataset_name}  || $c->stash->{list_name} || $c->stash->{cluster_pop_name};

    my $cluster_type = $c->stash->{cluster_type};
    my $file_id = $c->stash->{file_id};
    my $plot_name = "${cluster_type}-plot-${file_id}";

    my $ret->{kcluster_plot} = $cluster_plot_file;
    $ret->{clusters} = $clusters_file;
    $ret->{cluster_report} = $report;
    $ret->{result} = 'success';
    $ret->{cluster_pop_id} = $c->stash->{cluster_pop_id};
    $ret->{combo_pops_id} = $c->stash->{combo_pops_id};
    $ret->{list_id}       = $c->stash->{list_id};
    $ret->{cluster_type}  = $c->stash->{cluster_type};
    $ret->{dataset_id}    = $c->stash->{dataset_id};
    $ret->{trials_names}  = $c->stash->{trials_names};
    $ret->{result_name}   = $result_name;
    $ret->{output_link}   = $output_link;
    $ret->{data_type}     = $c->stash->{data_type};
    $ret->{k_number}      = $c->stash->{k_number};
    $ret->{selection_proportion} = $c->stash->{selection_proportion};
    $ret->{training_traits_ids} =  $c->stash->{training_traits_ids};
    $ret->{plot_name} = $plot_name;

    return $ret;

}


sub create_cluster_genotype_data {
    my ($self, $c) = @_;

    my $data_structure = $c->stash->{data_structure};
    my $referer = $c->req->referer;
    my $combo_pops_id = $c->stash->{combo_pops_id};

    my $cluster_pop_id = $c->stash->{cluster_pop_id};

    if ($data_structure =~ /list/)
    {
	$self->cluster_list_genotype_data($c);
    }
    elsif ($data_structure =~ /dataset/)
    {
	$c->controller('solGS::Dataset')->get_dataset_genotypes_genotype_data($c);
    }
    elsif ($referer =~ /solgs\/trait\/\d+\/population\/|\/breeders\/trial\/|\/solgs\/traits\/all\/population/)
    {
	$c->controller('solGS::solGS')->genotype_file($c, $cluster_pop_id);
    }
    elsif ($combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
	$c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->controller('solGS::List')->get_trials_list_geno_data($c);
    }

}


sub create_cluster_phenotype_data {
    my ($self, $c) = @_;

    my $data_structure = $c->stash->{data_structure};
    my $referer = $c->req->referer;
    my $combo_pops_id = $c->stash->{combo_pops_id};

    if ($data_structure =~ /list/)
    {
	$self->cluster_list_phenotype_data($c);
    }
    elsif ($data_structure =~ /dataset/)
    {
	$c->controller('solGS::Dataset')->get_dataset_phenotype_data($c);
    }
    elsif ($referer =~ /solgs\/trait\/\d+\/population\/|\/breeders\/trial\/|\/solgs\/traits\/all\/population/)
    {
	$c->controller('solGS::solGS')->phenotype_file($c);
    }
    elsif ($combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
	$c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->controller('solGS::List')->get_trials_list_pheno_data($c);
    }

}


sub cluster_list_genotype_data {
    my ($self, $c) = @_;

    my $list_id       = $c->stash->{list_id};
    my $list_type     = $c->stash->{list_type};
    my $pop_id        = $c->stash->{pop_id};
    my $data_structure = $c->stash->{data_structure};
    my $data_set_type  = $c->stash->{data_set_type};
    my $referer        = $c->req->referer;
    my $geno_file;

    if ($referer =~ /solgs\/trait\/\d+\/population\//)
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id);
	$c->stash->{genotype_file} = $c->stash->{genotype_file_name};
    }
    elsif ($referer =~ /solgs\/selection\//)
    {
	$c->stash->{pops_ids_list} = [$c->stash->{training_pop_id}, $c->stash->{selection_pop_id}];
	$c->controller('solGS::List')->get_trials_list_pheno_data($c);
	$c->controller('solGS::combinedTrials')->process_trials_list_details($c);
    }
    elsif ($referer =~ /cluster\/analysis\// && $data_set_type =~ 'combined_populations')
    {
    	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $c->stash->{combo_pops_id});
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->controller('solGS::List')->get_trials_list_geno_data($c);
	$c->controller('solGS::combinedTrials')->process_trials_list_details($c);
    }
    else
    {
	if ($list_type eq 'accessions')
	{
	    $c->controller('solGS::List')->genotypes_list_genotype_file($c, $list_id);
	}
	elsif ( $list_type eq 'trials')
	{
	    $c->controller('solGS::List')->get_list_trials_ids($c);
	    $c->stash->{pops_ids_list} =  $c->stash->{trials_ids};

	    $c->controller('solGS::List')->get_trials_list_geno_data($c);
	    $c->controller('solGS::combinedTrials')->process_trials_list_details($c);
	}
    }

}


sub cluster_list_phenotype_data {
    my ($self, $c) = @_;

    my $list_id       = $c->stash->{list_id};
    my $pop_id        = $c->stash->{pop_id};
    my $data_structure = $c->stash->{data_structure};
    my $data_set_type  = $c->stash->{data_set_type};
    my $referer        = $c->req->referer;
    my $geno_file;

    if ($referer =~ /solgs\/trait\/\d+\/population\//)
    {
	$c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
	$c->stash->{phenotype_file} = $c->stash->{phenotype_file_name};
    }
    elsif ($referer =~ /cluster\/analysis\// && $data_set_type =~ 'combined_populations')
    {
    	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $c->stash->{combo_pops_id});
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->controller('solGS::List')->get_trials_list_pheno_data($c);
    }
    else
    {
	$c->controller('solGS::List')->list_phenotype_data($c);
    }

}



sub combined_cluster_trials_data_file {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};

    my $cluster_type = $c->stash->{cluster_type};

    my $file_name;
    my $tmp_dir = $c->stash->{cluster_temp_dir};

    if ($cluster_type =~ /k-means/i)
    {
	$file_name = "combined_${cluster_type}_data_file_${file_id}";
    }
    else
    {
	$file_name = "combined_hierarchical_data_file_${file_id}";
    }

    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $file_name);

    $c->stash->{combined_cluster_data_file} = $tempfile;

}


sub kcluster_result_file {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};
    $c->stash->{cache_dir} = $c->stash->{cluster_cache_dir};

    my $cache_data = {key       => "${cluster_type}-result-${file_id}",
                      file      => "${cluster_type}-result-${file_id}.txt",
                      stash_key => "${cluster_type}_result_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub kcluster_plot_kmeans_file {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};
    $c->stash->{cache_dir} = $c->stash->{cluster_cache_dir};

     my $cache_data = {key      => "${cluster_type}-plot-${file_id}",
                      file      => "${cluster_type}-plot-${file_id}.png",
                      stash_key => "${cluster_type}_plot_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub kcluster_plot_pam_file {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $cluster_dir = $c->stash->{cluster_cache_dir};
    my $cluster_type = $c->stash->{cluster_type};
    $c->stash->{cache_dir} = $cluster_dir;

    my $cache_data = {key       => "${cluster_type}_plot_pam_${file_id}",
                      file      => "${cluster_type}_plot_pam_${file_id}.png",
                      stash_key => "${cluster_type}_plot_pam_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub hierarchical_result_file {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $cluster_dir = $c->stash->{cluster_cache_dir};

    $c->stash->{cache_dir} = $cluster_dir;

    my $cache_data = {key       => "hierarchical_result_${file_id}",
                      file      => "hierarchical_result_${file_id}.txt",
                      stash_key => 'hierarchical_result_file'
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub cluster_options_file {
    my ($self, $c) = @_;

    my $data_type = $c->stash->{data_type};
    my $k_number  = $c->stash->{k_number};
    my $file_id   = $c->stash->{file_id};

    my $cluster_type = $c->stash->{cluster_type};
    $c->stash->{cache_dir} = $c->stash->{cluster_cache_dir};

     my $cache_data = {key      => "${cluster_type}_options_${file_id}",
                      file      => "${cluster_type}_options_${file_id}.txt",
                      stash_key => "${cluster_type}_options_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub prep_cluster_download_files {
  my ($self, $c) = @_;

  $c->stash->{cache_dir}      = $c->stash->{cluster_cache_dir};
  $c->stash->{analysis_type}  = $c->stash->{cluster_type};

  my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'cluster');
  my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);

  mkpath ([$base_tmp_dir], 0, 0755);

  my $cluster_type = $c->stash->{cluster_type};

  $self->kcluster_plot_kmeans_file($c);
  my $plot_file = $c->stash->{"${cluster_type}_plot_file"};
  $c->controller('solGS::Files')->copy_file($plot_file, $base_tmp_dir);
  $plot_file = catfile($tmp_dir, basename($plot_file));

  $self->kcluster_result_file($c);
  my $clusters_file = $c->stash->{"${cluster_type}_result_file"};
  $c->controller('solGS::Files')->copy_file($clusters_file, $base_tmp_dir);
  $clusters_file =  catfile($tmp_dir, basename($clusters_file));

  $c->controller('solGS::Files')->analysis_report_file($c);
  my $report_file = $c->stash->{"${cluster_type}_report_file"};
  $c->controller('solGS::Files')->copy_file($report_file, $base_tmp_dir);
  $report_file =  catfile($tmp_dir, basename($report_file));

  $c->stash->{download_plot}     = $plot_file;
  $c->stash->{download_clusters} = $clusters_file;
  $c->stash->{download_cluster_report}= $report_file;

}


sub cluster_output_files {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};

    my $result_file;
    my $plot_pam_file;
    my $plot_kmeans_file;

    if ($cluster_type =~/k-means/i)
    {
	$self->kcluster_result_file($c);
	$result_file = $c->stash->{"${cluster_type}_result_file"};

	$self->kcluster_plot_kmeans_file($c);
	$plot_kmeans_file = $c->stash->{"${cluster_type}_plot_file"};

	#$self->kcluster_plot_pam_file($c);
	#$plot_pam_file = $c->stash->{"${cluster_type}_plot_pam_file"};
    }
    else
    {
	$self->hierarchical_result_file($c);
	$result_file = $c->stash->{hierarchical_result_file};
    }

    $c->stash->{analysis_type} = $cluster_type;
    ###$c->stash->{pop_id} = $file_id;

    $c->stash->{cache_dir} = $c->stash->{cluster_cache_dir};
    $c->controller('solGS::Files')->analysis_report_file($c);
    my $analysis_report_file = $c->{stash}->{"${cluster_type}_report_file"};

    $c->controller('solGS::Files')->analysis_error_file($c);
    my $analysis_error_file = $c->{stash}->{"${cluster_type}_error_file"};

    $self->combined_cluster_trials_data_file($c);
    my $combined_cluster_data_file =  $c->stash->{combined_cluster_data_file};

    my $file_list = join ("\t",
                          $result_file,
			  $plot_pam_file,
			  $plot_kmeans_file,
			  $analysis_report_file,
			  $analysis_error_file,
			  $combined_cluster_data_file,
	);

    my $tmp_dir = $c->stash->{cluster_temp_dir};
    my $name = "cluster_output_files_${file_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    write_file($tempfile, {binmode => ':utf8'}, $file_list);

    $c->stash->{cluster_output_files} = $tempfile;

}


sub cluster_geno_input_files {
    my ($self, $c) = @_;

    my $data_type = $c->stash->{data_type};
    my $files;

    if ($data_type =~ /genotype/i)
    {
	my $pop_id = $c->stash->{cluster_pop_id};
	my $protocol_id = $c->stash->{genotyping_protocol_id};

	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id, $protocol_id);

	$files = $c->stash->{genotype_files_list}
	|| $c->stash->{genotype_file}
	|| $c->stash->{genotype_file_name};
    }

    $c->stash->{cluster_geno_input_files} = $files;
}


sub cluster_pheno_input_files {
    my ($self, $c) = @_;

    my $data_type = $c->stash->{data_type};
    my $files;

    if ($data_type =~ /phenotype/i)
    {
	$files = $c->stash->{phenotype_files_list}
	|| $c->stash->{phenotype_file_name};
#	$c->controller('solGS::Files')->trait_phenodata_file($c);
#	$files = $c->stash->{trait_phenodata_file};

	$c->controller('solGS::Files')->phenotype_metadata_file($c);
	my $metadata_file = $c->stash->{phenotype_metadata_file};

	$files .= "\t" . $metadata_file;
    }

    $c->stash->{cluster_pheno_input_files} = $files;

}


sub cluster_gebvs_input_files {
    my ($self, $c) = @_;

    my $data_type = $c->stash->{data_type};

    $self->cluster_gebvs_file($c);
    my $files = $c->stash->{cluster_gebvs_file};

    $c->stash->{cluster_gebvs_input_files} = $files;

}


sub cluster_sindex_input_files {
    my ($self, $c) = @_;

    my $dir = $c->stash->{selection_index_cache_dir};
    my $sindex_name = $c->stash->{sindex_name};
    my $file = catfile($dir, "selection_index_only_${sindex_name}.txt");

    $c->stash->{cluster_sindex_input_files} = $file;

}


sub cluster_input_files {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $tmp_dir = $c->stash->{cluster_temp_dir};
    my $data_type = $c->stash->{data_type};
    my $cluster_type = $c->stash->{cluster_type};

    my $name     = "cluster_input_files_${file_id}";
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);

    my $files;

    if ($data_type =~ /genotype/i)
    {
	$self->cluster_geno_input_files($c);
	$files = $c->stash->{cluster_geno_input_files};
    }
    elsif ($data_type =~ /phenotype/i)
    {
	$self->cluster_pheno_input_files($c);
	$files = $c->stash->{cluster_pheno_input_files};
    }
    elsif ($data_type =~ /gebv/i)
    {
	$self->cluster_gebvs_input_files($c);
	$files = $c->stash->{cluster_gebvs_input_files};
    }

    if ($c->stash->{sindex_name})
    {
	$self->cluster_sindex_input_files($c);
	$files .=  "\t" . $c->stash->{cluster_sindex_input_files};
    }

    $self->cluster_options_file($c);
    my $cluster_opts_file = $c->stash->{"${cluster_type}_options_file"};

    $files .= "\t" . $cluster_opts_file;

    write_file($tempfile, {binmode => ':utf8'}, $files);

    $c->stash->{cluster_input_files} = $tempfile;

}


sub save_cluster_opts {
    my ($self, $c) = @_;

    my $cluster_type = $c->stash->{cluster_type};
    $self->cluster_options_file($c);
    my $opts_file = $c->stash->{"${cluster_type}_options_file"};

    my $data_type = $c->stash->{data_type};
    $data_type    = lc($data_type);
    my $k_number  = $c->stash->{k_number};
    my $selection_prop = $c->stash->{selection_proportion};
    my $traits_ids = $c->stash->{training_traits_ids};

    my @traits_abbrs;
    my $predicted_traits;

    if ($traits_ids)
    {
    	foreach my $trait_id (@$traits_ids)
    	{
    	    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    	    push @traits_abbrs, $c->stash->{trait_abbr};
    	}

    	$predicted_traits = join(',', @traits_abbrs);
    }

    my $opts_data = 'Params' . "\t" . 'Value' . "\n";
    $opts_data   .= 'data_type' . "\t" . $data_type . "\n";
    $opts_data   .= 'k_numbers' . "\t" . $k_number  . "\n";
    $opts_data   .= 'cluster_type' . "\t" . $cluster_type  . "\n";
    $opts_data   .= 'selection_proportion' . "\t" . $selection_prop  . "\n" if $selection_prop;
    $opts_data   .= 'predicted_traits' . "\t" . $predicted_traits . "\n" if $predicted_traits;

    write_file($opts_file, {binmode => ':utf8'}, $opts_data);


}


sub create_cluster_phenotype_data_query_jobs {
    my ($self, $c) = @_;

    my $data_str = $c->stash->{data_structure};

    if ($data_str =~ /list/)
    {
	$c->controller('solGS::List')->create_list_pheno_data_query_jobs($c);
	$c->stash->{cluster_pheno_query_jobs} = $c->stash->{list_pheno_data_query_jobs};
    }
    elsif ($data_str =~ /dataset/)
    {
	$c->controller('solGS::Dataset')->create_dataset_pheno_data_query_jobs($c);
	$c->stash->{cluster_pheno_query_jobs} = $c->stash->{dataset_pheno_data_query_jobs};
    }
    else
    {
	my $combo_pops_id = $c->stash->{combo_pops_id};
	if ($combo_pops_id)
	{
	    $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
	    $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	}

	my $trials = $c->stash->{pops_ids_list} || [$c->stash->{training_pop_id}] || [$c->stash->{selection_pop_id}];
	$c->controller('solGS::AsyncJob')->get_cluster_phenotype_query_job_args($c, $trials);
	$c->stash->{cluster_pheno_query_jobs} = $c->stash->{cluster_phenotype_query_job_args};
    }

}


sub create_cluster_genotype_data_query_jobs {
    my ($self, $c) = @_;

    my $data_str = $c->stash->{data_structure};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    if ($data_str =~ /list/)
    {
	$c->controller('solGS::List')->create_list_geno_data_query_jobs($c);
	$c->stash->{cluster_geno_query_jobs} = $c->stash->{list_geno_data_query_jobs};
    }
    elsif ($data_str =~ /dataset/)
    {
	$c->controller('solGS::Dataset')->create_dataset_geno_data_query_jobs($c);
	$c->stash->{cluster_geno_query_jobs} = $c->stash->{dataset_geno_data_query_jobs};
    }
    else
    {
	my $trials = $c->stash->{pops_ids_list} || [$c->stash->{cluster_pop_id}];
	$c->controller('solGS::AsyncJob')->get_cluster_genotype_query_job_args($c, $trials, $protocol_id);
	$c->stash->{cluster_geno_query_jobs} = $c->stash->{cluster_genotype_query_job_args};
    }

}


sub cluster_query_jobs {
    my ($self, $c) = @_;

    my $data_type = $c->stash->{data_type};
    my  $sindex_name = $c->stash->{sindex_name};

    my $jobs = [];

    if ($data_type =~ /phenotype/i)
    {
	$self->create_cluster_phenotype_data_query_jobs($c);
	$jobs = $c->stash->{cluster_pheno_query_jobs};
    }
    elsif ($data_type =~ /genotype/i && !$sindex_name)
    {
	$self->create_cluster_genotype_data_query_jobs($c);
	$jobs = $c->stash->{cluster_geno_query_jobs};
    }

     if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{cluster_query_jobs} = $jobs;
}


sub run_cluster {
    my ($self, $c) = @_;

     $self->save_cluster_opts($c);

     if ($c->stash->{data_type} =~ /genotype|phenotype/i)
     {
         $self->cluster_query_jobs_file($c);
         $c->stash->{prerequisite_jobs} = $c->stash->{cluster_query_jobs_file};
     }

    if ($c->stash->{data_type} =~ /gebv/i)
    {
        $self->cluster_combine_gebvs_jobs_file($c);
        $c->stash->{prerequisite_jobs} = $c->stash->{cluster_combine_gebvs_jobs_file};
    }

    $self->cluster_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{cluster_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub run_cluster_single_core {
    my ($self, $c) = @_;

    $self->cluster_query_jobs($c);
    my $queries =$c->stash->{cluster_query_jobs};

    $self->cluster_r_jobs($c);
    my $r_jobs = $c->stash->{cluster_r_jobs};

    foreach my $job (@$queries)
    {
	$c->controller('solGS::AsyncJob')->submit_job_cluster($c, $job);
    }

    foreach my $job (@$r_jobs)
    {
	$c->controller('solGS::AsyncJob')->submit_job_cluster($c, $job);
    }

}


sub run_cluster_multi_cores {
    my ($self, $c) = @_;

    $self->cluster_query_jobs_file($c);
    $c->stash->{prerequisite_jobs} = $c->stash->{cluster_query_jobs_file};

    $self->cluster_r_jobs_file($c);
    $c->stash->{dependent_jobs} = $c->stash->{cluster_r_jobs_file};

    $c->controller('solGS::AsyncJob')->run_async($c);

}


sub cluster_r_jobs {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};

    $self->cluster_output_files($c);
    my $output_file = $c->stash->{cluster_output_files};

    $self->cluster_input_files($c);
    my $input_file = $c->stash->{cluster_input_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{cluster_temp_dir};

    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "${cluster_type}-${file_id}";
    $c->stash->{r_script}     = 'R/solGS/cluster.r';

    $c->controller('solGS::AsyncJob')->get_cluster_r_job_args($c);
    my $jobs  = $c->stash->{cluster_r_job_args};

    if (reftype $jobs ne 'ARRAY')
    {
	$jobs = [$jobs];
    }

    $c->stash->{cluster_r_jobs} = $jobs;

}


sub cluster_r_jobs_file {
    my ($self, $c) = @_;

    my $cluster_type = $c->stash->{cluster_type};

    $self->cluster_r_jobs($c);
    my $jobs = $c->stash->{cluster_r_jobs};

    my $temp_dir = $c->stash->{cluster_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, "${cluster_type}-r-jobs-file");

    nstore $jobs, $jobs_file
	or croak "cluster r jobs : $! serializing $cluster_type cluster r jobs to $jobs_file";

    $c->stash->{cluster_r_jobs_file} = $jobs_file;

}


sub cluster_query_jobs_file {
    my ($self, $c) = @_;

    my $cluster_type = $c->stash->{cluster_type};

    $self->cluster_query_jobs($c);
    my $jobs = $c->stash->{cluster_query_jobs};

    my $temp_dir = $c->stash->{cluster_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, "${cluster_type}-query-jobs-file");

    nstore $jobs, $jobs_file
	or croak "cluster query jobs : $! serializing $cluster_type cluster query jobs to $jobs_file";

    $c->stash->{cluster_query_jobs_file} = $jobs_file;

}


sub cluster_combine_gebvs_jobs_file {
    my ($self, $c) = @_;

    my $cluster_type = $c->stash->{cluster_type};

    $c->controller('solGS::Gebvs')->combine_gebvs_jobs($c);
    my $jobs = $c->stash->{combine_gebvs_jobs};

    my $temp_dir = $c->stash->{cluster_temp_dir};
    my $jobs_file =  $c->controller('solGS::Files')->create_tempfile($temp_dir, "${cluster_type}-combine-gebvs-jobs-file");

    nstore $jobs, $jobs_file
	or croak "cluster combine gebvs jobs : $! serializing $cluster_type cluster combine gebvs jobs to $jobs_file";

    $c->stash->{cluster_combine_gebvs_jobs_file} = $jobs_file;

}



sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



__PACKAGE__->meta->make_immutable;

####
1;
####

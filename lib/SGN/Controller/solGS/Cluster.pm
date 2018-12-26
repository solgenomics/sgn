package SGN::Controller::solGS::Cluster;

use Moose;
use namespace::autoclean;

use File::Basename;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;

use CXGN::List;


BEGIN { extends 'Catalyst::Controller' }


# __PACKAGE__->config(
#     default   => 'application/json',
#     stash_key => 'rest',
#     map       => { 'application/json' => 'JSON', 
# 		   'text/html' => 'JSON' },
#     );


sub cluster_analysis :Path('/cluster/analysis/') Args() {
    my ($self, $c, $id) = @_;

    $c->stash->{pop_id} = $id;

    $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $id); 
    my $combo_pops_list = $c->stash->{combined_pops_list};

    if ($combo_pops_list) 
    {
	$c->stash->{data_set_type} = 'combined_populations';	
    }
    
    $c->stash->{template} = '/solgs/cluster/index.mas';

}


sub cluster_check_result :Path('/cluster/check/result/') Args() {
    my ($self, $c) = @_;
 
    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');

    my $list_id     = $c->req->param('list_id');
    my $list_type   = $c->req->param('list_type');
    my $list_name   = $c->req->param('list_name');

    my $dataset_id     =  $c->req->param('dataset_id');
    my $data_structure =  $c->req->param('data_structure');
    my $k_number       =  $c->req->param('k_number'); 
    my $cluster_type   = $c->req->param('cluster_type');
    $cluster_type      = 'k-means' if !$cluster_type;
    my $data_type      =  $c->req->param('data_type');
    $data_type         = 'Genotype' if !$data_type;

  
    $c->stash->{training_pop_id}  = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;
    $c->stash->{data_structure}   = $data_structure;
    $c->stash->{list_id}          = $list_id;
    $c->stash->{list_type}        = $list_type;
    $c->stash->{dataset_id}       = $dataset_id;
    $c->stash->{cluster_type}     = $cluster_type;
    $c->stash->{combo_pops_id}    = $combo_pops_id;
    $c->stash->{k_number}         = $k_number;
    
    #$c->stash->{file_id} = $training_pop_id || $list_id || $combo_pops_id || $dataset_id;
    $c->stash->{pop_id} = $training_pop_id || $list_id || $combo_pops_id || $dataset_id;
    $c->controller('solGS::Files')->create_file_id($c);
    #my $file_id = $c->stash->{file_id};
    
    $self->check_cluster_output_files($c);
    my $cluster_plot_exists = $c->stash->{"${cluster_type}_plot_exists"};
    
    my $ret->{result} = undef;
      
    if ($cluster_plot_exists)
    {
	$ret = $self->_jsonize_output($c);
    }

    $ret = to_json($ret);        
    $c->res->content_type('application/json');
    $c->res->body($ret);
    
}


sub check_cluster_output_files {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->create_file_id($c);
    my $file_id = $c->stash->{file_id};
    print STDERR "\ncheck_cluster_output_files: file_id - $file_id\n";
    my $cluster_type = $c->stash->{cluster_type};
    my $cluster_result_file;
    my $cluster_plot_file;
    
    if ($cluster_type =~ /k-means/i)
    {
	$self->kcluster_result_file($c);
	$cluster_result_file = $c->stash->{"${cluster_type}_result_file"};
 print STDERR "\ncheck_cluster_output_files: result file $cluster_result_file\n";
	$self->kcluster_plot_kmeans_file($c);
	$cluster_plot_file = $c->stash->{"${cluster_type}_plot_kmeans_file"};
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


sub cluster_result :Path('/cluster/result/') Args() {
    my ($self, $c) = @_;
    
    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');

    my $list_id     = $c->req->param('list_id');
    my $list_type   = $c->req->param('list_type');
    my $list_name   = $c->req->param('list_name');

    my $dataset_id     =  $c->req->param('dataset_id');
    my $data_structure =  $c->req->param('data_structure');
    my $k_number       =  $c->req->param('k_number'); 
    my $cluster_type   = $c->req->param('cluster_type');
    $cluster_type      = 'k-means' if !$cluster_type;
    my $data_type      =  $c->req->param('data_type');
    $data_type         = 'Genotype' if !$data_type;

    print STDERR "\n cluster result data type: $data_type -- cluster type: $cluster_type -- k_number: $k_number\n";
   
       
    $c->stash->{training_pop_id}  = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;
    $c->stash->{data_structure}   = $data_structure;
    $c->stash->{list_id}          = $list_id;
    $c->stash->{list_type}        = $list_type;
    $c->stash->{dataset_id}       = $dataset_id;
    $c->stash->{cluster_type}     = $cluster_type;
    $c->stash->{combo_pops_id}    = $combo_pops_id;
    $c->stash->{data_type}        = $data_type;
    $c->stash->{k_number}         = $k_number;

    $c->stash->{pop_id} = $training_pop_id || $list_id || $combo_pops_id || $dataset_id;
    $c->controller('solGS::Files')->create_file_id($c);
    my $file_id = $c->stash->{file_id};


    
    
    print STDERR "\n file id: $file_id\n";
   
    #$c->stash->{file_id} = $training_pop_id || $list_id || $combo_pops_id || $dataset_id;
     
    $self->check_cluster_output_files($c);
    my $cluster_plot_exists = $c->stash->{"${cluster_type}_plot_exists"};
 print STDERR "\n cluster plot exists : $cluster_plot_exists\n";
    my $ret->{result} = 'Cluster analysis failed.';

    if (!$cluster_plot_exists)
    {
	my $no_cluster_data;

	print STDERR "\n checking data_type : $data_type\n";
	if ($data_type =~ /genotype/i) 
	{
	    $self->create_cluster_genotype_data($c);
	    print STDERR "\n created genotype data\n";

	    my $geno_files = $c->stash->{genotype_files_list};
	    my $geno_file = $c->stash->{genotype_file};

	    print STDERR "\n genofiles: $geno_files --  geno_file: $geno_file\n";
	    
	    if (!$c->stash->{genotype_files_list} && !$c->stash->{genotype_file}) 
	    {	  
		$no_cluster_data = 'There is no genotype data. Aborted Cluster analysis.';                
	    }
	} 
	elsif ($data_type =~ /phenotype/i)
	{
	    print STDERR "\n creating phenotype data\n";
	    $self->create_cluster_phenotype_data($c);
	    if (!$c->stash->{phenotype_files_list} && !$c->stash->{phenotype_file})
	    {
		$no_cluster_data = 'There is no phenotype data. Aborted Cluster analysis.';
	    }
	} 	
	elsif ($data_type =~ /gebv/i)
	{
	    print STDERR "\n creating gebvs data\n";

	    $c->cluster_gebvs_file($c);
	    my $cluster_gebvs_file = $c->stash->{cluster_gebvs_file};

	    print STDERR "\ngebvs file: $cluster_gebvs_file\n";
	    if (!$cluster_gebvs_file)
	    {
		$no_cluster_data = 'There is no GEBVs data. Aborted Cluster analysis.';
	    }
	}

	if ($no_cluster_data)
	{
	    $ret->{result} = $no_cluster_data; 
	}  
	else 
	{
	    print STDERR "\n call run_cluster\n";
	    $self->save_cluster_opts($c);
	    $self->run_cluster($c);
	    $ret = $self->_jsonize_output($c);
	}	
    }
    else
    {    print STDERR "\n _jasonize_output\n";	 
	$ret = $self->_jsonize_output($c);
    }
    
    print STDERR "\n Done _jasonize_output\n $ret->{result} -- $ret->{kcluster_plot}\n"; 
    $ret = to_json($ret);
     print STDERR "\nret: $ret\n";   
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

    $c->controller('solGS::TraitsGebvs')->combine_gebvs_of_traits($c);   
    my $combined_gebvs_file = $c->stash->{combined_gebvs_file};
    
    my $tmp_dir = $c->stash->{cluster_temp_dir};
    $combined_gebvs_file = $c->controller('solGS::Files')->copy_file($combined_gebvs_file, $tmp_dir);

    $c->stash->{cluster_gebvs_file} = $combined_gebvs_file;
   
}


sub _jsonize_output {
    my ($self, $c) = @_;
    
    $self->prep_cluster_download_files($c);
    my $cluster_plot_file = $c->stash->{download_plot};
    my $clusters_file     = $c->stash->{download_clusters};
    my $report            = $c->stash->{download_cluster_report};

    my $output_link = $c->controller('solGS::Files')->format_cluster_output_url($c, 'cluster/analysis');

    print STDERR "\noutput link: $output_link\n$cluster_plot_file\n$clusters_file\n$report\n";
    
    my $ret->{kcluster_plot} = $cluster_plot_file;
    $ret->{clusters} = $clusters_file;
    $ret->{cluster_report} = $report;
    $ret->{result} = 'success';  
    $ret->{pop_id} = $c->stash->{pop_id};# if $list_type eq 'trials';
    $ret->{combo_pops_id} = $c->stash->{combo_pops_id};
    $ret->{list_id}       = $c->stash->{list_id};
    $ret->{cluster_type}  = $c->stash->{cluster_type};
    $ret->{dataset_id}    = $c->stash->{dataset_id};
    $ret->{trials_names}  = $c->stash->{trials_names};
    $ret->{output_link}   = $output_link;

    print STDERR "\nret result: $ret->{result}\n";
    return $ret;
    
}


sub create_cluster_genotype_data {    
    my ($self, $c) = @_;
   
    my $data_structure = $c->stash->{data_structure};

    if ($data_structure =~ /list/) 
    {
	$self->cluster_list_genotype_data($c);	
    }
    elsif ($data_structure =~ /dataset/) 
    {
	$c->controller('solGS::Dataset')->get_dataset_genotypes_genotype_data($c);	
    }
    else 
    {
	$c->controller('solGS::List')->process_trials_list_details($c);
    }

}


sub cluster_list_genotype_data {
    my ($self, $c) = @_;
    
    my $list_id       = $c->stash->{list_id};
    my $list_type     = $c->stash->{list_type};
    my $pop_id        = $c->stash->{pop_id};
    my $data_structure = $c->stash->{data_structure};
    my $data_set_type  = $c->stash->{data_set_type};
    my $referer       = $c->req->referer;
    my $geno_file;
    
    if ($referer =~ /solgs\/trait\/\d+\/population\//) 
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $pop_id);
	$c->stash->{genotype_file} = $c->stash->{genotype_file_name}; 
    }
    elsif ($referer =~ /solgs\/selection\//) 
    {
	$c->stash->{pops_ids_list} = [$c->stash->{training_pop_id}, $c->stash->{selection_pop_id}];
	$c->controller('solGS::List')->process_trials_list_details($c);
    }
    elsif ($referer =~ /cluster\/analysis\// && $data_set_type =~ 'combined_populations')
    {
    	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $c->stash->{combo_pops_id});
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->controller('solGS::List')->process_trials_list_details($c);
    }	   
    else
    {
	if ($list_type eq 'accessions')
	{
	    $c->controller('solGS::List')->genotypes_list_genotype_file($c);
	} 
	elsif ( $list_type eq 'trials') 
	{
	    $c->controller('solGS::List')->get_trials_list_ids($c);
	    my $trials_ids = $c->stash->{trials_ids};
	  
	    $c->stash->{pops_ids_list} = $trials_ids;
	    $c->controller('solGS::List')->process_trials_list_details($c);
	}
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

    my $cache_data = {key       => "${cluster_type}_result_${file_id}",
                      file      => "${cluster_type}_result_${file_id}.txt",
                      stash_key => "${cluster_type}_result_file"
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub kcluster_plot_kmeans_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};
    $c->stash->{cache_dir} = $c->stash->{cluster_cache_dir};

     my $cache_data = {key      => "${cluster_type}_plot_kmeans_${file_id}",
                      file      => "${cluster_type}_plot_kmeans_${file_id}.png",
                      stash_key => "${cluster_type}_plot_kmeans_file"
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

  print STDERR "\nprep dld cluster type: $cluster_type\n";
  
  $self->kcluster_plot_kmeans_file($c);   
  my $plot_file = $c->stash->{"${cluster_type}_plot_kmeans_file"};
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
 
print STDERR "\n $plot_file \n$clusters_file\n$report_file\n";  
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
	$plot_kmeans_file = $c->stash->{"${cluster_type}_plot_kmeans_file"};

	$self->kcluster_plot_pam_file($c);
	$plot_pam_file = $c->stash->{"${cluster_type}_plot_pam_file"};
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
    write_file($tempfile, $file_list);
    
    $c->stash->{cluster_output_files} = $tempfile;

}


sub cluster_input_files {
    my ($self, $c) = @_;
          
    my $file_id = $c->stash->{file_id};
    my $tmp_dir = $c->stash->{cluster_temp_dir};
    my $data_type = $c->stash->{data_type};
    my $cluster_type = $c->stash->{cluster_type};
    
    my $name     = "cluster_input_files_${file_id}_${data_type}"; 
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);

    my $files;

    if ($data_type =~ /genotype/i) 
    {
	if ($c->stash->{genotype_files_list}) 
	{
	    $files = join("\t", @{$c->stash->{genotype_files_list}});			      
	}
	else 
	{
	    $files = $c->stash->{genotype_file};
	}
    }
    elsif ($data_type =~ /phenotype/i)
    {
	#phenotype data file
	
    }
    elsif ($data_type =~ /gebv/i)	
    {
	$c->cluster_gebvs_file($c);
	$files = $c->stash->{cluster_gebvs_file};	
    }

    $self->cluster_options_file($c);
    my $cluster_opts_file = $c->stash->{"${cluster_type}_options_file"};

    $files .= "\t" . $cluster_opts_file;
    
    write_file($tempfile, $files);
    
    $c->stash->{cluster_input_files} = $tempfile;

}


sub save_cluster_opts {
    my ($self, $c) = @_;

    my $cluster_type = $c->stash->{cluster_type};
    $self->cluster_options_file($c);
    my $opts_file = $c->stash->{"${cluster_type}_options_file"};

    my $data_type = $c->stash->{data_type};
    my $k_number  = $c->stash->{k_number};

    my $opts_data = 'Params' . "\t" . 'Value' . "\n";
    $opts_data   .= 'data type' . "\t" . $data_type . "\n";
    $opts_data   .= 'k numbers' . "\t" . $k_number  . "\n";
    $opts_data   .= 'cluster type' . "\t" . $cluster_type  . "\n";

    print STDERR "\nopts_data: \n$opts_data\n";

    print STDERR "\n opts_file: $opts_file\n";
    
    write_file($opts_file, $opts_data);
    
}


sub run_cluster {
    my ($self, $c) = @_;
    
    my $pop_id  = $c->stash->{pop_id};
    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};
   
    $self->cluster_output_files($c);
    my $output_file = $c->stash->{cluster_output_files};

    $self->cluster_input_files($c);
    my $input_file = $c->stash->{cluster_input_files};
   
    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;

    if ($cluster_type =~ /k-means/i)
    {
	print STDERR "\n stash k-means r_script\n";
	$c->stash->{r_script}     = 'R/solGS/kCluster.r';
    }
    else
    {
	$c->stash->{r_script}     = 'R/solGS/hierarchical.r';	
    }
    
    $c->stash->{analysis_tempfiles_dir} = $c->stash->{cluster_temp_dir};
    $c->stash->{r_temp_file}  =  "${cluster_type}_${file_id}";
    	print STDERR "\n calling_r_script\n";
    $c->controller("solGS::solGS")->run_r_script($c);
    
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####

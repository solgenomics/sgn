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
    
    $c->stash->{template} = '/cluster/analysis.mas';

}


sub cluster_check_result :Path('/cluster/check/result/') Args() {
    my ($self, $c) = @_;

    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $list_id          = $c->req->param('list_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');
    my $cluster_type     = $c->req->param('cluster_type');
    my $referer          = $c->req->referer;
    my $file_id;

    if ($referer =~ /solgs\/selection\//)
    {
	if ($training_pop_id && $selection_pop_id) 
	{
	    $c->stash->{pops_ids_list} = [$training_pop_id, $selection_pop_id];
	    $c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	    $c->stash->{pop_id} =  $c->stash->{combo_pops_id};
	    $file_id = $c->stash->{combo_pops_id};
	}
    } 
    elsif ($list_id)
    {
	$c->stash->{pop_id} = $list_id;
	$file_id = $list_id;
	
	$list_id =~ s/list_//;		   	
	my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
	my $list_type = $list->type();
	$c->stash->{list_id}   = $list_id;
	$c->stash->{list_type} = $list_type;

	if ($list_type =~ /trials/)
	{
	    $c->controller('solGS::List')->get_trials_list_ids($c);
	    my $trials_ids = $c->stash->{trials_ids};
	    
	    $c->stash->{pops_ids_list} = $trials_ids;
	    $c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	    $c->stash->{pop_id} =  $c->stash->{combo_pops_id};
	    $file_id = $c->stash->{combo_pops_id};
	}	
    }
    elsif ($referer =~ /cluster\/analysis\/|\/solgs\/model\/combined\/populations\//  && $combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$file_id = $combo_pops_id;
    }
    else 
    {
	$c->stash->{pop_id} = $training_pop_id;
	$file_id = $training_pop_id;	
    }

    $c->stash->{file_id} = $file_id;

    my $cluster_result_file;

    if ($cluster_type =~ /k-means/)
    {
	$self->kcluster_result_file($c);
	$cluster_result_file = $c->stash->{kcluster_result_file};
    }
    else
    {
	$self->hierarchical_result_file($c);
	$cluster_result_file = $c->stash->{hierarchical_result_file};	
    }
    
    my $ret->{result} = undef;
   
    if (-s $cluster_result_file && $file_id =~ /\d+/) 
    {
	$ret->{result} = 1;
	$ret->{list_id} = $list_id;
	$ret->{cluster_type} = $cluster_type;
	$ret->{combo_pops_id} = $combo_pops_id;
	# $c->stash->{rest}{result} = 1;
	# $c->stash->{rest}{list_id} = $list_id;
	# $c->stash->{rest}{combo_pops_id} = $combo_pops_id;
	# $c->stash->{rest}{cluster_type} = $cluster_type;    
    }

    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
    
}


sub cluster_result :Path('/cluster/result/') Args() {
    my ($self, $c) = @_;
    
    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');

    my $list_id     = $c->req->param('list_id');
    my $list_type   = $c->req->param('list_type');
    my $list_name   = $c->req->param('list_name');
    
    my $cluster_type = $c->req->param('cluster_type');
    my $referer      = $c->req->referer;

    $c->stash->{cluster_type} = $cluster_type;
    
    my $file_id;

    if ($referer =~ /solgs\/selection\//)
    {
	$c->stash->{pops_ids_list} = [$training_pop_id, $selection_pop_id];
	$c->controller('solGS::List')->register_trials_list($c);
	$combo_pops_id =  $c->stash->{combo_pops_id};
	$c->stash->{pop_id} =  $combo_pops_id;
	$file_id = $combo_pops_id;
    }
    elsif ($referer =~ /cluster\/analysis\/|\/solgs\/model\/combined\/populations\// && $combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->stash->{pop_id} = $combo_pops_id;
	$file_id = $combo_pops_id;
	$c->stash->{data_set_type} = 'combined_populations';
    } 
    else 
    {
	$c->stash->{pop_id} = $training_pop_id;
	$file_id = $training_pop_id;
    }

    $c->stash->{training_pop_id}  = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;

    if ($list_id) 
    {
	$c->stash->{data_set_type} = 'list';
	$c->stash->{list_id}       = $list_id;
	$c->stash->{list_type}     = $list_type;
    }
   
    $self->create_cluster_genotype_data($c);
 
    $c->stash->{file_id} = $file_id;

    my $cluster_result_file;
    if ($cluster_type =~ /k-means/)
    {
	$self->kcluster_result_file($c);
	$cluster_result_file = $c->stash->{kcluster_result_file};
    }
    else
    {
	$self->hierarchical_result_file($c);
	$cluster_result_file = $c->stash->{hierarchical_result_file};
    }

    my $ret->{status} = 'Cluster analysis failed.';
   
    if( !-s $cluster_result_file)
    {	
	if (!$c->stash->{genotype_files_list} && !$c->stash->{genotype_file}) 
	{	  
	    $ret->{status} = 'There is no genotype data. Aborted Cluster analysis.';                
	}
	else 
	{	    
	    $self->run_cluster($c);	    
	}	
    }
    
    #my $cluster_result = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $cluster_result_file);
    my $kcluster_plot = $self->copy_kmeans_plot_to_images_dir($c);
    my $host = $c->req->base;

    if ( $host !~ /localhost/)
    {
	$host =~ s/:\d+//; 
	$host =~ s/http\w?/https/;
    }

    my $pop_id = $c->stash->{pop_id};
    my $output_link = $host . 'cluster/analysis/' . $pop_id;

    if ($kcluster_plot)
    {
        $ret->{kcluster_plot} = $kcluster_plot;
        $ret->{status} = 'success';  
	$ret->{pop_id} = $c->stash->{pop_id};# if $list_type eq 'trials';
	#$ret->{trials_names} = $c->stash->{trials_names};
	$ret->{output_link}  = $output_link;
    }  

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

    $c->stash->{data_set_type} = 'list';
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


sub create_cluster_genotype_data {    
    my ($self, $c) = @_;
   
    my $data_set_type = $c->stash->{data_set_type};

    if ($data_set_type =~ /list/) 
    {
	$self->cluster_list_genotype_data($c);	
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
    my $data_set_type = $c->stash->{data_set_type};
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
	    print STDERR "\n trials ids: @$trials_ids\n";
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
    my $tmp_dir;
    
    if ($cluster_type =~ /k-means/)
    {
	$file_name = "combined_kcluster_data_file_${file_id}";
	$tmp_dir = $c->stash->{kcluster_temp_dir};
    }
    else
    {
	$file_name = "combined_hierarchical_data_file_${file_id}";
	$tmp_dir = $c->stash->{hierarchical_temp_dir};
    }
    
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $file_name);
    
    $c->stash->{combined_cluster_data_file} = $tempfile;
    
}


sub kcluster_result_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
   
    $c->stash->{cache_dir} = $c->stash->{cluster_cache_dir};

    my $cache_data = {key       => "kcluster_result_${file_id}",
                      file      => "kcluster_result_${file_id}.txt",
                      stash_key => 'kcluster_result_file'
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub kcluster_plot_kmeans_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
  
    $c->stash->{cache_dir} = $c->stash->{cluster_cache_dir};

     my $cache_data = {key       => "kcluster_plot_kmeans_${file_id}",
                      file      => "kcluster_plot_kmeans_${file_id}.png",
                      stash_key => 'kcluster_plot_kmeans_file'
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub kcluster_plot_pam_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
    my $cluster_dir = $c->stash->{cluster_cache_dir};

    $c->stash->{cache_dir} = $cluster_dir;

    my $cache_data = {key       => "kcluster_plot_pam_${file_id}",
                      file      => "kcluster_plot_pam_${file_id}.png",
                      stash_key => 'kcluster_plot_pam_file'
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


sub copy_kmeans_plot_to_images_dir {
    my ($self, $c) = @_;

    my $images_dir = catfile($c->tempfiles_subdir, 'temp_images');
    my $fpath_images_dir = catfile($c->config->{basepath}, $images_dir);
  
    $self->kcluster_plot_kmeans_file($c);   
    my $plot = $c->stash->{kcluster_plot_kmeans_file};


    $c->controller('solGS::Files')->copy_file($plot, $fpath_images_dir);

    my $image_dir_file = catfile($images_dir, basename($plot));

    return $image_dir_file;
    
}


sub cluster_output_files {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
    my $cluster_type = $c->stash->{cluster_type};

    my $result_file;
    my $plot_pam_file;
    my $plot_kmeans_file;

    if ($cluster_type =~ 'k-means')	
    {
	$self->kcluster_result_file($c);
	$result_file = $c->stash->{kcluster_result_file};

	$self->kcluster_plot_kmeans_file($c);
	$plot_kmeans_file = $c->stash->{kcluster_plot_kmeans_file};

	$self->kcluster_plot_pam_file($c);
	$plot_pam_file = $c->stash->{kcluster_plot_pam_file};
    }
    else
    {
	$self->hierarchical_result_file($c);
	$result_file = $c->stash->{hierarchical_result_file};
    }

    $c->stash->{analysis_type} = $cluster_type;
    $c->stash->{pop_id} = $file_id;

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
    
    my $name     = "cluster_input_files_${file_id}"; 
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);

    my $files;

    if ($c->stash->{genotype_files_list}) 
    {
	$files = join("\t", @{$c->stash->{genotype_files_list}});			      
    }
    else 
    {
	$files = $c->stash->{genotype_file};
    }
    
    write_file($tempfile, $files);
    
    $c->stash->{cluster_input_files} = $tempfile;

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

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{cluster_temp_dir};
    
    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;

    if ($cluster_type = ~/k-means/)
    {
	$c->stash->{r_temp_file}  = "kcluster-${file_id}";
	$c->stash->{r_script}     = 'R/solGS/kCluster.r';
    }
    else
    {
	$c->stash->{r_temp_file}  = "hierarchical-${file_id}";
	$c->stash->{r_script}     = 'R/solGS/hierarchical.r';	
    }

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

package SGN::Controller::solGS::Files;

use Moose;
use namespace::autoclean;

use File::Basename;
use File::Copy;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use Cache::File;


BEGIN { extends 'Catalyst::Controller' }


sub marker_effects_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
    no warnings 'uninitialized';

    my $data_set_type = $c->stash->{data_set_type};
       
    my $cache_data;

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id}; 
       
        $cache_data = {key       => 'marker_effects_combined_pops_'.  $trait . '_' . $combo_identifier,
                       file      => 'marker_effects_'. $trait . '_' . $combo_identifier . '_combined_pops' . '.txt',
                       stash_key => 'marker_effects_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
        };
    }
    else
    {
    
       $cache_data = {key       => 'marker_effects' . $pop_id . '_'.  $trait,
                      file      => 'marker_effects_' . $trait . '_' . $pop_id . '.txt',
                      stash_key => 'marker_effects_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
       };
    }

    $self->cache_file($c, $cache_data);

}


sub variance_components_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
    
    my $data_set_type = $c->stash->{data_set_type};
    
    my $cache_data;

    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id}; 

        $cache_data = {key       => 'variance_components_combined_pops_'.  $trait . "_". $combo_identifier,
                       file      => 'variance_components_'. $trait . '_' . $combo_identifier. '_combined_pops.txt',
                       stash_key => 'variance_components_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
        };
    }
    else 
    {
        $cache_data = {key       => 'variance_components_' . $pop_id . '_'.  $trait,
                       file      => 'variance_components_' . $trait . '_' . $pop_id . '.txt',
                       stash_key => 'variance_components_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
        };
    }

    $self->cache_file($c, $cache_data);
}


sub trait_phenodata_file {
    my ($self, $c) = @_;
   
    my $pop_id        = $c->stash->{pop_id};
    my $trait_abbr    = $c->stash->{trait_abbr};    
    my $data_set_type = $c->stash->{data_set_type};
   
    my $cache_data;
    
    if ($trait_abbr)
    {
	no warnings 'uninitialized';

	if ($data_set_type =~ /combined populations/)
	{
	    my $combo_identifier = $c->stash->{combo_pops_id}; 
	    $cache_data = {key       => 'phenotype_trait_combined_pops_'.  $trait_abbr . "_". $combo_identifier,
			   file      => 'phenotype_data_' . $trait_abbr . '_'. $combo_identifier. '_combined.txt',
			   stash_key => 'trait_phenodata_file',
			   cache_dir => $c->stash->{solgs_cache_dir}
	    };
	}
	else 
	{
	    $cache_data = {key       => 'phenotype_' . $pop_id . '_'.  $trait_abbr,
			   file      => 'phenotype_data_' . $trait_abbr .'_' . $pop_id . '.txt',
			   stash_key => 'trait_phenodata_file',
			   cache_dir => $c->stash->{solgs_cache_dir}
	    };
	}

	$self->cache_file($c, $cache_data);
    }
}


sub filtered_training_genotype_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    $pop_id = $c->{stash}->{combo_pops_id} if !$pop_id;

    my $cache_data = { key       => 'filtered_genotype_data_' . $pop_id, 
                       file      => 'filtered_genotype_data_' . $pop_id . '.txt',
                       stash_key => 'filtered_training_genotype_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
    };
    
    $self->cache_file($c, $cache_data);
}


sub filtered_selection_genotype_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};
    
    my $cache_data = { key       => 'filtered_genotype_data_' . $pop_id, 
                       file      => 'filtered_genotype_data_' . $pop_id . '.txt',
                       stash_key => 'filtered_selection_genotype_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
    };
    
    $self->cache_file($c, $cache_data);
}


sub formatted_phenotype_file {
    my ($self, $c) = @_;
   
    my $pop_id = $c->stash->{pop_id};
    $pop_id = $c->{stash}->{combo_pops_id} if !$pop_id;

    my $cache_data = { key       => 'formatted_phenotype_data_' . $pop_id, 
                       file      => 'formatted_phenotype_data_' . $pop_id . '.txt',
                       stash_key => 'formatted_phenotype_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
    };
    
    $self->cache_file($c, $cache_data);
}


sub phenotype_file_name {
    my ($self, $c, $pop_id) = @_;
   
    $pop_id = $c->stash->{pop_id} || $c->{stash}->{combo_pops_id} if !$pop_id;

    my $dir; 
    if ($pop_id =~ /list/) 
    {
	$dir = $c->stash->{solgs_lists_dir};
    } 
    elsif ($pop_id =~ /dataset/) 
    {
	$dir = $c->stash->{solgs_datasets_dir};	
    }
    else
    {
	$dir = $c->stash->{solgs_cache_dir};
    }
   
    my $cache_data = { key       => 'phenotype_data_' . $pop_id, 
		       file      => 'phenotype_data_' . $pop_id . '.txt',
		       stash_key => 'phenotype_file_name',
		       cache_dir => $dir
    };
    
    $self->cache_file($c, $cache_data);
    
}


sub analysis_error_file {
    my ($self, $c) = @_;
   
    my $type      = $c->stash->{analysis_type};
    my $cache_dir = $c->stash->{cache_dir}  || $c->stash->{solgs_cache_dir};
    my $file_id   = $c->stash->{file_id};
   
    my $name = "${type}_error_${file_id}";
   
    my $cache_data = { key       => $name, 
		       file      => $name . '.txt',
		       cache_dir => $cache_dir,
		       stash_key => "${type}_error_file",
    };
    
    $self->cache_file($c, $cache_data);

}


sub analysis_report_file {
    my ($self, $c) = @_;
   
    my $type      = $c->stash->{analysis_type};
    my $cache_dir = $c->stash->{cache_dir} || $c->stash->{solgs_cache_dir};
    my $file_id   = $c->stash->{file_id};
   
    my	$name = "${type}_report_${file_id}";
   
    my $cache_data = { key       => $name, 
		       file      => $name . '.txt',
		       cache_dir => $cache_dir,
		       stash_key => "${type}_report_file",		       
    };
    
    $self->cache_file($c, $cache_data);

}


sub genotype_file_name {
    my ($self, $c, $pop_id) = @_;
   
   # $pop_id = $c->stash->{pop_id} if !$pop_id;
 
    my $dir; 

    my $combo_pops_id = $c->{stash}->{combo_pops_id};

    if ($combo_pops_id && $combo_pops_id == $pop_id) 
    {
	$pop_id = $pop_id . '_combined';
    }
    
    if ($pop_id =~ /list/) 
    {
	$dir = $c->stash->{solgs_lists_dir};
    } 
    elsif ($pop_id =~ /dataset/) 
    {
	$dir = $c->stash->{solgs_datasets_dir};	
    }
    else
    {
	$dir = $c->stash->{solgs_cache_dir};
    }

    my $cache_data = { key       => 'genotype_data_' . $pop_id, 
		       file      => 'genotype_data_' . $pop_id . '.txt',
		       stash_key => 'genotype_file_name',
		       cache_dir => $dir
    };
 
    
    $self->cache_file($c, $cache_data);
}


sub relationship_matrix_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $data_set_type = $c->stash->{data_set_type};
        
    my $cache_data;
    
    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        my $combo_identifier = $c->stash->{combo_pops_id};
        $cache_data = {key       => 'relationship_matrix_combined_pops_'.  $combo_identifier,
                       file      => 'relationship_matrix_combined_pops_' . $combo_identifier . '.txt',
                       stash_key => 'relationship_matrix_file',
		       cache_dir => $c->stash->{solgs_cache_dir}

        };
    }
    else 
    {
    
        $cache_data = {key       => 'relationship_matrix_' . $pop_id,
                       file      => 'relationship_matrix_' . $pop_id . '.txt',
                       stash_key => 'relationship_matrix_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
        };
    }

    $self->cache_file($c, $cache_data);

}


# sub blups_file {
#     my ($self, $c) = @_;
    
#     my $blups_file = $c->stash->{rrblup_training_gebvs_file};
#     my $top_blups = $c->controller('solGS::Utils')->top_10($blups_file);
#     $c->stash->{top_blups} = $top_blups;
# }


sub validation_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};
     
    my $data_set_type = $c->stash->{data_set_type};
       
    my $cache_data;

    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/) 
    {
        my $combo_identifier = $c->stash->{combo_pops_id};
        $cache_data = {key       => 'cross_validation_combined_pops_'.  $trait . "_${combo_identifier}",
                       file      => 'cross_validation_'. $trait . '_' . $combo_identifier . '_combined_pops.txt' ,
                       stash_key => 'validation_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
        };
    }
    else
    {

        $cache_data = {key       => 'cross_validation_' . $pop_id . '_' . $trait, 
                       file      => 'cross_validation_' . $trait . '_' . $pop_id . '.txt',
                       stash_key => 'validation_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
        };
    }

    $self->cache_file($c, $cache_data);
}


sub combined_gebvs_file {
    my ($self, $c, $identifier) = @_;

    my $pop_id = $c->stash->{pop_id};
     
    my $cache_data = {key       => 'selected_traits_gebv_' . $pop_id . '_' . $identifier, 
                      file      => 'selected_traits_gebv_' . $pop_id . '_' . $identifier . '.txt',
                      stash_key => 'selected_traits_gebv_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub trait_phenotype_file {
    my ($self, $c, $pop_id, $trait) = @_;

    my $dir = $c->stash->{solgs_cache_dir};
    my $exp = "phenotype_data_${trait}_${pop_id}";
    my $file = $self->grep_file($dir, $exp);
   
    $c->stash->{trait_phenotype_file} = $file;

}


sub all_traits_file {
    my ($self, $c, $pop_id) = @_;

    my $pop_id = $c->stash->{pop_id};
    #$pop_id = $c->stash->{combo_pops_id} if !$pop_id;

    my $cache_data = {key       => 'all_traits_pop' . $pop_id,
                      file      => 'all_traits_pop_' . $pop_id . '.txt',
                      stash_key => 'all_traits_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub traits_list_file {
    my ($self, $c, $pop_id) = @_;

   # my $pop_id = $c->stash->{pop_id};
   # $pop_id = $c->stash->{combo_pops_id} if !$pop_id;
    if ($pop_id)
    {
	my $cache_data = {key       => 'traits_list_pop' . $pop_id,
			  file      => 'traits_list_pop_' . $pop_id . '.txt',
			  stash_key => 'traits_list_file',
			  cache_dir => $c->stash->{solgs_cache_dir}
	};

	$self->cache_file($c, $cache_data);
    }

}


sub population_metadata_file {
    my ($self, $c, $dir, $file_id) = @_;
    
    my $user_id = $c->user->id;
    
    my $cache_data = {key       => "metadata_${user_id}_${file_id}",
                      file      => "metadata_${user_id}_${file_id}",
                      stash_key => 'population_metadata_file',
		      cache_dir => $dir,
    };

    $self->cache_file($c, $cache_data);

}


sub phenotype_metadata_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'phenotype_metadata',
                      file      => 'phenotype_metadata' . '.txt',
                      stash_key => 'phenotype_metadata_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub rrblup_training_gebvs_file {
    my ($self, $c, $identifier, $trait_id) = @_;

    $identifier = $c->stash->{pop_id} || $c->stash->{training_pop_id} || $c->stash->{combo_pops_id} if !$identifier;
    $trait_id  = $c->stash->{trait_id} if !$trait_id;
   
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr  = $c->stash->{trait_abbr};

    my $cache_data = {key       => 'rrblup_training_gebvs_' . $identifier . '_' . $trait_abbr, 
                      file      => 'rrblup_training_gebvs_' . $trait_abbr. '_' . $identifier  . '.txt',
                      stash_key => 'rrblup_training_gebvs_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub rrblup_selection_gebvs_file {    
    my ($self, $c, $identifier, $trait_id) = @_;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr  = $c->stash->{trait_abbr};

    my $cache_data = {key       => 'rrblup_selection_gebvs_' . $identifier . '_' . $trait_abbr, 
                      file      => 'rrblup_selection_gebvs_' . $trait_abbr . '_' . $identifier . '.txt',
                      stash_key => 'rrblup_selection_gebvs_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub list_of_prediction_pops_file {
    my ($self, $c, $training_pop_id)= @_;

    my $cache_data = {key       => 'list_of_prediction_pops' . $training_pop_id,
                      file      => 'list_of_prediction_pops_' . $training_pop_id . '.txt',
                      stash_key => 'list_of_prediction_pops_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub first_stock_genotype_file {
    my ($self, $c, $pop_id) = @_;
    
    my $cache_data = {key       => 'first_stock_genotype_file'. $pop_id,
                      file      => 'first_stock_genotype_file_' . $pop_id . '.txt',
                      stash_key => 'first_stock_genotype_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub selection_population_file {
    my ($self, $c, $pred_pop_id) = @_;
    
    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};

    my $file = "selection_population_file_${pred_pop_id}";
    my $tempfile = $self->create_tempfile($tmp_dir, $file);

    $c->stash->{prediction_pop_id} = $pred_pop_id;
    $c->stash->{selection_pop_id}  = $pred_pop_id;
    $self->filtered_selection_genotype_file($c);
    my $filtered_geno_file = $c->stash->{filtered_selection_genotype_file};

    my $geno_files = $filtered_geno_file;  
 
    $self->genotype_file_name($c, $pred_pop_id);
    $geno_files .= "\t" . $c->stash->{genotype_file_name};  

    write_file($tempfile, $geno_files); 

    $c->stash->{selection_population_file} = $tempfile;
  
}


sub traits_acronym_file {
    my ($self, $c, $pop_id) = @_;

   # my $pop_id = $c->stash->{pop_id};
   # $pop_id = $c->stash->{combo_pops_id} if !$pop_id;

    my $cache_data = {key       => 'traits_acronym_pop' . $pop_id,
                      file      => 'traits_acronym_pop_' . $pop_id . '.txt',
                      stash_key => 'traits_acronym_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}
 

sub template {
    my ($self, $file) = @_;

    $file =~ s/(^\/)//; 
    my $dir = '/solgs';
 
    return  catfile($dir, $file);

}


sub cache_file {
    my ($self, $c, $cache_data) = @_;
  
    my $cache_dir = $cache_data->{cache_dir} || $c->stash->{cache_dir} ||  $c->stash->{solgs_cache_dir};
      
    my $file_cache  = Cache::File->new(cache_root => $cache_dir, 
				       lock_level => Cache::File::LOCK_NFS()
	);

    $file_cache->purge();

    my $file  = $file_cache->get($cache_data->{key});
    
    no warnings 'uninitialized';
    
    unless (-s $file > 1)
    {      
        $file = catfile($cache_dir, $cache_data->{file});

        write_file($file);
        $file_cache->set($cache_data->{key}, $file, '30 days');
    }

    $c->stash->{$cache_data->{stash_key}} = $file;
   # $c->stash->{cache_dir} = $c->stash->{solgs_cache_dir};
}


sub create_file_id {
    my ($self, $c) = @_;

    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $data_structure   = $c->stash->{data_structure};
    my $list_id          = $c->stash->{list_id};
    my $list_type        = $c->stash->{list_type};
    my $dataset_id       = $c->stash->{dataset_id};
    my $cluster_type     = $c->stash->{cluster_type};
    my $combo_pops_id    = $c->stash->{combo_pops_id};
    my $data_type        = $c->stash->{data_type};
    my $k_number         = $c->stash->{k_number};    
    my $sindex_wts       = $c->stash->{sindex_weigths};
    my $sindex_name      = $c->stash->{sindex_name};
    my $sel_prop         = $c->stash->{selection_proportion};

    my $traits_ids = $c->stash->{training_traits_ids};
    my @traits_ids = $traits_ids->[0] ? @{$traits_ids} : 0;
    
    my $traits_selection_id;
    if (scalar(@traits_ids > 1))
    {
	$traits_selection_id = $c->controller('solGS::TraitsGebvs')->create_traits_selection_id($traits_ids);
    }
        
    my $file_id;
    my $referer = $c->req->referer;
    
    if ($referer =~ /solgs\/selection\//)
    {
	$c->stash->{pops_ids_list} = [$training_pop_id, $selection_pop_id];
	$c->controller('solGS::List')->register_trials_list($c);
	$combo_pops_id =  $c->stash->{combo_pops_id};
	$file_id = $combo_pops_id;
    }
    elsif ($referer =~ /cluster\/analysis\/|\/solgs\/model\/combined\/populations\// && $combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$file_id = $combo_pops_id;
	$c->stash->{data_set_type} = 'combined_populations';
    } 
    elsif ($referer =~ /solgs\/traits\/all\/population\/|solgs\/models\/combined\/trials\//) 
    {
	 if ($sindex_wts)
	 {
	     if ($selection_pop_id && $training_pop_id !~ /^$selection_pop_id$/)
	     {
	     	 $file_id = $training_pop_id . '-' . $selection_pop_id. '-' . $sindex_wts;
	     }
	     else
	     {
		 $file_id = $training_pop_id . '-' . $sindex_wts; 
	     }
	     
	    
	 }
	 elsif ($sindex_name) 
	 {
	    $file_id = $sindex_name; 
	 }
	 else 
	 {
	     if ($selection_pop_id && $training_pop_id !~ /^$selection_pop_id$/)
	     {
		 $file_id = $training_pop_id . '-' . $selection_pop_id; 
	     } else 
	     {
		 $file_id = $training_pop_id; 
	     }
	 }   
    }
    else 
    {
	$file_id = $training_pop_id;
    }

    if ($data_structure =~ /list/) 
    {
    	$file_id = "list_${list_id}";
    }
    elsif ($data_structure =~ /dataset/) 
    {
    	$file_id = "dataset_${dataset_id}";
    }
       
    $file_id = $data_type ? $file_id . '-' . $data_type : $file_id;
    $file_id = $k_number  ? $file_id . '-' . $k_number : $file_id;
    $file_id = $file_id . '-' . $traits_selection_id if $traits_selection_id && (!$sindex_name && !$sindex_wts);
    $file_id = $file_id . '-' . $traits_ids[0] if @$traits_ids & @$traits_ids == 1;
    $file_id = $file_id . '-' . $sel_prop if $sel_prop;
    
    $c->stash->{file_id} = $file_id;
    
}


sub format_cluster_output_url {
    my ($self, $c, $path) = @_;

    my $pop_id = $c->stash->{pop_id};
    
    my $host = $c->req->base;

    if ( $host !~ /localhost/)
    {
	$host =~ s/:\d+//; 
	$host =~ s/http\w?/https/;
    }

    my $end = substr($path, -1, 1);
    my $front = substr($path, 0, 1);

    $path = $path . '/' if $end !~ /\//;
    $path =~ s/\///  if $front =~ /\//;
   
    my $output_link = $host . $path . $pop_id;
      
    return $output_link;
}


sub create_tempfile {
    my ($self, $dir, $name, $ext) = @_;
    
    $ext = '.' . $ext if $ext;
    
    my ($fh, $file) = tempfile($name . "-XXXXX", 
			       SUFFIX => $ext,
                               DIR => $dir,
        );
    
    $fh->close;
    
    return $file;

}


sub copy_file {
    my ($self, $file, $dir) = @_;
    
    mkpath($dir, 0, 755);
    
    copy($file, $dir) 
	or die "could not copy $file to $dir"; 

    return catfile($dir, basename($file));
}


sub grep_file {
    my ($self, $dir, $exp) = @_;

    opendir my $dh, $dir 
        or die "can't open $dir: $!\n";

    my ($file)  = grep { /^$exp/ && -f "$dir/$_" }  readdir($dh);
    close $dh;
   
    if ($file)    
    {
        $file = catfile($dir, $file);
    }
 
    return $file;
}


sub get_solgs_dirs {
    my ($self, $c) = @_;
        
    my $geno_version    = $c->config->{default_genotyping_protocol}; 
    $geno_version       = 'analysis-data' if ($geno_version =~ /undefined/) || !$geno_version;    
    $geno_version       =~ s/\s+//g;
    my $tmp_dir         = $c->site_cluster_shared_dir;    
    $tmp_dir            = catdir($tmp_dir, $geno_version);
    my $solgs_dir       = catdir($tmp_dir, "solgs");
    my $solgs_cache     = catdir($tmp_dir, 'solgs', 'cache'); 
    my $solgs_tempfiles = catdir($tmp_dir, 'solgs', 'tempfiles');
    my $solqtl_cache    = catdir($tmp_dir, 'solqtl', 'cache');
    my $solqtl_tempfiles = catdir($tmp_dir, 'solqtl', 'tempfiles');  
    my $solgs_lists     = catdir($tmp_dir, 'solgs', 'tempfiles', 'lists');
    my $solgs_datasets  = catdir($tmp_dir, 'solgs', 'tempfiles', 'datasets');
    my $histogram_cache = catdir($tmp_dir, 'histogram', 'cache');
    my $histogram_temp  = catdir($tmp_dir, 'histogram', 'tempfiles');
    my $log_dir         = catdir($tmp_dir, 'log', 'cache');
    my $anova_cache     = catdir($tmp_dir, 'anova', 'cache');
    my $anova_temp      = catdir($tmp_dir, 'anova', 'tempfiles');
    my $corre_cache     = catdir($tmp_dir, 'correlation', 'cache');
    my $corre_temp      = catdir($tmp_dir, 'correlation', 'tempfiles');
    my $pca_cache       = catdir($tmp_dir, 'pca', 'cache');
    my $pca_temp        = catdir($tmp_dir, 'pca', 'tempfiles');
    my $cluster_cache   = catdir($tmp_dir, 'cluster', 'cache');
    my $cluster_temp    = catdir($tmp_dir, 'cluster', 'tempfiles');
    my $sel_index_cache = catdir($tmp_dir, 'selectionIndex', 'cache');
    my $sel_index_temp  = catdir($tmp_dir, 'selectionIndex', 'tempfiles');

    mkpath (
	[
	 $solgs_dir, $solgs_cache, $solgs_tempfiles, $solgs_lists,  $solgs_datasets, 
	 $pca_cache, $pca_temp, $histogram_cache, $histogram_temp, $log_dir, $corre_cache, $corre_temp,
	 $anova_temp,$anova_cache, $solqtl_cache, $solqtl_tempfiles,
	 $cluster_cache, $cluster_temp, $sel_index_cache,  $sel_index_temp,
	], 
	0, 0755
	);
   
    $c->stash(solgs_dir                   => $solgs_dir, 
              solgs_cache_dir             => $solgs_cache, 
              solgs_tempfiles_dir         => $solgs_tempfiles,
              solgs_lists_dir             => $solgs_lists,
	      solgs_datasets_dir          => $solgs_datasets,
	      pca_cache_dir               => $pca_cache,
	      pca_temp_dir                => $pca_temp,
	      cluster_cache_dir           => $cluster_cache,
	      cluster_temp_dir            => $cluster_temp,
              correlation_cache_dir       => $corre_cache,
	      correlation_temp_dir        => $corre_temp,
	      histogram_cache_dir         => $histogram_cache,
	      histogram_temp_dir          => $histogram_temp,
	      analysis_log_dir            => $log_dir,
              anova_cache_dir             => $anova_cache,
	      anova_temp_dir              => $anova_temp,
	      solqtl_cache_dir            => $solqtl_cache,
              solqtl_tempfiles_dir        => $solqtl_tempfiles,
	      cache_dir                   => $solgs_cache,
	      selection_index_cache_dir   => $sel_index_cache,
	      selection_index_temp_dir    => $sel_index_temp,

        );

}


###
1;#
##
 

package SGN::Controller::solGS::pca;

use Moose;
use namespace::autoclean;

use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;
use Scalar::Util qw /weaken reftype/;

use CXGN::List;


BEGIN { extends 'Catalyst::Controller' }


sub pca_analysis :Path('/pca/analysis/') Args() {
    my ($self, $c, $id) = @_;

    $c->stash->{pop_id} = $id;

    my $referer = $c->req->referer;

    unless($id =~ /dataset|list/) 
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $id); 
	my $combo_pops_list = $c->stash->{combined_pops_list};

	if ($combo_pops_list) 
	{
	    $c->stash->{data_set_type} = 'combined_populations';	
	}
    }
    
    $c->stash->{template} = '/solgs/pca/index.mas';

}


sub check_result :Path('/pca/check/result/') Args() {
    my ($self, $c) = @_;

    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $list_id          = $c->req->param('list_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');
    my $pca_share_id     = $c->req->param('pca_share_id');
    my $file_id;

    my $referer = $c->req->referer;
  
    if ($referer =~ /solgs\/selection\//)
    {
	if ($training_pop_id && $selection_pop_id) 
	{
	    my @pops_ids = ($training_pop_id, $selection_pop_id);
	    $c->stash->{pops_ids_list} = \@pops_ids;
	    $c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	    $c->stash->{pop_id} =  $c->stash->{combo_pops_id};
	    $file_id = $c->stash->{combo_pops_id};
	}
    } 
    elsif ($list_id)
    {
	$c->stash->{pop_id} = $list_id;
		
	$list_id =~ s/list_//;		   	
	my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });

	my $list_type =  $list->type();
	$c->stash->{list_id}   = $list_id;
	$c->stash->{list_type} = $list_type;
	$c->stash->{list_name} = $list->name();
	 
	if ($list_type =~ /trials/)
	{
	    $c->controller('solGS::List')->get_trials_list_ids($c);
	    $c->stash->{pops_ids_list} =  $c->stash->{trials_ids};
	    $c->controller('solGS::List')->process_trials_list_details($c);
	    
	    $c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	    $c->stash->{pop_id} =  $c->stash->{combo_pops_id};
	    $file_id = $c->stash->{combo_pops_id};
	}	
    }
    elsif ($referer =~ /solgs\/model\/combined\/populations\//  && $combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$file_id = $combo_pops_id;

	$c->controller('solGS::List')->process_trials_list_details($c);
    }
 
    else 
    {
	$c->stash->{pop_id} = $training_pop_id;
	$file_id = $training_pop_id;	
    }

    $file_id = $pca_share_id if !$file_id;
    $c->stash->{file_id} = $file_id ;
    my $ret->{result} = 0;
    
    if ($self->check_pca_output($c))
    {
	$ret = $c->stash->{formatted_pca_output};
	$ret->{result} = 1;
	$ret->{list_id} = $list_id;
	$ret->{pop_id}  = $file_id;
	$ret->{list_name} = $c->stash->{list_name};
	$ret->{trials_names} = $c->stash->{trials_names};
	$ret->{combo_pops_id} = $combo_pops_id; 
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub pca_run :Path('/pca/run/') Args() {
    my ($self, $c) = @_;
    
    my $training_pop_id  = $c->req->param('training_pop_id');
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $combo_pops_id    = $c->req->param('combo_pops_id');

    my $list_id     = $c->req->param('list_id');
    my $list_type   = $c->req->param('list_type');
    my $list_name   = $c->req->param('list_name');
    my $referer     = $c->req->referer;
    
    my $pop_id;
    my $file_id;
    my $trials_names;
    
    if ($referer =~ /solgs\/selection\//)
    {
	$c->stash->{pops_ids_list} = [$training_pop_id, $selection_pop_id];
	$c->controller('solGS::List')->register_trials_list($c);
	$combo_pops_id =  $c->stash->{combo_pops_id};
	$c->stash->{pop_id} =  $combo_pops_id;
	$file_id = $combo_pops_id;
    }
    elsif ($referer =~ /pca\/analysis\/|\/solgs\/model\/combined\/populations\// && $combo_pops_id)
    {
	 $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
	 $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	 $c->stash->{pop_id} = $combo_pops_id;
	 $c->stash->{combo_pops_id} = $combo_pops_id;
	 $file_id = $combo_pops_id;
	 $c->stash->{data_set_type} = 'combined_populations';
	 
	 $c->controller('solGS::List')->process_trials_list_details($c);
	 $trials_names = $c->stash->{trials_names};
    } 
    else 
    {
	$c->stash->{pop_id} = $training_pop_id;
	$file_id = $training_pop_id;
	$pop_id  = $training_pop_id;
    }

    $c->stash->{training_pop_id}  = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;

    if ($list_id) 
    {
	$c->stash->{data_set_type} = 'list';
	$c->stash->{list_id}       = $list_id;
	$c->stash->{list_type}     = $list_type;
	$file_id = 'list_' . $list_id if $list_id !~ /list/;

	$c->controller('solGS::List')->create_list_population_metadata_file($c, $file_id);
	if ($list_type =~ /trial/)
	{
	    $c->controller('solGS::List')->get_trials_list_ids($c);
	    $c->stash->{pops_ids_list} = $c->stash->{trials_ids};	    
	    $c->controller('solGS::List')->process_trials_list_details($c);
	    $trials_names = $c->stash->{trials_names};
	}		
    }
    
    $c->stash->{file_id} = $file_id;

    my $ret->{status} = 'PCA analysis failed';
   
    if (!$self->check_pca_output($c)) 
    {
	$self->create_pca_genotype_data($c);
	
	if (!$c->stash->{genotype_files_list} && !$c->stash->{genotype_file}) 
	{	  
	    $ret->{status} = 'There is no genotype data. Aborted PCA analysis.';                
	}
	else 
	{ 
	    $self->run_pca($c);
	    $self->format_pca_output($c);
	}
	
    }

    $ret = $c->stash->{formatted_pca_output};
    $ret->{pop_id} = $c->stash->{pop_id};
    $ret->{trials_names} = $trials_names;
   
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}

sub check_pca_output {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};

    if ($file_id)
    {
	$self->format_pca_output($c);
	my $pca_output = $c->stash->{formatted_pca_output};

	if (ref($pca_output) eq 'HASH') 
	{
	    return 1;
	}
	else
	{
	    return 0;
	}
    }

}


sub format_pca_output {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};

    if ($file_id)
    {
	$self->pca_scores_file($c);
	my $pca_scores_file = $c->stash->{pca_scores_file};

	$self->pca_variance_file($c);
	my $pca_variance_file = $c->stash->{pca_variance_file};
	
	if ( -s $pca_scores_file && -s $pca_variance_file)
	{
	    my $ret->{status} = undef;
	    my $pca_scores    = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $pca_scores_file);
	    my $pca_variances = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $pca_variance_file);

	    my $host = $c->req->base;

	    if ( $host !~ /localhost/)
	    {
		$host =~ s/:\d+//; 
		$host =~ s/http\w?/https/;
	    }
	    
	    my $output_link = $host . 'pca/analysis/' . $file_id;
	    #$c->controller('solGS::List')->process_trials_list_details($c);
	    if ($pca_scores)
	    {
		$ret->{pca_scores} = $pca_scores;
		$ret->{pca_variances} = $pca_variances;
		$ret->{status} = 'success';  
		$ret->{pop_id} = $file_id;# if $list_type eq 'trials';
		#$ret->{trials_names} = $c->stash->{trials_names};
		$ret->{output_link}  = $output_link;
	    }

	    $c->stash->{formatted_pca_output} = $ret;
	}
	else
	{
	    $c->stash->{formatted_pca_output} = undef;
	}
    }
    else
    {
	die "Required file id argument missing.";	
    }
    
}

sub download_pca_scores : Path('/download/pca/scores/population') Args(1) {
    my ($self, $c, $file_id) = @_;
   
    my $pca_dir = $c->stash->{pca_cache_dir};
    my $pca_file = catfile($pca_dir,  "pca_scores_${file_id}.txt");
  
    unless (!-e $pca_file || -s $pca_file <= 1) 
    {
	my @pca_data;
	my $count=1;

	foreach my $row ( read_file($pca_file) )
	{
	    if ($count==1) {  $row = 'Individuals' . $row;}             
	    $row = join(",", split(/\s/, $row));
	    $row .= "\n";
 
	    push @pca_data, [ $row ];
	    $count++;
	}
   
	$c->res->content_type("text/plain");
	$c->res->body(join "",  map{ $_->[0] } @pca_data);   
    }  
}


sub pca_genotypes_list :Path('/pca/genotypes/list') Args(0) {
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
    $self->create_pca_genotype_data($c);

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


sub format_pca_scores {
   my ($self, $c) = @_;

   my $file = $c->stash->{pca_scores_file};
   my $data = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $file);
  
   $c->stash->{pca_scores} = $data;

}


sub create_pca_genotype_data {    
    my ($self, $c) = @_;
   
    my $data_set_type = $c->stash->{data_set_type};

    if ($data_set_type =~ /list/) 
    {
	$self->pca_list_genotype_data($c);	
    }
    else
    {
	my $combo_pops_id = $c->stash->{combo_pops_id};
	
	if ($combo_pops_id)
	{
	    $c->controller('solGS::combinedTrials')->cache_combined_pops_data($c);
	    $c->stash->{genotype_file} = $c->stash->{trait_combined_geno_file};
	    my $geno_file = $c->stash->{genotype_file};
	}
	else 
	{
	    $c->controller('solGS::solGS')->genotype_file($c);
	}

    }

}


sub pca_list_genotype_data {
    my ($self, $c) = @_;
    
    my $list_id = $c->stash->{list_id};
    my $list_type = $c->stash->{list_type};
    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};

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
	$c->stash->{pops_ids_list} = [$c->stash->{training_pop_id},  $c->stash->{selection_pop_id}];
	$c->controller('solGS::solGS')->genotype_file($c);
	$c->controller('solGS::List')->process_trials_list_details($c);
    }
    elsif ($referer =~ /pca\/analysis\// && $data_set_type =~ 'combined_populations')
    {
    	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $c->stash->{combo_pops_id});
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$c->controller('solGS::List')->get_trials_list_geno_data($c);
	$c->controller('solGS::List')->process_trials_list_details($c);
    }	   
    else
    {
	if ($list_type eq 'accessions') 
	{
	    $c->controller('solGS::List')->genotypes_list_genotype_file($c, $pop_id);
	} 
	elsif ( $list_type eq 'trials') 
	{
	    $c->controller('solGS::List')->get_trials_list_ids($c);
	    $c->stash->{pops_ids_list} = $c->stash->{trials_ids};
	    $c->controller('solGS::List')->get_trials_list_geno_data($c);
	    $c->controller('solGS::List')->process_trials_list_details($c);
	}
    }

}


sub pca_scores_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
    my $pca_dir = $c->stash->{pca_cache_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_scores_${file_id}",
                      file      => "pca_scores_${file_id}.txt",
                      stash_key => 'pca_scores_file'
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub pca_variance_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
    my $pca_dir = $c->stash->{pca_cache_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_variance_${file_id}",
                      file      => "pca_variance_${file_id}.txt",
                      stash_key => 'pca_variance_file'
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub pca_loadings_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
    my $pca_dir = $c->stash->{pca_cache_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_loadings_${file_id}",
                      file      => "pca_loadings_${file_id}.txt",
                      stash_key => 'pca_loadings_file'
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub pca_output_files {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{file_id};
     
    $self->pca_scores_file($c);
    $self->pca_loadings_file($c);
    $self->pca_variance_file($c);
    $self->combined_pca_trials_data_file($c);

    my $file_list = join ("\t",
                          $c->stash->{pca_scores_file},
                          $c->stash->{pca_loadings_file},
			  $c->stash->{pca_variance_file},
			  $c->stash->{combined_pca_data_file},
	);
     
    
    my $tmp_dir = $c->stash->{pca_temp_dir};
    my $name = "pca_output_files_${file_id}"; 
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name); 
    write_file($tempfile, $file_list);
    
    $c->stash->{pca_output_files} = $tempfile;

}


sub combined_pca_trials_data_file {
    my ($self, $c) = @_;
    
    my $file_id = $c->stash->{file_id};
    my $tmp_dir = $c->stash->{pca_temp_dir};
    my $name = "combined_pca_data_file_${file_id}"; 
    my $tempfile =  $c->controller('solGS::Files')->create_tempfile($tmp_dir, $name);
    
    $c->stash->{combined_pca_data_file} = $tempfile;
    
}


sub pca_input_files {
    my ($self, $c) = @_;
          
    my $file_id = $c->stash->{file_id};
    my $tmp_dir = $c->stash->{pca_temp_dir};
    
    my $name     = "pca_input_files_${file_id}"; 
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
    
    $c->stash->{pca_input_files} = $tempfile;

}


sub run_pca {
    my ($self, $c) = @_;
    
    my $pop_id  = $c->stash->{pop_id};
    my $file_id = $c->stash->{file_id};
    
    $self->pca_output_files($c);
    my $output_file = $c->stash->{pca_output_files};

    $self->pca_input_files($c);
    my $input_file = $c->stash->{pca_input_files};

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{pca_temp_dir};
    
    $c->stash->{input_files}  = $input_file;
    $c->stash->{output_files} = $output_file;
    $c->stash->{r_temp_file}  = "pca-${file_id}";
    $c->stash->{r_script}     = 'R/solGS/pca.r';
    
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

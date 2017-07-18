package SGN::Controller::solGS::pca;

use Moose;
use namespace::autoclean;

use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;

use CXGN::List;


BEGIN { extends 'Catalyst::Controller' }


sub pca_analysis :Path('/pca/analysis/') Args(0) {
    my ($self, $c) = @_;
    
    $c->stash->{template} = '/pca/analysis.mas';

}


sub check_result :Path('/pca/check/result/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;

    $self->pca_scores_file($c);
    my $pca_scores_file = $c->stash->{pca_scores_file};
 
    my $ret->{result} = undef;
   
    if (-s $pca_scores_file && $pop_id =~ /\d+/) 
    {
	$ret->{result} = 1;                
    }    

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub pca_result :Path('/pca/result/') Args(1) {
    my ($self, $c, $pop_id) = @_;
    
    $c->stash->{pop_id} = $pop_id || $c->req->param('population_id');

    my $list_id     = $c->req->param('list_id');
    my $list_type   = $c->req->param('list_type');
    my $list_name   = $c->req->param('list_name');

    if ($list_id) 
    {
	$c->stash->{data_set_type} = 'list';
	$c->stash->{list_id}       = $list_id;
	$c->stash->{list_type}     = $list_type;
    }
   
    $self->create_pca_genotype_data($c);
    
    my @genotype_files_list;
    my $geno_file;
    if ($c->stash->{genotype_files_list}) 
    {
	@genotype_files_list = @{$c->stash->{genotype_files_list}};
	$geno_file = $genotype_files_list[0] if !$genotype_files_list[1];
    }
    else 
    {
	$geno_file = $c->stash->{genotype_file};
    }

    $self->pca_scores_file($c);
    my $pca_scores_file = $c->stash->{pca_scores_file};

    $self->pca_variance_file($c);
    my $pca_variance_file = $c->stash->{pca_variance_file};
 
    my $ret->{status} = 'PCA analysis failed.';
    if( !-s $pca_scores_file) 
    {
	if (!-s $geno_file )
	{
	    $ret->{status} = 'There is no genotype data. Aborted PCA analysis.';                
	}
	else 
	{
	    $self->run_pca($c);	
	}
    }
    
    my $pca_scores = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $pca_scores_file);
    my $pca_variances = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $pca_variance_file);
   
    if ($pca_scores)
    {
        $ret->{pca_scores} = $pca_scores;
	$ret->{pca_variances} = $pca_variances;
        $ret->{status} = 'success';  
	$ret->{pop_id} = $c->stash->{pop_id} if $list_type eq 'trials';
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub download_pca_scores : Path('/download/pca/scores/population') Args(1) {
    my ($self, $c, $id) = @_;
    
    $self->create_pca_dir($c);
    my $pca_dir = $c->stash->{pca_dir};
    my $pca_file = catfile($pca_dir,  "pca_scores_${id}");
  
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
	$self->_pca_list_genotype_data($c);
	
    }
    else 
    {
	$self->_pca_trial_genotype_data($c);
    }

}


sub _pca_list_genotype_data {
    my ($self, $c) = @_;
    
    my $list_id = $c->stash->{list_id};
    my $list_type = $c->stash->{list_type};
    my $pop_id = $c->stash->{pop_id};

    my $referer = $c->req->referer;
    my $geno_file;
    
    if ($referer =~ /solgs\/trait\/\d+\/population\/|solgs\/selection\//) 
    {
	$c->controller('solGS::solGS')->genotype_file_name($c, $pop_id);
	$geno_file  = $c->stash->{genotype_file_name};
	$c->stash->{genotype_file} = $geno_file;
 
    }	   
    else
    {
	if ($list_type eq 'accessions') 
	{

	    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
	    my @genotypes_list = @{$list->elements};

	    $c->stash->{genotypes_list} = \@genotypes_list;	   
	    my $geno_data = $c->model('solGS::solGS')->genotypes_list_genotype_data(\@genotypes_list);
	    
	    my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};
	    my $file = "genotype_data_uploaded_${list_id}";     
	    $file = $c->controller("solGS::solGS")->create_tempfile($tmp_dir, $file);    
	    
	    write_file($file, $geno_data);
	    $c->stash->{genotype_file} = $file; 
	    
	} 
	elsif ( $list_type eq 'trials') 
	{
	    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
	    my @trials_list = @{$list->elements};
	
	    my @genotype_files;
	    foreach (@trials_list) 
	    {
		my $trial_id = $c->model("solGS::solGS")
		    ->project_details_by_name($_)
		    ->first
		    ->project_id;

		$c->stash->{pop_id} = $trial_id; 
		$self->_pca_trial_genotype_data($c);
		push @genotype_files, $c->stash->{genotype_file};
	    }

	    $c->stash->{genotype_files_list} = \@genotype_files;
	}
    }

}


sub _pca_trial_genotype_data {
    my ($self, $c) = @_;
  
    my $referer = $c->req->referer;
    my $pop_id = $c->stash->{pop_id};

    my $geno_file;
 
    if ($referer =~ /solgs\/selection\//) 
    {
	$c->stash->{selection_pop_id} = $c->stash->{pop_id};	   
	$c->controller('solGS::solGS')->filtered_selection_genotype_file($c, $pop_id);
	$geno_file = $c->stash->{filtered_selection_genotype_file};
    }
    else
    {
	$c->stash->{training_pop_id} = $c->stash->{pop_id};	   
	$c->controller('solGS::solGS')->filtered_training_genotype_file($c, $pop_id);
	$geno_file = $c->stash->{filtered_training_genotype_file};

    }

    if (!-s $geno_file) 
    {
	$c->controller('solGS::solGS')->genotype_file_name($c, $pop_id);
	$geno_file = $c->stash->{genotype_file_name};
    }

    if (-s $geno_file)
    {    
	$c->stash->{genotype_file} = $geno_file;
    }
    else
    {	
	$c->controller("solGS::solGS")->genotype_file($c);
    }
   
}

sub create_pca_dir {
    my ($self, $c) = @_;
     
    $c->controller("solGS::solGS")->get_solgs_dirs($c);

}


sub pca_scores_file {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    $self->create_pca_dir($c);
    my $pca_dir = $c->stash->{pca_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_scores_${pop_id}",
                      file      => "pca_scores_${pop_id}",,
                      stash_key => 'pca_scores_file'
    };

    $c->controller("solGS::solGS")->cache_file($c, $cache_data);

}


sub pca_variance_file {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    $self->create_pca_dir($c);
    my $pca_dir = $c->stash->{pca_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_variance_${pop_id}",
                      file      => "pca_variance_${pop_id}",,
                      stash_key => 'pca_variance_file'
    };

    $c->controller("solGS::solGS")->cache_file($c, $cache_data);

}


sub pca_loadings_file {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    $self->create_pca_dir($c);
    my $pca_dir = $c->stash->{pca_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_loadings_${pop_id}",
                      file      => "pca_loadings_${pop_id}",,
                      stash_key => 'pca_loadings_file'
    };

    $c->controller("solGS::solGS")->cache_file($c, $cache_data);

}


sub pca_output_files {
    my ($self, $c) = @_;
     
    $self->pca_scores_file($c);
    $self->pca_loadings_file($c);
    $self->pca_variance_file($c);

    my $file_list = join ("\t",
                          $c->stash->{pca_scores_file},
                          $c->stash->{pca_loadings_file},
			  $c->stash->{pca_variance_file},
	);
     
    my $pop_id = $c->stash->{pop_id};
    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};
    my $name = "pca_output_files_${pop_id}"; 
    my $tempfile =  $c->controller("solGS::solGS")->create_tempfile($tmp_dir, $name); 
    write_file($tempfile, $file_list);
    
    $c->stash->{output_files} = $tempfile;

}


sub run_pca {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    my $pca_output_file = $self->pca_output_files($c);
    my $geno_file = $c->stash->{genotype_file};

    $c->stash->{input_files}  = $geno_file;
    $c->stash->{output_files} = $pca_output_file;
    $c->stash->{r_temp_file}  = "pca-${pop_id}";
    $c->stash->{r_script}     = 'R/solGS/pca.r';

    $c->controller("solGS::solGS")->run_r_script($c);
    
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####

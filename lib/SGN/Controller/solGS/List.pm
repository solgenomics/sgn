=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 DESCRIPTION

SGN::Controller::solGS::List - Controller for list based training and selection populations

=cut


package SGN::Controller::solGS::List;

use Moose;
use namespace::autoclean;

use List::MoreUtils qw /uniq/;
use CXGN::Tools::Run;
use JSON;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use String::CRC;
use Try::Tiny;
use POSIX qw(strftime);

BEGIN { extends 'Catalyst::Controller' }



sub generate_check_value :Path('/solgs/generate/checkvalue') Args(0) {
    my ($self, $c) = @_;
    
    my $file_name = $c->req->param('string');
    my $check_value = crc($file_name);

    my $ret->{status} = 'failed';
    
    if ($check_value) 
    {
        $ret->{status} = 'success';
        $ret->{check_value} = $check_value;
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub upload_prediction_genotypes_list :Path('/solgs/upload/prediction/genotypes/list') Args(0) {
    my ($self, $c) = @_;
    
    my $list_id    = $c->req->param('id');
    my $list_name  = $c->req->param('name');   
    my $list       = $c->req->param('list');
  
    $list =~ s/\\//g;
    $list = from_json($list);
 
    $c->stash->{list_name} = $list_name;
    $c->stash->{list_id}   = $list_id;
    
    my @stocks_names = ();  
    foreach my $stock (@$list)
    {
        push @stocks_names, $stock->[1];
    }
    
    @stocks_names = uniq(@stocks_names);
    $c->stash->{genotypes_list} = \@stocks_names;
    my $data = $c->model('solGS::solGS')->genotypes_list_genotype_data(\@stocks_names);
    $c->stash->{genotypes_list_genotype_data} = $data;   
    $self->genotypes_list_genotype_data_file($c);   
    my $genotype_file = $c->stash->{genotypes_list_genotype_data_file};

    $c->stash->{prediction_pop_id} = $list_id;
    $self->create_list_population_metadata_file($c);

    my $ret->{status} = 'failed';
    
    if (-s $genotype_file) 
    {
        $ret->{status} = 'success';
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub solgs_list_login_message :Path('/solgs/list/login/message') Args(0) {
    my ($self, $c) = @_;

    my $page = $c->req->param('page');

    my $message = "This is a private data. If you are the owner, "
	. "please <a href=\"/solpeople/login.pl?goto_url=$page\">login</a> to view it.";

    $c->stash->{message} = $message;

    $c->stash->{template} = "/generic_message.mas"; 
   
}


sub get_trial_id :Path('/solgs/get/trial/id') Args(0) {
    my ($self, $c) = @_;
    
    my @trials_names = $c->req->param('trials_names[]');

    my $tr_rs = $c->model('solGS::solGS')->project_details_by_exact_name(\@trials_names);

    my @trials_ids;
    
    while (my $rw = $tr_rs->next) 
    {
	push @trials_ids, $rw->project_id;
    }
 
    my  $ret->{trials_ids} = \@trials_ids;
           
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_selection_genotypes_list_from_file {
    my ($self, $file) = @_;
    my @clones;

    open my $fh, $file or die "Can't open file $file: $!";

    while (<$fh>) 
    {
        $_ =~ s/\n//;
        push @clones, $_;
    }

    return \@clones;

}


sub genotypes_list_genotype_data_file {
    my ($self, $c) = @_;
    
    my $geno_data = $c->stash->{genotypes_list_genotype_data};
            
    $self->create_list_pop_tempfiles($c);
    my $file = $c->stash->{geno_data_tmp_file};
    write_file($file, $geno_data);

    $c->stash->{genotypes_list_genotype_data_file} = $file;
  
}


sub create_list_pop_tempfiles {
    my ($self, $dir, $model_id) = @_;

    my $pheno_name = "phenotype_data_${model_id}.txt";
    my $geno_name  = "genotype_data_${model_id}.txt";

    my $pheno_file = catfile($dir, $pheno_name);
    my $geno_file  = catfile($dir, $geno_name);
      
    my $files = { pheno_file => $pheno_file, geno_file => $geno_file};

    return $files;

}


sub create_list_population_metadata {
    my ($self, $c) = @_;
    my $metadata = 'key' . "\t" . 'value';
    $metadata .= "\n" . 'user_id' . "\t" . $c->user->id;
    $metadata .= "\n" . 'list_name' . "\t" . $c->{stash}->{list_name};
    $metadata .= "\n" . 'description' . "\t" . 'Uploaded on: ' . strftime "%a %b %e %H:%M %Y", localtime;
    
    $c->stash->{user_list_population_metadata} = $metadata;
  
}


sub create_list_population_metadata_file {
    my ($self, $c) = @_;
      
    my $tmp_dir          = $c->stash->{solgs_prediction_upload_dir};
    my $model_id         = $c->stash->{model_id};
    $c->stash->{pop_id}  = $model_id;
    my $selection_pop_id = $c->stash->{prediction_pop_id};   
    my $user_id          = $c->user->id;
  
    $self->create_list_population_metadata($c);
    my $metadata = $c->stash->{user_list_population_metadata};
   
    my $file;
    if ($model_id) 
    {              
        $file = catfile ($tmp_dir, "metadata_${user_id}_${model_id}");
    }

    if ($selection_pop_id) 
    { 
        $file = catfile ($tmp_dir, "metadata_${user_id}_${selection_pop_id}");
    }

    write_file($file, $metadata);
 
    $c->stash->{user_list_population_metadata_file} = $file;
  
}


sub user_uploaded_prediction_population :Path('/solgs/model') Args(4) {
    my ($self, $c, $model_id,  $uploaded, $prediction, $prediction_pop_id) = @_;

    my $referer = $c->req->referer;
    my $base    = $c->req->base;
    $referer    =~ s/$base//;
    my $path    = $c->req->path;
    $path       =~ s/$base//;
    my $page    = "solgs/model/combined/populations/";
   
    my $ret->{status} = 'failed';
    
    if ($referer =~ m/$page/)
    {
        my $trait_id = $c->req->param('trait_id');
        my $combo_pops_id = $model_id;
        my $uploaded_prediction = $c->req->param('uploaded_prediction');
        my $list_source = $c->req->param('list_source');
      
        $c->stash->{data_set_type}       = "combined populations"; 
        $c->stash->{combo_pops_id}       = $model_id;
        $c->stash->{model_id}            = $model_id;                          
        $c->stash->{prediction_pop_id}   = $prediction_pop_id;  
        $c->stash->{uploaded_prediction} = $uploaded_prediction;
        $c->stash->{list_source}         = $list_source;

        $c->controller("solGS::solGS")->get_trait_details($c, $trait_id);
        my $trait_abbr = $c->stash->{trait_abbr};

        my $identifier = $combo_pops_id. '_uploaded_' . $prediction_pop_id;
        $c->controller("solGS::solGS")->prediction_pop_gebvs_file($c, $identifier, $trait_id);
      
        my $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
      
        if ( ! -s $prediction_pop_gebvs_file )
        {
           my $dir = $c->stash->{solgs_cache_dir};
          
           my $exp = "phenotype_data_${model_id}_${trait_abbr}"; 
           my $pheno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);

           $exp = "genotype_data_${model_id}_${trait_abbr}"; 
           my $geno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);

           $c->stash->{trait_combined_pheno_file} = $pheno_file;
           $c->stash->{trait_combined_geno_file}  = $geno_file;
           
           $self->user_prediction_population_file($c, $prediction_pop_id);
           my $selection_pop_file = $c->stash->{genotypes_list_genotype_data_file};
          
           $c->controller("solGS::solGS")->compare_genotyping_platforms($c, [$geno_file, $selection_pop_file]);
           my $no_match = $c->stash->{pops_with_no_genotype_match};
           
           if(!$no_match)
           {
               $c->controller("solGS::solGS")->get_rrblup_output($c); 
           }
           else 
           {
               $ret->{status} = 'The selection population was genotyped by a set of markers different from the ones used for the training population. Therefore, you can\'t use this prediction model on it.';   
                     
           }

        }
        
        $c->controller("solGS::solGS")->gs_files($c);   
        $c->controller("solGS::solGS")->download_prediction_urls($c, $combo_pops_id,  $prediction_pop_id );
        my $download_prediction = $c->stash->{download_prediction};
        
        if (-s $prediction_pop_gebvs_file) 
        {
            $ret->{status} = 'success';
            $ret->{output} = $download_prediction;
        }
              
        $ret = to_json($ret);
       
        $c->res->content_type('application/json');
        $c->res->body($ret);
       
    }
    elsif ($referer =~ /solgs\/(trait|traits)\//) 
    {
        my $trait_id = $c->req->param('trait_id');
        my $uploaded_prediction = $c->req->param('uploaded_prediction');
        my $list_source = $c->req->param('list_source');

        $c->stash->{data_set_type}       = "single population"; 
        $c->stash->{pop_id}              = $model_id;
        $c->stash->{model_id}            = $model_id;                          
        $c->stash->{prediction_pop_id}   = $prediction_pop_id;  
        $c->stash->{uploaded_prediction} = $uploaded_prediction;
        $c->stash->{list_source}         = $list_source;
        $c->stash->{page_trait_id}       = $trait_id;
        
	my @analyzed_traits;
       
        if ($uploaded_prediction) 
        {
            $c->controller("solGS::solGS")->analyzed_traits($c);
            @analyzed_traits = @{ $c->stash->{analyzed_traits} };            
         }

        my $prediction_pop_gebvs_file;

        foreach my $trait_name (@analyzed_traits) 
        {    
            my $acronym_pairs = $c->controller("solGS::solGS")->get_acronym_pairs($c);
            
            if ($acronym_pairs)
            {
                foreach my $r (@$acronym_pairs) 
                 {
                     if ($r->[0] eq $trait_name) 
                     {
                         $trait_name = $r->[1];
                         $trait_name =~ s/\n//g;
                     }
                 }
             }

             $trait_id =  $c->model("solGS::solGS")->get_trait_id($trait_name);
             $c->controller("solGS::solGS")->get_trait_details($c, $trait_id);
             my $trait_abbr = $c->stash->{trait_abbr};

             my $identifier = $model_id . '_uploaded_' . $prediction_pop_id;
             $c->controller("solGS::solGS")->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        
             $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
      
             if (! -s $prediction_pop_gebvs_file)
             {

                 my ($pheno_file, $geno_file);

                 if ($model_id =~ /uploaded/) 
                 {
                     my $dir     = $c->stash->{solgs_prediction_upload_dir};
                     my $user_id = $c->user->id;
                     
		     my $exp     = "phenotype_data_${model_id}"; 
                     $pheno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);
                
                     $exp       = "genotype_data_${model_id}"; 
                     $geno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);    

                 }
                 else 
                 {
                     my $dir = $c->stash->{solgs_cache_dir};
           
                     my $exp     = "phenotype_data_${model_id}"; 
                     $pheno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);
                    
                     $exp = "genotype_data_${model_id}"; 
                     $geno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);
                 }
                
                 $c->stash->{phenotype_file} = $pheno_file;
                 $c->stash->{genotype_file}  = $geno_file;
                
                 $self->user_prediction_population_file($c, $prediction_pop_id);               
                 my $selection_pop_file = $c->stash->{genotypes_list_genotype_data_file};
                
                 $c->controller("solGS::solGS")->compare_genotyping_platforms($c, [$geno_file, $selection_pop_file]);
                 my $no_match = $c->stash->{pops_with_no_genotype_match};
                
                 if(!$no_match)
                 {
                     $c->controller("solGS::solGS")->get_rrblup_output($c); 
                 }
                 else 
                 {
                     $ret->{status} = 'The selection population was genotyped by a set of markers different from the ones used for the training population. Therefore, this model can not be used to predict the breeding values of this selection population.';   
                     
                 }
             }
         } 
          
        $c->controller("solGS::solGS")->trait_phenotype_stat($c);  
        $c->controller("solGS::solGS")->gs_files($c);               
        
	$c->controller("solGS::solGS")->download_prediction_urls($c, $model_id, $prediction_pop_id );
        my $download_prediction = $c->stash->{download_prediction};
                 
        if (-s $prediction_pop_gebvs_file) 
        {
            $ret->{status} = 'success';
            $ret->{output} = $download_prediction;
        }
        
        $ret = to_json($ret);
       
        $c->res->content_type('application/json');
        $c->res->body($ret);         
    }
}


sub user_prediction_population_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $user_id   = $c->user->id; 
    my $upload_dir = $c->stash->{solgs_prediction_upload_dir};
   
    my ($fh, $tempfile) = tempfile("prediction_population_${pred_pop_id}-XXXXX", 
                                   DIR => $upload_dir
        );

    my $exp = "genotype_data_uploaded_${pred_pop_id}"; 
    my  $pred_pop_file = $c->controller("solGS::solGS")->grep_file($upload_dir, $exp);
 
    $c->stash->{genotypes_list_genotype_data_file} = $pred_pop_file;
   
    $fh->print($pred_pop_file);
    $fh->close; 

    $c->stash->{prediction_population_file} = $tempfile;
  
}


sub get_list_elements_names {
    my ($self, $c) = @_;

    my $list = $c->stash->{list};
 print STDERR "\n pop id:getting list_list elements_names\n";
  

   # $list = from_json($list);

    my @names = ();  
   
    foreach my $id_names (@$list)
    {
        push @names, $id_names->[1];
    }

    $c->stash->{list_elements_names} = \@names;

}


# sub prepare_plots_type_training_data {
#     my ($self, $c) = @_;

#     my $list = $c->stash->{list};
 
#     $self->get_list_elements_names($c, $list);
#     my $plots_names = $c->stash->{list_elements_names};
        
#     my $pheno_data = $c->model('solGS::solGS')->plots_list_phenotype_data($plots_names);
#     $c->stash->{plots_list_phenotype_data} = $pheno_data;
	
#     $c->stash->{plots_names} = $plots_names;
#     $self->map_genotypes_plots($c);	
#     my $genotypes = $c->stash->{genotypes_list}; 

#     my $geno_data = $c->model('solGS::solGS')->genotypes_list_genotype_data($genotypes);
#     $c->stash->{genotypes_list_genotype_data} = $geno_data;
	
#     $self->plots_list_phenotype_data_file($c);
#     $self->genotypes_list_genotype_data_file($c);
#     $self->create_list_population_metadata_file($c);
      
# } 


sub map_genotypes_plots {
    my ($self, $c) = @_;
  
    my  $plots = $c->stash->{plots_names};
   
    if (!@$plots) 
    { 
	die "No plots list provided $!\n"; 
    }
    else
    {
	my $genotypes_rs = $c->model('solGS::solGS')->get_genotypes_from_plots($plots);
	
	my @genotypes;
	while (my $genotype = $genotypes_rs->next) 
	{
	    my $name = $genotype->uniquename;
	    push @genotypes, $name;
	    print STDERR "\n ma-genotypes: $name\n";
	}

	@genotypes = uniq(@genotypes); 
	
	$c->stash->{genotypes_list} = \@genotypes;
    }	    
        
}


sub load_plots_list_training :Path('/solgs/load/plots/list/training') Args(0) {
    my ($self, $c) = @_;
     
    my $args = $c->req->param('arguments');

    my $json = JSON->new();
    $args = $json->decode($args);
  
    $c->stash->{list_name}       = $args->{list_name};
    $c->stash->{list}            = $args->{list};
    $c->stash->{model_id}        = $args->{population_id};
    $c->stash->{population_type} = $args->{population_type};

    $self->plots_list_phenotype_file($c);
    $self->genotypes_list_genotype_file($c);
    
    my $tmp_dir  = $c->stash->{solgs_prediction_upload_dir};
    my $model_id = $c->stash->{model_id};
      print STDERR "\n model id: $model_id\n";
    my $files = $self->create_list_pop_tempfiles($tmp_dir, $model_id);
    my $pheno_file = $files->{pheno_file};
    my $geno_file  =  $files->{geno_file};
 
    $self->create_list_population_metadata_file($c);
 
    my $ret->{status} = 'failed';
    
    if (-s $geno_file && -s $pheno_file) 
    {
        $ret->{status} = 'success';
    }
               
    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub genotypes_list_genotype_data {
    my ($self, $args) = @_;
   
    my $model_id  = $args->{model_id};
    my $genotypes = $args->{genotypes_list};
    my $tmp_dir   = $args->{list_data_dir};
    print STDERR "\n genotypes list geno data --model id: $model_id -- $genotypes->[0]\n";
    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});

    my $geno_data = $model->genotypes_list_genotype_data($genotypes);
   
    my $files = $self->create_list_pop_tempfiles($tmp_dir, $model_id);

    my $geno_file = $files->{geno_file};
    write_file($geno_file, $geno_data);
      
}


sub genotypes_list_genotype_file {
    my ($self, $c) = @_;

    my $model_id = $c->stash->{model_id};
    my $list     = $c->stash->{list}; 

    $self->get_list_elements_names($c);
    my $plots_names = $c->stash->{list_elements_names};

    $c->stash->{plots_names} = $plots_names;
    $self->map_genotypes_plots($c);	
    my $genotypes = $c->stash->{genotypes_list}; 

    my $data_dir = $c->stash->{solgs_prediction_upload_dir};

    my $args = {
	'model_id'       => $model_id,
	'genotypes_list' => $genotypes,	        
	'list_data_dir'  => $data_dir,
    };

    $c->stash->{r_temp_file} = 'genotypes-list-genotype-data-query';
    $c->controller('solGS::solGS')->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;
 
    try 
    { 
        my $geno_job = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["SGN::Controller::solGS::List" => "genotypes_list_genotype_data"],
    	    args          => [$args],
    	    load_packages => ['SGN::Controller::solGS::List', 'SGN::Context', 'SGN::Model::solGS::solGS'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },
	    
         });

	$c->stash->{r_job_tempdir} = $geno_job->tempdir();
	$c->stash->{r_job_id} = $geno_job->job_id();
	$c->stash->{cluster_job} = $geno_job;

	unless ($background_job)
	{
	    $geno_job->wait();
	}
	
    }
    catch 
    {
	$status = $_;
	$status =~ s/\n at .+//s;           
    }; 

}


sub plots_list_phenotype_data {
    my ($self, $args) = @_;
   
    my $model_id    = $args->{model_id};
    my $plots       = $args->{plots_list};
    my $traits_file = $args->{traits_file};
    my $tmp_dir     = $args->{list_data_dir};
   
    my $model = SGN::Model::solGS::solGS->new({schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});
    my $pheno_data = $model->plots_list_phenotype_data($plots);

    $pheno_data = SGN::Controller::solGS::solGS->format_phenotype_dataset($pheno_data, $traits_file);
    
    my $files = $self->create_list_pop_tempfiles($tmp_dir, $model_id);

    my $pheno_file = $files->{pheno_file};
    
    write_file($pheno_file, $pheno_data);
      
}


sub plots_list_phenotype_file {
    my ($self, $c) = @_;

    my $model_id = $c->stash->{model_id};
    my $list     = $c->stash->{list}; 

    $self->get_list_elements_names($c);
    my $plots_names = $c->stash->{list_elements_names};
  
    $c->stash->{pop_id} = $model_id;
    $c->controller("solGS::solGS")->traits_list_file($c);    
    my $traits_file =  $c->stash->{traits_list_file};
    
    my $data_dir = $c->stash->{solgs_prediction_upload_dir};

    my $args = {
	'model_id'      => $model_id,
	'plots_list'    => $plots_names,	        
	'traits_file'   => $traits_file,
	'list_data_dir' => $data_dir,
    };

    $c->stash->{r_temp_file} = 'plots-phenotype-data-query';
    $c->controller('solGS::solGS')->create_cluster_acccesible_tmp_files($c);
    my $out_temp_file = $c->stash->{out_file_temp};
    my $err_temp_file = $c->stash->{err_file_temp};

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $status;
 
    try 
    { 
        my $geno_job = CXGN::Tools::Run->run_cluster_perl({
           
            method        => ["SGN::Controller::solGS::List" => "plots_list_phenotype_data"],
    	    args          => [$args],
    	    load_packages => ['SGN::Controller::solGS::List', 'SGN::Controller::solGS::solGS', 'SGN::Context', 'SGN::Model::solGS::solGS'],
    	    run_opts      => {
    		              out_file    => $out_temp_file,
			      err_file    => $err_temp_file,
    		              working_dir => $temp_dir,
			      max_cluster_jobs => 1_000_000_000,
	    },
	    
         });

	$c->stash->{r_job_tempdir} = $geno_job->tempdir();
	$c->stash->{r_job_id} = $geno_job->job_id();
	$c->stash->{cluster_job} = $geno_job;

	unless ($background_job)
	{
	    $geno_job->wait();
	}
	
    }
    catch 
    {
	$status = $_;
	$status =~ s/\n at .+//s;           
    }; 

}





sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



1;


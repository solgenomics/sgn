package SGN::Controller::solGS::Upload;

use Moose;
use namespace::autoclean;

use List::MoreUtils qw /uniq/;
#use jQuery::File::Upload;
use JSON;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use String::CRC;
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
 
    my @stocks_names = ();  
    foreach my $stock (@$list)
    {
        push @stocks_names, $stock->[1];
	print STDERR "\n uploaded stock: $stock->[1]\n";
    }
    

    @stocks_names = uniq(@stocks_names);
    $c->stash->{genotypes_list} = \@stocks_names;
    
    $c->stash->{list_name} = $list_name;
    $c->stash->{list_id}   = $list_id;

    $c->model('solGS::solGS')->format_user_list_genotype_data($c);
    
    $self->create_user_list_genotype_data_file($c);
   
    my $genotype_file = $c->stash->{user_selection_list_genotype_data_file};

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


sub create_user_list_genotype_data_file {
    my ($self, $c) = @_;
      
    my $tmp_dir   = $c->stash->{solgs_prediction_upload_dir};
    my $list_id =  $c->stash->{list_id};
    $list_id = $c->stash->{model_id} if !$list_id;
    my $population_type = $c->stash->{population_type};
   
    my $user_id   = $c->user->id;
    my $geno_data;
    
    if ($population_type =~ /reference/) 
    {   
        $geno_data = $c->stash->{user_reference_list_genotype_data};
    }
    else 
    {
        $geno_data = $c->stash->{user_selection_list_genotype_data};    
    }

    my $file = catfile ($tmp_dir, "genotype_data_${user_id}_${list_id}");

    write_file($file, $geno_data);

    if ($population_type =~ /reference/) 
    {
        $c->stash->{user_reference_list_genotype_data_file} = $file;
    }
    else
    {
        $c->stash->{user_selection_list_genotype_data_file} = $file;   
    }

}


sub create_user_reference_list_phenotype_data_file {
    my ($self, $c) = @_;
      
    my $tmp_dir = $c->stash->{solgs_prediction_upload_dir};
    my $model_id = $c->stash->{model_id};
    $c->stash->{pop_id} = $model_id;

    my $user_id    = $c->user->id;
    my $pheno_data = $c->stash->{user_reference_list_phenotype_data};
    
    $c->controller("solGS::solGS")->traits_list_file($c);    
    my $traits_file =  $c->stash->{traits_list_file};
  
    $pheno_data = $c->controller("solGS::solGS")->format_phenotype_dataset($pheno_data, $traits_file);
    
    my $file = catfile ($tmp_dir, "phenotype_data_${user_id}_${model_id}");
    write_file($file, $pheno_data);
    
    $c->stash->{user_reference_list_phenotype_data_file} = $file;
  
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

        $c->controller("solGS::solGS")->get_trait_name($c, $trait_id);
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
           my $selection_pop_file = $c->stash->{user_selection_list_genotype_data_file};
          
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
             $c->controller("solGS::solGS")->get_trait_name($c, $trait_id);
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
                     
		     my $exp     = "phenotype_data_${user_id}_${model_id}"; 
                     $pheno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);
                
                     $exp       = "genotype_data_${user_id}_${model_id}"; 
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
                 my $selection_pop_file = $c->stash->{user_selection_list_genotype_data_file};
                
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

    my $exp = "genotype_data_${user_id}_uploaded_${pred_pop_id}"; 
    my  $pred_pop_file = $c->controller("solGS::solGS")->grep_file($upload_dir, $exp);
 
    $c->stash->{user_selection_list_genotype_data_file} = $pred_pop_file;
   
    $fh->print($pred_pop_file);
    $fh->close; 

    $c->stash->{prediction_population_file} = $tempfile;
  
}


sub upload_reference_genotypes_list :Path('/solgs/upload/reference/genotypes/list') Args(0) {
    my ($self, $c) = @_;
 
    my $model_id   = $c->req->param('model_id');
    my $list_name  = $c->req->param('list_name');   
    my $list       = $c->req->param('list');

    my $population_type          = $c->req->param('population_type');
    $c->stash->{population_type} = $population_type;
 
    $list =~ s/\\//g; 
    my $garbage = substr $list, 0, 1, ''; 
    $garbage    = substr $list, -1, 1, '';

    $list = from_json($list);

    my @plots_names = ();  
   
    foreach my $plot (@$list)
    {
        push @plots_names, $plot->[1];
    }
    
    $c->stash->{reference_population_plot_names} = \@plots_names;
     
    $c->stash->{list_name} = $list_name;
    $c->stash->{model_id}  = $model_id;
    
    $c->model('solGS::solGS')->format_user_list_genotype_data();
    $c->model('solGS::solGS')->format_user_reference_list_phenotype_data();
    
    $self->create_user_list_genotype_data_file($c);
    my $geno_file = $c->stash->{user_reference_list_genotype_data_file};
 
    $self->create_user_reference_list_phenotype_data_file($c);
    my $pheno_file =  $c->stash->{user_reference_list_phenotype_data_file};

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


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



1;

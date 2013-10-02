package SGN::Controller::solGS::Upload;

use Moose;
use namespace::autoclean;

use List::MoreUtils qw /uniq/;
use jQuery::File::Upload;
use JSON;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use String::CRC;

BEGIN { extends 'Catalyst::Controller' }


sub upload_prediction_genotypes_file :Path('/solgs/upload/prediction/genotypes/file') Args(0) {
    my ($self, $c) = @_;

    my $file_upload = jQuery::File::Upload->new();
   
    $file_upload->ctx($c);
    $file_upload->field_name('files[]');
    
   # $c->controller("solGS::solGS")->get_solgs_dirs($c);
    my $solgs_prediction_upload = $c->stash->{solgs_prediction_upload_dir};
    
    $file_upload->upload_dir($solgs_prediction_upload);
   
    $file_upload->relative_url_path('/solgs/upload/prediction/genotypes/files');
  
    $file_upload->tmp_dir($solgs_prediction_upload);
    $file_upload->script_url('/solgs/upload/prediction/genotypes');
    $file_upload->use_client_filename(1);
   
    $file_upload->handle_request;
    
    my $file_name         = $file_upload->filename;
    my $absolute_filename = $file_upload->absolute_filename;
    my $client_filename   = $file_upload->client_filename;
  
    my $geno_list = $self->get_selection_genotypes_list_from_file($absolute_filename);
    
    my @genotypes_list = uniq(@$geno_list);
    $c->stash->{prediction_genotypes_list_stocks_names} = \@genotypes_list;
    
    $c->stash->{list_name} = $file_name;
    $c->stash->{list_id}   = crc($file_name);

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
    $c->model('solGS::solGS')->format_user_list_genotype_data($c);
    
    $self->create_user_list_genotype_data_file($c);

    $file_upload->print_response;

    print STDERR "\n  file_name: $file_name\t absolute_name: $absolute_filename \t client_filename: $client_filename\n";


}


sub generate_check_value :Path('/solgs/generate/checkvalue') Args(0) {
    my ($self, $c) = @_;
    
    my $file_name = $c->req->param('file_name');
    my $check_value = crc($file_name);

   # print STDERR "\nfile_name: $file_name \t check_value: $check_value\n";
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
    }
    
    @stocks_names = uniq(@stocks_names);
    $c->stash->{prediction_genotypes_list_stocks_names} = \@stocks_names;
    
    $c->stash->{list_name} = $list_name;
    $c->stash->{list_id}   = $list_id;

   # $c->controller("solGS::solGS")->get_solgs_dirs($c);
    $c->model('solGS::solGS')->format_user_list_genotype_data($c);
    
    $self->create_user_list_genotype_data_file($c);

    my $ret->{status} = 'failed';
    
    if (-s $c->stash->{user_list_genotype_data_file}) 
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
   
    # if ($c->stash->{list_source}  eq 'from_db') { $list_id= $c->stash->{list_id} };
    # if ($c->stash->{list_source}  eq 'from_file') { $list_id= $c->stash->{list_id} };

    my $user_id   = $c->user->id;  
    my $geno_data = $c->stash->{user_list_genotype_data};
    my $file = catfile ($tmp_dir, "genotype_data_${user_id}_${list_id}");

    write_file($file, $geno_data);

    $c->stash->{user_list_genotype_data_file} = $file;


}


sub user_uploaded_prediction_population :Path('/solgs/model') Args(4) {
    my ($self, $c, $model_id,  $uploaded, $prediction, $prediction_pop_id) = @_;

    my $referer = $c->req->referer;
    my $base    = $c->req->base;
    $referer    =~ s/$base//;
    my $path    = $c->req->path;
    $path       =~ s/$base//;
    my $page    = "solgs/model/combined/populations/";
    
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
          
            $c->controller("solGS::solGS")->get_rrblup_output($c); 
        }
        
        $c->controller("solGS::solGS")->gs_files($c);
   
        $c->controller("solGS::solGS")->download_prediction_urls($c, $combo_pops_id,  $prediction_pop_id );
        my $download_prediction = $c->stash->{download_prediction};
     
        my $ret->{status} = 'failed';
    
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
                         print STDERR "\ntrait_name: $r->[0] $r->[1] : $trait_name\n";
                     }
                 }
             }

             $trait_id =  $c->model("solGS::solGS")->get_trait_id($c, $trait_name);
             $c->controller("solGS::solGS")->get_trait_name($c, $trait_id);
             my $trait_abbr = $c->stash->{trait_abbr};

             my $identifier = $model_id . '_uploaded_' . $prediction_pop_id;
             $c->controller("solGS::solGS")->prediction_pop_gebvs_file($c, $identifier, $trait_id);
        
             $prediction_pop_gebvs_file = $c->stash->{prediction_pop_gebvs_file};
      
             if (! -s $prediction_pop_gebvs_file)
             {
                 my $dir = $c->stash->{solgs_cache_dir};
           
                 my $exp = "phenotype_data_${model_id}"; 
                 my $pheno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);
                
                 $exp = "genotype_data_${model_id}"; 
                 my $geno_file = $c->controller("solGS::solGS")->grep_file($dir, $exp);
                
                 $c->stash->{phenotype_file} = $pheno_file;
                 $c->stash->{genotype_file}  = $geno_file;

                 $self->user_prediction_population_file($c, $prediction_pop_id);
  
                 $c->controller("solGS::solGS")->get_rrblup_output($c); 

             }
         } 
            
         $c->controller("solGS::solGS")->trait_phenotype_stat($c);
         $c->controller("solGS::solGS")->gs_files($c);
        
      
         $c->controller("solGS::solGS")->download_prediction_urls($c, $model_id, $prediction_pop_id );
         my $download_prediction = $c->stash->{download_prediction};
      
         my $ret->{status} = 'failed';
    
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

    $c->stash->{prediction_pop_id} = $pred_pop_id;

    
    my $exp = "genotype_data_${user_id}_${pred_pop_id}";
   # if($c->stash->{'list_source'} eq 'from_db')
   # {
    my  $pred_pop_file = $c->controller("solGS::solGS")->grep_file($upload_dir, $exp);
   # } else 
   # {
   #    my $solgs_prediction_upload = $c->stash->{solgs_prediction_upload_dir}      

    #}

    $c->stash->{user_list_genotype_data_file} = $pred_pop_file;
   
    $fh->print($pred_pop_file);
    $fh->close; 

    $c->stash->{prediction_population_file} = $tempfile;
  
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



1;

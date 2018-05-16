package SGN::Controller::solGS::Correlation;

use Moose;
use namespace::autoclean;

use Cache::File;
use CXGN::Tools::Run;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use CXGN::Phenome::Population;
use JSON;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller' }


sub check_pheno_corr_result :Path('/phenotype/correlation/check/result/') Args(1) {
    my ($self, $c, $pop_id) = @_;

    $c->stash->{pop_id} = $pop_id;

    $self->pheno_correlation_output_files($c);
    my $corre_output_file = $c->stash->{corre_coefficients_json_file};
   
    my $ret->{result} = undef;
   
    if (-s $corre_output_file && $pop_id =~ /\d+/) 
    {
	$ret->{result} = 1;                
    }    

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub correlation_phenotype_data :Path('/correlation/phenotype/data/') Args(0) {
    my ($self, $c) = @_;
   
    my $pop_id = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;
    my $referer = $c->req->referer;
   
    my $phenotype_file;
    
    if( $pop_id =~ /uploaded/) 
    {
        my $phenotype_dir = $c->stash->{solgs_prediction_upload_dir};
        my $userid        = $c->user->id;
        $phenotype_file   = "phenotype_data_${userid}_${pop_id}";
        $phenotype_file   = $c->controller('solGS::Files')->grep_file($phenotype_dir, $phenotype_file);
    }
    elsif ($referer =~ /qtl/)
    {    
        $self->create_correlation_phenodata_file($c);
        $phenotype_file =  $c->stash->{phenotype_file};
    }
    else
    {
        my $phenotype_dir = $c->stash->{solgs_cache_dir};
        $phenotype_file   = 'phenotype_data_' . $pop_id;
        $phenotype_file   = $c->controller('solGS::Files')->grep_file($phenotype_dir, '\'^' . $phenotype_file . '\'');
    }

    unless ($phenotype_file)
    {     
        $self->create_correlation_phenodata_file($c);
        $phenotype_file =  $c->stash->{phenotype_file};
    }

    my $ret->{result} = undef;

    if (-s $phenotype_file)
    {
        $ret->{result} = 1;             
    } 
   
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub correlation_genetic_data :Path('/correlation/genetic/data/') Args(0) {
    my ($self, $c) = @_;
   
    my $corr_pop_id = $c->req->param('corr_population_id');
    my $pop_type    = $c->req->param('type');
    my $model_id    = $c->req->param('model_id');
    
    my $index_file  = $c->req->param('index_file');
      
    $c->stash->{model_id} = $model_id;
    $c->stash->{pop_id}   = $model_id;

    $c->stash->{prediction_pop_id} = $corr_pop_id if $pop_type =~ /selection/;
 
    $c->stash->{selection_index_file} = $index_file;
    $self->combine_gebvs_of_traits($c);   
    my $combined_gebvs_file = $c->stash->{combined_gebvs_file};
   
    my $ret->{result} = undef;

    if ( -s $combined_gebvs_file )
    {
        $ret->{result} = 1; 
        $ret->{gebvs_file} = $combined_gebvs_file;
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub trait_acronyms {
    my ($self, $c) = @_;

    $c->controller('solGS::solGS')->get_acronym_pairs($c);
    
}


sub combine_gebvs_of_traits {
    my ($self, $c) = @_;

    $c->controller('solGS::solGS')->get_gebv_files_of_traits($c);  
    my $gebvs_files = $c->stash->{gebv_files_of_valid_traits};
   
    if (!-s $gebvs_files) 
    {
	$gebvs_files = $c->stash->{gebv_files_of_traits};
    }
   
    my $index_file  = $c->stash->{selection_index_file};
   
    my @files_no = map { split(/\t/) } read_file($gebvs_files);
 
    if (scalar(@files_no) > 1 ) 
    {
            
        if ($index_file) 
        {
            write_file($gebvs_files, {append => 1}, "\t". $index_file )   
        }

        my $pred_pop_id = $c->stash->{prediction_pop_id};
        my $model_id    = $c->stash->{model_id};
        my $identifier  =  $pred_pop_id ? $model_id . "_" . $pred_pop_id :  $model_id; 
	my $tmp_dir = $c->stash->{solgs_tempfiles_dir};
        my $combined_gebvs_file = $c->controller('solGS::Files')->create_tempfile($tmp_dir, "combined_gebvs_${identifier}"); 
   
        $c->stash->{input_files}  = $gebvs_files;
        $c->stash->{output_files} = $combined_gebvs_file;
        $c->stash->{r_temp_file}  = "combining-gebvs-${identifier}";
        $c->stash->{r_script}     = 'R/solGS/combine_gebvs_files.r';

        $c->controller("solGS::solGS")->run_r_script($c);
        $c->stash->{combined_gebvs_file} = $combined_gebvs_file;
    }
    else 
    {
        $c->stash->{combined_gebvs_files} = 0;           
    }
}


sub create_correlation_phenodata_file {
    my ($self, $c)  = @_;
    my $referer = $c->req->referer;
    
    if ($referer =~ /qtl/) 
    {
        my $pop_id = $c->stash->{pop_id};
       
        my $pheno_exp = "phenodata_${pop_id}";
        my $dir       = catdir($c->config->{solqtl}, 'cache');
       
        my $phenotype_file = $c->controller('solGS::Files')->grep_file($dir, $pheno_exp);
       
        unless ($phenotype_file) 
	{           
            my $pop =  CXGN::Phenome::Population->new($c->dbc->dbh, $pop_id);       
            $phenotype_file =  $pop->phenotype_file($c);
        }
        
        my $new_file = catfile($c->stash->{correlation_dir}, "phenotype_data_${pop_id}.csv");
      
        copy($phenotype_file, $new_file) 
            or die "could not copy $phenotype_file to $new_file";
       
        $c->stash->{phenotype_file} = $new_file;       
    } 
    else
    {           
      $c->controller("solGS::solGS")->phenotype_file($c);  
    }
        
}


sub create_correlation_dir {
    my ($self, $c) = @_;
    
    $c->controller('solGS::Files')->get_solgs_dirs($c);
   
}


sub pheno_correlation_output_files {
    my ($self, $c) = @_;
     
    my $pop_id = $c->stash->{pop_id};
    
    $self->create_correlation_dir($c);
    my $corre_dir = $c->stash->{correlation_dir};
    
    my $file_cache  = Cache::File->new(cache_root => $corre_dir);
    $file_cache->purge();
                                       
    my $key_table = 'corre_coefficients_table_' . $pop_id;
    my $key_json  = 'corre_coefficients_json_' . $pop_id;
    my $corre_coefficients_file      = $file_cache->get($key_table);
    my $corre_coefficients_json_file = $file_cache->get($key_json);

    unless ($corre_coefficients_file && $corre_coefficients_json_file )
    {         
        $corre_coefficients_file= catfile($corre_dir, "corre_coefficients_table_${pop_id}");

        write_file($corre_coefficients_file);
        $file_cache->set($key_table, $corre_coefficients_file, '30 days');

        $corre_coefficients_json_file = catfile($corre_dir, "corre_coefficients_json_${pop_id}");

        write_file($corre_coefficients_json_file);
        $file_cache->set($key_json, $corre_coefficients_json_file, '30 days');
    }

    $c->stash->{corre_coefficients_table_file} = $corre_coefficients_file;
    $c->stash->{corre_coefficients_json_file}  = $corre_coefficients_json_file;
}


sub genetic_correlation_output_files {
    my ($self, $c) = @_;
     
    my $corre_pop_id = $c->stash->{corre_pop_id};
    my $model_id     = $c->stash->{model_id};
    my $type         = $c->stash->{type};
 
    my $pred_pop_id = $c->stash->{prediction_pop_id};
    $model_id    = $c->stash->{model_id};
    my $identifier  =  $type =~ /selection/ ? $model_id . "_" . $corre_pop_id :  $corre_pop_id; 

    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};
    my $corre_json_file  = $c->controller('solGS::Files')->create_tempfile($tmp_dir, "genetic_corre_json_${identifier}");
    my $corre_table_file = $c->controller('solGS::Files')->create_tempfile($tmp_dir, "genetic_corre_table_${identifier}");

    $c->stash->{genetic_corre_table_file} = $corre_table_file;
    $c->stash->{genetic_corre_json_file}  = $corre_json_file;
}


sub pheno_correlation_analysis_output :Path('/phenotypic/correlation/analysis/output') Args(0) {
    my ($self, $c) = @_;

    my $pop_id = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;

    $self->pheno_correlation_output_files($c);
    my $corre_json_file = $c->stash->{corre_coefficients_json_file};
      
    
    my $ret->{status} = 'failed';
  
    if (!-s $corre_json_file)
    {
        $self->run_pheno_correlation_analysis($c);  
        $corre_json_file = $c->stash->{corre_coefficients_json_file}; 
    }
    
    if (-s $corre_json_file)
    {
	$self->trait_acronyms($c);
	my $acronyms = $c->stash->{acronym};
    
	$ret->{acronyms} = $acronyms;
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file);	
    } 
        
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub genetic_correlation_analysis_output :Path('/genetic/correlation/analysis/output') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{corre_pop_id} = $c->req->param('corr_population_id');
    $c->stash->{model_id}     = $c->req->param('model_id');
    $c->stash->{type}         = $c->req->param('type');
    
    my $corr_pop_id = $c->req->param('corr_population_id');
    my $model_id    = $c->req->param('model_id');
    my $type        = $c->req->param('type');

    my $gebvs_file = $c->req->param('gebvs_file');
    $c->stash->{data_input_file} = $gebvs_file;
    
    $self->genetic_correlation_output_files($c);
   
    if (-s $gebvs_file) 
    {
        $self->run_genetic_correlation_analysis($c);       
    }
    
    my $ret->{status} = 'failed';
    my $corre_json_file = $c->stash->{genetic_corre_json_file};
    
    if (-s $corre_json_file)
    { 
        $ret->{status}   = 'success';
        $ret->{data}     = read_file($corre_json_file);
    } 
    
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub run_pheno_correlation_analysis {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};
   
    $self->create_correlation_phenodata_file($c);
    $c->stash->{data_input_file} = $c->stash->{phenotype_file};
    
    $self->pheno_correlation_output_files($c);
    $c->stash->{corre_table_output_file} = $c->stash->{corre_coefficients_table_file};
    $c->stash->{corre_json_output_file}  = $c->stash->{corre_coefficients_json_file};
    
    $c->controller("solGS::Files")->formatted_phenotype_file($c);

    $c->stash->{referer} = $c->req->referer;
    
    $c->stash->{correlation_type} = "pheno_correlation_${pop_id}";
    $c->stash->{correlation_script} = "R/solGS/phenotypic_correlation.r";
    
    $self->run_correlation_analysis($c);

    #$self->trait_acronyms($c);
}


sub run_genetic_correlation_analysis {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{corre_pop_id};
  
    $self->genetic_correlation_output_files($c);
    $c->stash->{corre_table_output_file} = $c->stash->{genetic_corre_table_file};
    $c->stash->{corre_json_output_file}  = $c->stash->{genetic_corre_json_file};
      
    $c->stash->{referer} = $c->req->referer;
    
    $c->stash->{correlation_type} = "genetic_correlation_${pop_id}";
    $c->stash->{correlation_script} = "R/solGS/genetic_correlation.r";
    $self->run_correlation_analysis($c);

}


sub download_phenotypic_correlation : Path('/download/phenotypic/correlation/population') Args(1) {
    my ($self, $c, $id) = @_;
    
    $self->create_correlation_dir($c);
    my $corr_dir = $c->stash->{correlation_dir};
    my $corr_file = catfile($corr_dir,  "corre_coefficients_table_${id}");
  
    unless (!-e $corr_file || -s $corr_file <= 1) 
    {
	my @corr_data;
	my $count=1;

	foreach my $row ( read_file($corr_file) )
	{
	    if ($count==1) {  $row = 'Traits,' . $row;}             
	    $row =~ s/NA//g; 
	    $row = join(",", split(/\s/, $row));
	    $row .= "\n";
 
	    push @corr_data, [ $row ];
	    $count++;
	}
   
	$c->res->content_type("text/plain");
	$c->res->body(join "",  map{ $_->[0] } @corr_data);   
           

    }  
}


sub run_correlation_analysis {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};
   
    $self->create_correlation_dir($c);
    my $corre_dir = $c->stash->{correlation_dir};
    
    my $data_input_file = $c->stash->{data_input_file};
    
    my $corre_table_file = $c->stash->{corre_table_output_file};
    my $corre_json_file  = $c->stash->{corre_json_output_file};
    
    my $formatted_phenotype_file = $c->stash->{formatted_phenotype_file};

    my $referer        = $c->stash->{referer};
    my $corre_analysis = $c->stash->{correlation_type};
    my $corre_script   = $c->stash->{correlation_script};
   
    if (-s $data_input_file) 
    {
        CXGN::Tools::Run->temp_base($corre_dir);
       
        my ( $corre_commands_temp, $corre_output_temp ) =
            map
        {
            my (undef, $filename ) =
                tempfile(
                    catfile(
                        CXGN::Tools::Run->temp_base(),
                        "$corre_analysis-$_-XXXXXX",
                         ),
                );
            $filename
        } qw / in out /;
    
    {
        my $corre_commands_file = $c->path_to($corre_script);
        copy( $corre_commands_file, $corre_commands_temp )
            or die "could not copy '$corre_commands_file' to '$corre_commands_temp'";
    }

      try 
      {
          print STDERR "\nsubmitting correlation job to the cluster..\n";
          my $r_process = CXGN::Tools::Run->run_cluster(
              'R', 'CMD', 'BATCH',
              '--slave',
              "--args $formatted_phenotype_file $referer $corre_table_file $corre_json_file $data_input_file",
              $corre_commands_temp,
              $corre_output_temp,
              {
                  working_dir => $corre_dir,
                  max_cluster_jobs => 1_000_000_000,
              },
              );

          $r_process->wait;
          print STDERR "\ndone with correlation analysis..\n";
      }
      catch 
      {  
            
            my $err = $_;
            $err =~ s/\n at .+//s; #< remove any additional backtrace
            #     # try to append the R output
           
            try
            { 
                $err .= "\n=== R output ===\n".file($corre_output_temp)->slurp."\n=== end R output ===\n" 
            };
            
            $c->stash->{script_error} = "Correlation analysis failed.";
                     
      };       
    }
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



####
1;
####

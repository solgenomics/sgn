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
        $phenotype_file   = $c->controller('solGS::solGS')->grep_file($phenotype_dir, $phenotype_file);
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
        $phenotype_file   = $c->controller('solGS::solGS')->grep_file($phenotype_dir, '\'^' . $phenotype_file . '\'');
    }

    unless ($phenotype_file)
    {     
        $self->create_correlation_phenodata_file($c);
        $phenotype_file =  $c->stash->{phenotype_file};
    }


    my $ret->{status} = 'failed';

    if($phenotype_file)
    {
        $ret->{status} = 'success';             
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub create_correlation_phenodata_file {
    my ($self, $c)  = @_;
    my $referer = $c->req->referer;
    
    if ($referer =~ /qtl/) 
    {
        my $pop_id = $c->stash->{pop_id};
       
        my $pheno_exp = "phenodata_${pop_id}";
        my $dir       = catdir($c->config->{r_qtl_temp_path}, 'cache');
       
        my $phenotype_file = $c->controller("solGS::solGS")->grep_file($dir, $pheno_exp);
       
        unless ($phenotype_file) {
           
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
    
    my $temp_dir        = $c->config->{cluster_shared_tempdir};
    my $correlation_dir = catdir($temp_dir, 'correlation', 'cache'); 
  
    mkpath ([$temp_dir, $correlation_dir], 0, 0755);
   
    $c->stash->{correlation_dir} = $correlation_dir;

}


sub correlation_output_file {
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

    $c->stash->{corre_coefficients_file} = $corre_coefficients_file;
    $c->stash->{corre_coefficients_json_file} = $corre_coefficients_json_file;
}


sub correlation_analysis_output :Path('/correlation/analysis/output') Args(0) {
    my ($self, $c) = @_;

    my $pop_id = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;

    $self->correlation_output_file($c);
    my $corre_coefficients_file = $c->stash->{corre_coefficients_file};
   
    if (!-s $corre_coefficients_file)
    {
        $self->run_correlation_analysis($c);  
        $corre_coefficients_file = $c->stash->{corre_coefficients_file};
  
    }

    my $ret->{status} = 'failed';

    if (-s $corre_coefficients_file)
    {
        $ret->{status} = 'success';      
        my $corre_json_file = $c->stash->{corre_coefficients_json_file};       
        $ret->{data} = read_file($corre_json_file);
                
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub run_correlation_analysis {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};
   
    $self->create_correlation_dir($c);
    my $corre_dir = $c->stash->{correlation_dir};
    
    $self->create_correlation_phenodata_file($c);
    my $pheno_file = $c->stash->{phenotype_file};
    
    $self->correlation_output_file($c);
    my $corre_table_file = $c->stash->{corre_coefficients_file};
    my $corre_json_file = $c->stash->{corre_coefficients_json_file};
   
    my $referer = $c->req->referer;

    if (-s $pheno_file) 
    {
        CXGN::Tools::Run->temp_base($corre_dir);
       
        my ( $corre_commands_temp, $corre_output_temp ) =
            map
        {
            my (undef, $filename ) =
                tempfile(
                    catfile(
                        CXGN::Tools::Run->temp_base(),
                        "corre_analysis_${pop_id}-$_-XXXXXX",
                         ),
                );
            $filename
        } qw / in out /;
    
    {
        my $corre_commands_file = $c->path_to('/R/correlation.r');
        copy( $corre_commands_file, $corre_commands_temp )
            or die "could not copy '$corre_commands_file' to '$corre_commands_temp'";
    }

      try 
      {
          print STDERR "\nsubmitting correlation job to the cluster..\n";
          my $r_process = CXGN::Tools::Run->run_cluster(
              'R', 'CMD', 'BATCH',
              '--slave',
              "--args $referer $corre_table_file $corre_json_file $pheno_file",
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
                     

            $c->throw(is_client_error   => 1,
                      title             => "Correlation analysis script error",
                      public_message    => "There is a problem running the correlation r script  on this dataset!",	     
                      notify            => 1, 
                      developer_message => $err,
            );
      };
        
    } 

    $c->stash->{corre_coefficients_file} = $corre_table_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



####
1;
####

package SGN::Controller::solGS::Histogram;

use Moose;
use namespace::autoclean;
use CXGN::Tools::Run;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use File::Temp qw / tempfile tempdir /;
use JSON;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller' }


sub histogram_phenotype_data :Path('/histogram/phenotype/data/') Args(0) {
    my ($self, $c) = @_;
    
    my $pop_id   = $c->req->param('population_id');
    my $trait_id = $c->req->param('trait_id');
   
    $c->stash->{pop_id} = $pop_id;

    $c->controller('solGS::solGS')->get_trait_name($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};
    
    my $trait_pheno_file = "phenotype_trait_${trait_abbr}_${pop_id}";
    my $dir = $c->stash->{solgs_cache_dir};

    $trait_pheno_file = $c->controller('solGS::solGS')->grep_file($dir, $trait_pheno_file);
    $c->stash->{histogram_trait_file} = $trait_pheno_file;

    if (!$trait_pheno_file || -z $trait_pheno_file)
    {
        $self->create_population_phenotype_data($c);                 
    }

    unless (!$c->stash->{phenotype_file} || -s $trait_pheno_file)
    {
        $self->create_trait_phenodata($c);
    }    
    
    my $data = $self->format_plot_data($c);
    
    $c->controller('solGS::solGS')->trait_phenotype_stat($c);
     my $stat = $c->stash->{descriptive_stat};

    my $ret->{status} = 'failed';

    if (@$data)
    {
        $ret->{data} = $data;
	$ret->{stat} = $stat;
        $ret->{status} = 'success';             
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    
      
}


sub format_plot_data {
   my ($self, $c) = @_;

   my $file = $c->stash->{histogram_trait_file};
   my $data = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $file);
  
   return $data;
   
}


sub create_population_phenotype_data {    
    my ($self, $c) = @_;
    
    $c->controller("solGS::solGS")->phenotype_file($c);

}


sub create_histogram_dir {
    my ($self, $c) = @_;
    
    my $temp_dir      =  $c->config->{cluster_shared_tempdir};
    my $histogram_dir = catdir($temp_dir, 'histogram', 'cache'); 
  
    mkpath ($histogram_dir, 0, 0755);
   
    $c->stash->{histogram_dir} = $histogram_dir;

}


sub create_trait_phenodata {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};
   
    $self->create_histogram_dir($c);
    my $histogram_dir = $c->stash->{histogram_dir};

    my $pheno_file = $c->stash->{phenotype_file};
    my $trait_file = $c->controller("solGS::solGS")->trait_phenodata_file($c);
    my $trait_abbr = $c->stash->{trait_abbr};
 
    if (-s $pheno_file) 
    {
        CXGN::Tools::Run->temp_base($histogram_dir);
       
        my ( $histogram_commands_temp, $histogram_output_temp ) =
            map
        {
            my (undef, $filename ) =
                tempfile(
                    catfile(
                        CXGN::Tools::Run->temp_base(),
                        "histogram_analysis_${pop_id}_${trait_abbr}-$_-XXXXXX",
                         ),
                );
            $filename
        } qw / in out /;
    
    {
        my $histogram_commands_file = $c->path_to('/R/histogram.r');
        copy( $histogram_commands_file, $histogram_commands_temp )
            or die "could not copy '$histogram_commands_file' to '$histogram_commands_temp'";
    }

      try 
      {
          print STDERR "\nsubmitting histogram job to the cluster..\n";
          my $r_process = CXGN::Tools::Run->run_cluster(
              'R', 'CMD', 'BATCH',
              '--slave',
              "--args  input_file=$pheno_file trait_name=$trait_abbr output_file=$trait_file",
              $histogram_commands_temp,
              $histogram_output_temp,
              {
                  working_dir => $histogram_dir,
                  max_cluster_jobs => 1_000_000_000,
              },
              );

          $r_process->wait;
          print STDERR "\ndone with histogram analysis..\n";
      }
      catch 
      {  
            
            my $err = $_;
            $err =~ s/\n at .+//s; #< remove any additional backtrace
            #     # try to append the R output
           
            try
            { 
                $err .= "\n=== R output ===\n".file($histogram_output_temp)->slurp."\n=== end R output ===\n" 
            };
                     
            $c->stash->{script_error} =  "There is a problem running the histogram r script on this dataset.";	     
    
      };
     
        $c->stash->{histogram_trait_file} = $trait_file;
    }
    else 
    {
        $c->stash->{script_error} =  "There is no phenotype for this trait.";     
    }

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}
####
1;
####

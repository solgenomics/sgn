package SGN::Controller::solGS::combinedTrials;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
#use CatalystX::GlobalContext ();
use Statistics::Descriptive;
use Math::Round::Var;
use Algorithm::Combinatorics qw /combinations/;
use CXGN::Tools::Run;
use JSON;


BEGIN { extends 'Catalyst::Controller' }



sub prepare_data_for_trials :Path('/solgs/retrieve/populations/data') Args() {
    my ($self, $c) = @_;
   
    my $ids = $c->req->param('trials');
   # my @pop_ids = @ids;
    my  @pop_ids = split(/,/, $ids);

    print STDERR "\nids: $ids\n";
    my $combo_pops_id;
    my $ret->{status} = 0;

    my $solgs_controller = $c->controller('solGS::solGS');
    my $not_matching_pops;
    my @g_files;
    if (scalar(@pop_ids) > 1 )
    {  
        $combo_pops_id =  crc(join('', @pop_ids));
        $c->stash->{combo_pops_id} = $combo_pops_id;
      
        $solgs_controller->multi_pops_phenotype_data($c, \@pop_ids);
        $solgs_controller->multi_pops_genotype_data($c, \@pop_ids);

        my $geno_files = $c->stash->{multi_pops_geno_files};
        @g_files = split(/\t/, $geno_files);

        $solgs_controller->compare_genotyping_platforms($c, \@g_files);
        $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};
     
        if (!$not_matching_pops) 
        {

             print STDERR "\n not_matching_pops: $not_matching_pops - g_files: $g_files[0]\n";

            # #$solgs_controller->cache_combined_pops_data($c);

           # # my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
           # # my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
             
           #  unless (-s $combined_pops_geno_file  && -s $combined_pops_pheno_file ) 
           #  {
           #      $self->r_combine_populations($c);
                
           #      $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
           #      $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
           #  }
                       
           #  if (-s $combined_pops_pheno_file > 1 && -s $combined_pops_geno_file > 1) 
           #  {
           #      my $tr_abbr = $c->stash->{trait_abbr};  
           #      $c->stash->{data_set_type} = 'combined populations';                
           #      $self->get_rrblup_output($c); 
           #      my $analysis_result = $c->stash->{combo_pops_analysis_result};
                  
           #      $ret->{pop_ids}       = $ids;
           #      $ret->{combo_pops_id} = $combo_pops_id; 
           #      $ret->{status}        = $analysis_result;

           #      $self->list_of_prediction_pops($c, $combo_pops_id);

           #      my $entry = "\n" . $combo_pops_id . "\t" . $ids;
           #      $self->catalogue_combined_pops($c, $entry);

           #    }           
        }
        else 
        { print STDERR "\n not_matching_pops: $not_matching_pops - g_files: $g_files[0]\n";
            $ret->{not_matching_pops} = $not_matching_pops;
        }
    }
    else 
    {
        #run gs model based on a single population
        my $pop_id = $pop_ids[0];
        $ret->{redirect_url} = "/solgs/population/$pop_id";
    }
      print STDERR "\n end... not_matching_pops: $not_matching_pops - g_files: $g_files[0]\n";  
    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



1;

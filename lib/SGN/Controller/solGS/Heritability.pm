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

use JSON;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller' }


sub check_regression_data :Path('/heritability/check/data/') Args(0) {
    my ($self, $c) = @_;
    
    my $pop_id   = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;

    my $solgs_controller = $c->controller('solGS::solGS');

    my $trait_id = $c->req->param('trait_id');
    $solgs_controller->get_trait_name($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};
     
    my $cache_dir = $c->stash->{solgs_cache_dir};

    my $phenotype_file   = "phenotype_trait_${trait_abbr}_${pop_id}";
    $phenotype_file   = $solgs_controller->grep_file($cache_dir, $phenotype_file);
       
    my $gebv_file = "gebv_kinship_${trait_abbr}_${pop_id}";
    $gebv_file    = $solgs_controller->grep_file($cache_dir,  $gebv_file);
      
    my $ret->{status} = 'failed';

    if(-s $phenotype_file && -s $gebv_file)
    {
        $ret->{status} = 'success';             
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub get_heritability {
    my ($self, $c) = @_;
    
    my $trait_abbr = $c->stash->{trait_abbr};
    my $pop_id     = $c->stash->{pop_id};
    
    my $solgs_controller = $c->controller('solGS::solGS');
    my $cache_dir = $c->stash->{solgs_cache_dir};

    my $var_comp_file = "variance_components_${trait_abbr}_${pop_id}";
    $var_comp_file = $solgs_controller->grep_file($cache_dir, $var_comp_file);

    my ($txt, $value) = map { split(/\t/)  } 
                        grep {/heritability/}
                        read_file($var_comp_file);
  
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



####
1;
####

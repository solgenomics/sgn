package SGN::Controller::solGS::Histogram;

use Moose;
use namespace::autoclean;


use JSON;
BEGIN { extends 'Catalyst::Controller' }


sub histogram_phenotype_data :Path('/histogram/phenotype/data/') Args(0) {
    my ($self, $c) = @_;
    
    my $pop_id = $c->req->param('population_id');
    my $trait_id = $c->req->param('trait_id');
   
    $c->controller('solGS::solGS')->get_trait_name($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};
    
    my $pheno_file = "phenotype_trait_${trait_abbr}_${pop_id}";
    my $dir = $c->stash->{solgs_cache_dir};

    $pheno_file = $c->controller('solGS::solGS')->grep_file($dir, $pheno_file);
    $c->stash->{trait_pheno_data_file} = $pheno_file;
      
    my $data = $self->prepare_histogram_data($c);

    my $ret->{status} = 'failed';

    if ($data)
    {
        $ret->{data} = $data;
        $ret->{status} = 'success';             
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub prepare_histogram_data {
   my ($self, $c) = @_;

   my $file = $c->stash->{trait_pheno_data_file};
   my $data = $c->controller('solGS::solGS')->convert_to_arrayref($c, $file);
   
   return $data;
   
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}
####
1;
####

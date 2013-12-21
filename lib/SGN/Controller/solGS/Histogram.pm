package SGN::Controller::solGS::Histogram;

use Moose;
use namespace::autoclean;


use JSON;
BEGIN { extends 'Catalyst::Controller' }


sub histogram_phenotype_data :Path('/histogram/phenotype/data/') Args(0) {
    my ($self, $c) = @_;
    
    my $pop_id = $c->req->param('population_id');
    my $trait_id = $c->req->param('trait_id');
   
    $c->stash->{pop_id} = $pop_id;

    $c->controller('solGS::solGS')->get_trait_name($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};
    
    my $trait_pheno_file = "phenotype_trait_${trait_abbr}_${pop_id}";
    my $dir = $c->stash->{solgs_cache_dir};

    $trait_pheno_file = $c->controller('solGS::solGS')->grep_file($dir, $trait_pheno_file);

    if(!$trait_pheno_file)
    {
        my $pop_pheno_file = 'corr_phenotype_data_' . $pop_id;
        $dir = $c->stash->{correlation_dir};
       
        $pop_pheno_file = $c->controller('solGS::solGS')->grep_file($dir, $pop_pheno_file);
        
        if (!$pop_pheno_file) 
        {
            $self->create_histogram_phenodata_file($c);
            my $pop_pheno_file = $c->stash->{histogram_phenodata_file}
        }
    }

    # clean up, format and save trait phenotype data
    $c->stash->{trait_pheno_data_file} = $trait_pheno_file;
      
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


sub create_histogram_phenodata_file {
    my ($self, $c)  = @_;

    my $pop_id = $c->stash->{pop_id};

    $self->create_histogram_dir($c);
    my $histogram_cache_dir = $c->stash->{histogram_dir};

    my $file_cache  = Cache::File->new(cache_root => $histogram_cache_dir);
    $file_cache->purge();
                                       
    my $key = 'histogram_phenotype_data_' . $pop_id;
    my $histogram_pheno_file  = $file_cache->get($key);

    unless ($histogram_pheno_file)
    {         
        $histogram_pheno_file= catfile($histogram_cache_dir, 'histogram_phenotype_data_' . $pop_id);

        $self->get_population_phenotype_data($c);
        my $pheno_data =  $c->{histogram_pheno_data};

        write_file($histogram_pheno_file, $pheno_data);
        $file_cache->set($key, $histogram_pheno_file, '30 days');
    }

    $c->stash->{histogram_phenodata_file} = $histogram_pheno_file;

}


sub get_population_phenotype_data {    
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};
    my $pheno_data = $c->model('solGS::solGS')->phenotype_data($c, $pop_id);
    my $formatted_pheno_data = $c->controller('solGS::solGS')->format_phenotype_dataset($c, $pheno_data);
  
    $c->{histogram_pheno_data} = $formatted_pheno_data;

}


sub create_histogram_dir {
    my ($self, $c) = @_;
    
    my $temp_dir        = $c->config->{cluster_shared_tempdir};
    my $histogram_dir = catdir($temp_dir, 'histogram', 'cache'); 
  
    mkpath ([$temp_dir, $histogram_dir], 0, 0755);
   
    $c->stash->{histogram_dir} = $histogram_dir;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}
####
1;
####

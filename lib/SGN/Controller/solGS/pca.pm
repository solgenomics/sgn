package SGN::Controller::solGS::pca;

use Moose;
use namespace::autoclean;

use File::Spec::Functions qw / catfile catdir/;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use JSON;


BEGIN { extends 'Catalyst::Controller' }


sub pca_result :Path('/pca/result/') Args(1) {
    my ($self, $c, $pop_id) = @_;
    
    $c->stash->{pop_id}   = $pop_id;
    $c->stash->{model_id} = $pop_id;

    $self->create_pca_genotype_data($c);
    my $geno_file = $c->stash->{genotype_file};

    my $ret->{status} = 'failed';

    my $pca_scores;
    if (!-s $geno_file)
    {
	$ret->{status} = 'There is no genotype data. Aborted PCA analysis.';                
    }
    else 
    {
	$self->run_pca($c);
	my $pca_file = $c->stash->{pca_scores_file};
	$pca_scores = $c->stash->{pca_scores};	
    }

    if ($pca_scores)
    {
        $ret->{pca_scores} = $pca_scores;
        $ret->{status} = 'success';             
    }

    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub format_pca_scores {
   my ($self, $c) = @_;

   my $file = $c->stash->{pca_scores_file};
   my $data = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $file);
  
   $c->stash->{pca_scores} = $data;

}


sub create_pca_genotype_data {    
    my ($self, $c) = @_;
    
    $c->controller("solGS::solGS")->genotype_file($c);

}


sub create_pca_dir {
    my ($self, $c) = @_;
    
    my $temp_dir        = $c->config->{cluster_shared_tempdir};
    my $pca_dir = catdir($temp_dir, 'pca', 'cache'); 
  
    mkpath ([$temp_dir, $pca_dir], 0, 0755);
   
    $c->stash->{pca_dir} = $pca_dir;

}



sub pca_scores_file {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    $self->create_pca_dir($c);
    my $pca_dir = $c->stash->{pca_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_scores_${pop_id}",
                      file      => "pca_scores_${pop_id}",,
                      stash_key => 'pca_scores_file'
    };

    $self->cache_file($c, $cache_data);

}


sub pca_loadings_file {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    $self->create_pca_dir($c);
    my $pca_dir = $c->stash->{pca_dir};

    $c->stash->{cache_dir} = $pca_dir;

    my $cache_data = {key       => "pca_loadings_${pop_id}",
                      file      => "pca_loadings_${pop_id}",,
                      stash_key => 'pca_loadings_file'
    };

    $self->cache_file($c, $cache_data);

}


sub pca_output_files {
    my ($self, $c) = @_;
     
    $self->pca_scores_file($c);
    $self->pca_loadings_file($c);

    my $file_list = join ("\t",
                          $c->stash->{pca_scores_file},
                          $c->stash->{pca_loadings_file},                       
	);
                          
    my $name = "pca_output_files_${pop_id}"; 
    my $tempfile =  $c->controller("solGS::solGS")->create_tempfile($c, $name); 
    write_file($tempfile, $file_list);
    
    $c->stash->{output_files} = $tempfile;

}


sub run_pca {
    my ($self, $c) = @_;
    
    my $pop_id = $c->stash->{pop_id};

    my $pca_output_file = $self->pca_output_file($c);

    $c->stash->{input_files}  = $geno_file;
    $c->stash->{output_files} = $pca_output_file;
    $c->stash->{r_temp_file}  = "pca-${pop_id}";
    $c->stash->{r_script}     = 'R/pca.r';

    $c->controller("solGS::solGS")->run_r_script($c);
    $c->stash->{combined_gebvs_file} = $combined_gebvs_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####

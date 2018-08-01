package SGN::Controller::solGS::Heritability;

use Moose;
use namespace::autoclean;

use File::Slurp qw /write_file read_file/;
use JSON;
use Math::Round::Var;
use Statistics::Descriptive;


BEGIN { extends 'Catalyst::Controller' }


sub check_regression_data :Path('/heritability/check/data/') Args(0) {
    my ($self, $c) = @_;
    
    my $pop_id   = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;

    my $solgs_controller = $c->controller('solGS::solGS');

    my $trait_id = $c->req->param('trait_id');
    $solgs_controller->get_trait_details($c, $trait_id);
    
    $self->get_regression_data_files($c);

    my $ret->{exists} = undef;

    my $gebv_file  = $c->stash->{regression_gebv_file};
    my $pheno_file = $c->stash->{regression_pheno_file};

    if(-s $gebv_file  && -s $pheno_file)
    {
        $ret->{exists} = 'yes';             
    }

    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub get_regression_data_files {
    my ($self, $c) = @_;

    my $pop_id     = $c->stash->{pop_id};
    my $trait_abbr = $c->stash->{trait_abbr}; 
    my $cache_dir  = $c->stash->{solgs_cache_dir};
 
    my $phenotype_file = "phenotype_trait_${trait_abbr}_${pop_id}";
    $phenotype_file    = $c->controller('solGS::Files')->grep_file($cache_dir, $phenotype_file);
       
    my $gebv_file = "rrblup_training_gebvs_${trait_abbr}_${pop_id}";
    $gebv_file    = $c->controller('solGS::Files')->grep_file($cache_dir,  $gebv_file);
   
    $c->stash->{regression_gebv_file} = $gebv_file;
    $c->stash->{regression_pheno_file} = $phenotype_file;  

}


sub get_heritability {
    my ($self, $c) = @_;
    
    my $trait_abbr = $c->stash->{trait_abbr};
    my $pop_id     = $c->stash->{pop_id};
    my $cache_dir  = $c->stash->{solgs_cache_dir};

    $c->controller('solGS::Files')->variance_components_file($c);
    my $var_comp_file = $c->stash->{variance_components_file};

    my ($txt, $value) = map { split(/\t/)  } 
                        grep {/Heritability/}
                        read_file($var_comp_file);

    $c->stash->{heritability} = $value;
}


sub heritability_regeression_data :Path('/heritability/regression/data/') Args(0) {
    my ($self, $c) = @_;
    
    my $pop_id   = $c->req->param('population_id');
    $c->stash->{pop_id} = $pop_id;

    my $trait_id = $c->req->param('trait_id');
    my $solgs_controller = $c->controller('solGS::solGS');
    $solgs_controller->get_trait_details($c, $trait_id);

    $self->get_regression_data_files($c);

    my $gebv_file  = $c->stash->{regression_gebv_file};
    my $pheno_file = $c->stash->{regression_pheno_file};

    my @gebv_data  = map { $_ =~ s/\n//; $_ }  read_file($gebv_file);
    my @pheno_data = map { $_ =~ s/\n//; $_ }  read_file($pheno_file);
    
    @gebv_data  = map { [ split(/\t/) ] } @gebv_data;
    @pheno_data = map { [ split(/\t/) ] } @pheno_data;
 
    my @pheno_values   = map { $_->[1] } @pheno_data;
    shift(@pheno_values);
    shift(@gebv_data);
    shift(@pheno_data);
   
    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@pheno_values);
    my $pheno_mean = $stat->mean();

    my $round = Math::Round::Var->new(0.01);
   
    my @pheno_deviations = map { [$_->[0], $round->round(( $_->[1] - $pheno_mean ))] } @pheno_data;

    $self->get_heritability($c);
    my $heritability = $c->stash->{heritability};
    
    my $ret->{status} = 'failed';

    if (@gebv_data && @pheno_data)
    {
        $ret->{status}           = 'success';
        $ret->{gebv_data}        = \@gebv_data;
        $ret->{pheno_deviations} = \@pheno_deviations;
        $ret->{pheno_data}       = \@pheno_data;
        $ret->{heritability}     = $heritability;

    }

    $ret = to_json($ret);
 
    $c->res->content_type('application/json');
    $c->res->body($ret);           
    
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



####
1;
####

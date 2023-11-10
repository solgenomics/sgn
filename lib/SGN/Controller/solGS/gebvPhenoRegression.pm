package SGN::Controller::solGS::gebvPhenoRegression;

use Moose;
use namespace::autoclean;

use File::Slurp qw /write_file read_file/;
use JSON;
use Math::Round::Var;
use Statistics::Descriptive;


BEGIN { extends 'Catalyst::Controller' }


sub check_regression_data :Path('/solgs/check/regression/data/') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $trait_id = $c->stash->{'trait_id'};
    $c->controller('solGS::Trait')->get_trait_details($c, $trait_id);

    $self->get_regression_data_files($c);

    my $ret->{exists} = undef;

    my $gebv_file  = $c->stash->{regression_gebv_file};
    my $pheno_file = $c->stash->{regression_pheno_file};

    if(-s $gebv_file  && -s $pheno_file)
    {
        $ret->{exists} = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_regression_data_files {
    my ($self, $c) = @_;

    my $pop_id     = $c->stash->{training_pop_id};
    my $trait_abbr = $c->stash->{trait_abbr};
    my $cache_dir  = $c->stash->{solgs_cache_dir};

    $c->controller('solGS::Files')->model_phenodata_file($c);
    my $phenotype_file = $c->stash->{model_phenodata_file};

    $c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
    my $gebv_file = $c->stash->{rrblup_training_gebvs_file};

    $c->stash->{regression_gebv_file} = $gebv_file;
    $c->stash->{regression_pheno_file} = $phenotype_file;

}


sub get_heritability {
    my ($self, $c, $pop_id, $trait_id) = @_;

    $c->controller('solGS::Trait')->get_trait_details($c, $trait_id);

    $c->controller('solGS::Files')->variance_components_file($c);
    my $var_comp_file = $c->stash->{variance_components_file};

    my ($txt, $value) = map { split(/\t/)  }
                        grep {/SNP heritability/}
                        read_file($var_comp_file, {binmode => ':utf8'});

    return $value;
    
}


sub get_additive_variance {
    my ($self, $c, $pop_id, $trait_id) = @_;

    $c->controller('solGS::Trait')->get_trait_details($c, $trait_id);

    $c->controller('solGS::Files')->variance_components_file($c);
    my $var_comp_file = $c->stash->{variance_components_file};

    my ($txt, $value) = map { split(/\t/)  }
                        grep {/Additive genetic/}
                        read_file($var_comp_file, {binmode => ':utf8'});

    return $value;

}


sub get_regeression_data :Path('/solgs/get/regression/data/') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $trait_id = $c->stash->{'trait_id'};
    $c->controller('solGS::Trait')->get_trait_details($c, $trait_id);

    $self->get_regression_data_files($c);

    my $gebv_file  = $c->stash->{regression_gebv_file};
    my $pheno_file = $c->stash->{regression_pheno_file};

    my @gebv_data  = map { $_ =~ s/\n//; $_ }  read_file($gebv_file, {binmode => ':utf8'});
    my @pheno_data = map { $_ =~ s/\n//; $_ }  read_file($pheno_file, {binmode => ':utf8'});

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

    my $pop_id = $c->stash->{'training_pop_id'};
    my $heritability =  $self->get_heritability($c, $pop_id, $trait_id);

    my $ret->{status} = undef;

    if (@gebv_data && @pheno_data)
    {
        $ret->{status} = 1;
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

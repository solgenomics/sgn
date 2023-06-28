
=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 Name

SGN::Controller::solGS::CachedResult - checks for cached output.

=cut

package SGN::Controller::solGS::CachedResult;

use Moose;
use namespace::autoclean;

use File::Slurp qw /write_file read_file/;
use JSON;

#use Scalar::Util qw /weaken reftype/;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => {
        'application/json' => 'JSON',
        'text/html'        => 'JSON'
    },
);

sub check_cached_result : Path('/solgs/check/cached/result') Args(0) {
    my ( $self, $c ) = @_;

    my $req_page = $c->req->param('page');
    my $args     = $c->req->param('arguments');

    $c->controller('solGS::Utils')->stash_json_args( $c, $args );

    $c->stash->{rest}{arguments} = $args;

    my $json = JSON->new();
    $args = $json->decode($args);

    $self->_check_cached_output( $c, $req_page, $args );

}

sub _check_cached_output {
    my ( $self, $c, $req_page, $args ) = @_;

    $c->stash->{training_traits_ids} =
      $args->{training_traits_ids} || $args->{trait_id};
    my $training_pop_id = $args->{training_pop_id};

    $c->stash->{training_pop_id} =
      ref($training_pop_id) eq 'ARRAY'
      ? $training_pop_id->[0]
      : $training_pop_id;

    $c->stash->{rest}{cached} = undef;

    if ( $req_page =~ /solgs\/population\// ) {
        my $pop_id = $args->{training_pop_id}[0];
        $self->_check_single_trial_training_data( $c, $pop_id );
    }
    elsif ( $req_page =~ /solgs\/populations\/combined\// ) {
        my $pop_id = $args->{training_pops_id}[0] || $args->{combo_pops_id}[0];
        $c->stash->{data_set_type} = $args->{data_set_type};

        $self->_check_combined_trials_data( $c, $pop_id );
    }
    elsif ( $req_page =~ /solgs\/trait\// ) {
        my $pop_id   = $args->{training_pop_id}[0];
        my $trait_id = $args->{trait_id}[0];

        $self->_check_single_trial_model_output( $c, $pop_id, $trait_id );
    }
    elsif ( $req_page =~ /solgs\/model\/combined\/trials\// ) {
        my $pop_id   = $args->{training_pop_id}[0];
        my $trait_id = $args->{trait_id}[0];

        $c->stash->{data_set_type} = $args->{data_set_type};

        $self->_check_combined_trials_model_output( $c, $pop_id, $trait_id );
    }
    elsif ( $req_page =~ /solgs\/selection\/(\d+|\w+_\d+)\/model\// ) {
        my $tr_pop_id  = $args->{training_pop_id}[0];
        my $sel_pop_id = $args->{selection_pop_id}[0];
        my $trait_id   = $args->{trait_id}[0];

        $c->stash->{data_set_type} = $args->{data_set_type};

        my $referer = $c->req->referer;

        if ( $referer =~ /solgs\/traits\/all\// ) {
            $self->_check_selection_pop_all_traits_output( $c, $tr_pop_id,
                $sel_pop_id );
        }
        elsif ( $referer =~ /solgs\/models\/combined\/trials\// ) {
            $self->_check_selection_pop_all_traits_output( $c, $tr_pop_id,
                $sel_pop_id );
        }
        else {
            $self->_check_selection_pop_output( $c, $tr_pop_id, $sel_pop_id,
                $trait_id );
        }
    }
    elsif ( $req_page =~ /solgs\/traits\/all\/population\// ) {
        my $tr_pop_id  = $args->{training_pop_id}[0];
        my $sel_pop_id = $args->{selection_pop_id}[0];
        my $traits_ids = $args->{training_traits_ids};

        $self->_check_single_trial_model_all_traits_output( $c, $tr_pop_id,
            $traits_ids );
    }
    elsif ( $req_page =~ /solgs\/models\/combined\/trials\// ) {
        my $tr_pop_id  = $args->{training_pop_id}[0];
        my $sel_pop_id = $args->{selection_pop_id}[0];
        my $traits     = $args->{training_traits_ids};

        $self->_check_combined_trials_model_all_traits_output( $c, $tr_pop_id,
            $traits );
    }
    elsif ( $req_page =~ /kinship\/analysis/ ) {
        $c->controller('solGS::Kinship')
          ->stash_kinship_pop_id( $c, $args->{kinship_pop_id} );
        my $kinship_pop_id = $c->stash->{kinship_pop_id};
        my $protocol_id    = $args->{genotyping_protocol_id};
        my $trait_id       = $args->{trait_id};

        $self->_check_kinship_output( $c, $kinship_pop_id, $protocol_id,
            $trait_id );
    }
    elsif ( $req_page =~ /pca\/analysis/ ) {
        my $pca_pop_id = $args->{pca_pop_id};
        my $data_str   = $args->{data_structure};

        if ( $data_str =~ /dataset|list/ && $pca_pop_id !~ /dataset|list/ ) {
            $pca_pop_id = $data_str . '_' . $pca_pop_id;
        }

        my $file_id = $c->controller('solGS::Files')->create_file_id($c);
        $self->_check_pca_output( $c, $file_id );
    }
    elsif ( $req_page =~ /cluster\/analysis/ ) {
        my $cluster_pop_id = $args->{cluster_pop_id};
        my $protocol_id    = $args->{genotyping_protocol_id};

        # my
        # my $trait_id     = $args->{trait_id};
        my $data_str = $args->{data_structure};

        if ( $data_str =~ /dataset|list/ && $cluster_pop_id !~ /dataset|list/ )
        {
            $cluster_pop_id = $data_str . '_' . $cluster_pop_id;
        }

        my $file_id = $c->controller('solGS::Files')->create_file_id($c);
        $self->_check_cluster_output( $c, $file_id );
    }

}

sub _check_single_trial_training_data {
    my ( $self, $c, $pop_id ) = @_;

    $c->stash->{rest}{cached} =
      $self->check_single_trial_training_data( $c, $pop_id );

}

sub _check_single_trial_model_output {
    my ( $self, $c, $pop_id, $trait_id ) = @_;

    my $cached_pop_data =
      $self->check_single_trial_training_data( $c, $pop_id );

    if ($cached_pop_data) {
        $c->stash->{rest}{cached} =
          $self->check_single_trial_model_output( $c, $pop_id, $trait_id );
    }
}

sub _check_single_trial_model_all_traits_output {
    my ( $self, $c, $pop_id, $traits_ids ) = @_;

    my $cached_pop_data =
      $self->check_single_trial_training_data( $c, $pop_id );

    $self->check_single_trial_model_all_traits_output( $c, $pop_id,
        $traits_ids );

    foreach my $tr (@$traits_ids) {
        my $tr_cache = $c->stash->{$tr}{cached};

        if ( !$tr_cache ) {
            $c->stash->{rest}{cached} = undef;
            last;
        }
        else {
            $c->stash->{rest}{cached} = 1;
        }
    }
}

sub _check_combined_trials_data {
    my ( $self, $c, $pop_id ) = @_;

    $c->stash->{combo_pops_id} = $pop_id;
    $c->controller('solGS::combinedTrials')->get_combined_pops_list($c);
    my $trials = $c->stash->{combined_pops_list};

    foreach my $trial (@$trials) {
        $self->_check_single_trial_training_data( $c, $trial );
        my $cached = $c->stash->{rest}{cached};

        last if !$c->stash->{rest}{cached};
    }
}

sub _check_combined_trials_model_output {
    my ( $self, $c, $pop_id, $trait_id ) = @_;

    my $cached_pop_data =
      $self->check_combined_trials_training_data( $c, $pop_id, $trait_id );

    if ($cached_pop_data) {
        $c->stash->{rest}{cached} =
          $self->check_single_trial_model_output( $c, $pop_id, $trait_id );
    }

}

sub _check_combined_trials_model_all_traits_output {
    my ( $self, $c, $pop_id, $traits ) = @_;

    $self->check_combined_trials_model_all_traits_output( $c, $pop_id,
        $traits );

    foreach my $tr (@$traits) {
        my $tr_cache = $c->stash->{$tr}{cached};

        if ( !$tr_cache ) {
            $c->stash->{rest}{cached} = undef;
            last;
        }
        else {
            $c->stash->{rest}{cached} = 1;
        }
    }

}

sub _check_selection_pop_all_traits_output {
    my ( $self, $c, $tr_pop_id, $sel_pop_id ) = @_;

    $c->controller('solGS::Gebvs')
      ->selection_pop_analyzed_traits( $c, $tr_pop_id, $sel_pop_id );
    my $sel_traits_ids = $c->stash->{selection_pop_analyzed_traits_ids};

    $c->stash->{training_pop_id} = $tr_pop_id;
    $c->controller("solGS::solGS")->traits_with_valid_models($c);
    my $training_models_traits = $c->stash->{traits_ids_with_valid_models};

    $c->stash->{rest}{cached} = 0;
    if ( $sel_traits_ids->[0] ) {
        if ( scalar(@$sel_traits_ids) == scalar(@$training_models_traits) ) {
            if ( sort(@$sel_traits_ids) ~~ sort(@$training_models_traits) ) {
                $c->stash->{rest}{cached} = 1;
            }
        }
    }

}

sub _check_selection_pop_output {
    my ( $self, $c, $tr_pop_id, $sel_pop_id, $trait_id ) = @_;

    if ( $c->stash->{data_set_type} =~ 'combined_populations' ) {
        $self->_check_combined_trials_model_selection_output( $c, $tr_pop_id,
            $sel_pop_id, $trait_id );
    }
    else {
        $self->_check_single_trial_model_selection_output( $c, $tr_pop_id,
            $sel_pop_id, $trait_id );
    }

}

sub _check_single_trial_model_selection_output {
    my ( $self, $c, $tr_pop_id, $sel_pop_id, $trait_id ) = @_;

    my $cached_pop_data =
      $self->check_single_trial_training_data( $c, $tr_pop_id );

    if ($cached_pop_data) {
        my $cached_model_out =
          $self->check_single_trial_model_output( $c, $tr_pop_id, $trait_id );

        if ($cached_model_out) {
            $c->stash->{rest}{cached} =
              $self->check_selection_pop_output( $c, $tr_pop_id, $sel_pop_id,
                $trait_id );
        }
    }

}

sub _check_combined_trials_model_selection_output {
    my ( $self, $c, $tr_pop_id, $sel_pop_id, $trait_id ) = @_;

    my $cached_tr_data =
      $self->check_combined_trials_training_data( $c, $tr_pop_id, $trait_id );

    if ($cached_tr_data) {
        my $cached_model_out =
          $self->_check_combined_trials_model_output( $c, $tr_pop_id,
            $trait_id );

        if ($cached_model_out) {
            $c->stash->{rest}{cached} =
              $self->check_selection_pop_output( $c, $tr_pop_id, $sel_pop_id,
                $trait_id );
        }
    }

}

sub _check_kinship_output {
    my ( $self, $c, $kinship_pop_id, $protocol_id, $trait_id ) = @_;

    $c->stash->{rest}{cached} =
      $self->check_kinship_output( $c, $kinship_pop_id, $protocol_id,
        $trait_id );
}

sub _check_pca_output {
    my ( $self, $c, $file_id ) = @_;

    $c->stash->{rest} = $self->check_pca_output( $c, $file_id );
}

sub _check_cluster_output {
    my ( $self, $c, $file_id ) = @_;
    my $cached = $self->check_cluster_output( $c, $file_id );
    $c->stash->{rest}{cached} = $self->check_cluster_output( $c, $file_id );
}

sub check_single_trial_training_data {
    my ( $self, $c, $pop_id, $protocol_id ) = @_;

    $protocol_id = $c->stash->{genotyping_protocol_id} if !$protocol_id;
    $c->controller('solGS::genotypingProtocol')
      ->stash_protocol_id( $c, $protocol_id );
    $protocol_id = $c->stash->{genotyping_protocol_id};

    my $cached_pheno = $self->check_cached_phenotype_data( $c, $pop_id );
    my $cached_geno  = $self->check_cached_genotype_data( $c, $pop_id );

    if ( $cached_pheno && $cached_geno ) {
        return 1;
    }
    else {
        return 0;
    }

}

sub check_cached_genotype_data {
    my ( $self, $c, $pop_id ) = @_;

    $c->controller('solGS::Files')->genotype_file_name( $c, $pop_id );
    my $file = $c->stash->{genotype_file_name};

    my $cached;
    if ( -s $file ) {
        my @rows = read_file( $file, { binmode => ':utf8' } );
        $cached = 1 if $rows[1];
    }

    return $cached;

}

sub check_cached_phenotype_data {
    my ( $self, $c, $pop_id ) = @_;

    $c->controller('solGS::Files')->phenotype_file_name( $c, $pop_id );
    my $file = $c->stash->{phenotype_file_name};

    my $cached;
    if ( -s $file ) {
        my @rows = read_file( $file, { binmode => ':utf8' } );
        $cached = 1 if $rows[1];
    }

    return $cached;

}

sub check_single_trial_model_output {
    my ( $self, $c, $pop_id, $trait_id, $protocol_id ) = @_;

    $c->stash->{trait_id} = $trait_id;
    $c->stash->{training_pop_id} = $pop_id;

    $c->controller('solGS::Files')
      ->rrblup_training_gebvs_file( $c, $pop_id, $trait_id, $protocol_id );
    my $cached_gebv = -s $c->stash->{rrblup_training_gebvs_file};

    if ($cached_gebv) {
        return 1;
    }
    else {
        return 0;
    }

}

sub check_single_trial_model_all_traits_output {
    my ( $self, $c, $pop_id, $traits_ids ) = @_;

    my $cached_pop_data =
      $self->check_single_trial_training_data( $c, $pop_id );

    if ($cached_pop_data) {
        foreach my $tr (@$traits_ids) {
            $c->stash->{$tr}{cached} =
              $self->check_single_trial_model_output( $c, $pop_id, $tr );
        }
    }

}

sub check_combined_trials_model_all_traits_output {
    my ( $self, $c, $pop_id, $traits_ids ) = @_;

    foreach my $tr (@$traits_ids) {
        my $cached_tr_data =
          $self->check_combined_trials_training_data( $c, $pop_id, $tr );

        if ($cached_tr_data) {
            $c->stash->{$tr}{cached} =
              $self->check_single_trial_model_output( $c, $pop_id, $tr );
        }
    }

}

sub check_selection_pop_output {
    my ( $self, $c, $tr_pop_id, $sel_pop_id, $trait_id ) = @_;

    $c->stash->{trait_id} = $trait_id;
    $c->stash->{training_pop_id} = $tr_pop_id;
    $c->stash->{selection_pop_id} = $sel_pop_id;

    $c->controller('solGS::Files')
      ->rrblup_selection_gebvs_file( $c, $tr_pop_id, $sel_pop_id, $trait_id );
    my $cached_gebv = -s $c->stash->{rrblup_selection_gebvs_file};

    if ($cached_gebv) {
        return 1;
    }
    else {
        return 0;
    }

}

sub check_selection_pop_all_traits_output {
    my ( $self, $c, $tr_pop_id, $sel_pop_id ) = @_;

    $c->controller('solGS::Gebvs')
      ->selection_pop_analyzed_traits( $c, $tr_pop_id, $sel_pop_id );
    my $traits_ids = $c->stash->{selection_pop_analyzed_traits_ids};

    foreach my $tr (@$traits_ids) {
        $c->stash->{$tr}{cached} =
          $self->check_selection_pop_output( $c, $tr_pop_id, $sel_pop_id, $tr );
    }

}

sub check_combined_trials_training_data {
    my ( $self, $c, $combo_pops_id, $trait_id ) = @_;

    $c->controller('solGS::Trait')->get_trait_details( $c, $trait_id );
    $c->stash->{combo_pops_id} = $combo_pops_id;

    $c->controller('solGS::combinedTrials')->cache_combined_pops_data($c);

    my $cached_pheno = -s $c->stash->{trait_combined_pheno_file};
    my $cached_geno  = -s $c->stash->{trait_combined_geno_file};

    if ( $cached_pheno && $cached_geno ) {
        return 1;
    }
    else {
        return 0;
    }

}

sub check_multi_trials_training_data {
    my ( $self, $c, $trials_ids, $protocol_id ) = @_;

    my $cached;

    foreach my $trial_id (@$trials_ids) {
        my $exists = $self->check_single_trial_training_data( $c, $trial_id,
            $protocol_id );

        if ( !$exists ) {
            last;
        }
        else {
            $cached = $exists;
        }
    }

    return $cached;

}

sub check_kinship_output {
    my ( $self, $c, $pop_id, $protocol_id, $trait_id ) = @_;

    my $files = $c->controller('solGS::Kinship')
      ->get_kinship_coef_files( $c, $pop_id, $protocol_id, $trait_id );

    my $cached =
      -s $files->{'json_file_adj'} && -s $files->{'matrix_file_adj'} ? 1 : 0;

    return $cached;

}

sub check_pca_output {
    my ( $self, $c, $file_id ) = @_;

    if ($file_id) {
        $c->stash->{file_id} = $file_id;
        $c->controller('solGS::pca')->pca_scores_file($c);
        my $scores_file = $c->stash->{pca_scores_file};

        if ( -s $scores_file ) {
            $c->controller('solGS::pca')->prepare_pca_output_response($c);
            my $ret = $c->stash->{pca_output_response};
            return $ret;
        }
        else {
            my $ret = { scores_file => 0 };
        }
    }

}

sub check_cluster_output {
    my ( $self, $c, $file_id ) = @_;

    if ($file_id) {
        $c->stash->{file_id} = $file_id;

        my $cluster_type = $c->stash->{cluster_type};
        my $cached_file;
        if ( $cluster_type =~ /k-means/i ) {
            $c->controller('solGS::Cluster')->cluster_result_file($c);
            $cached_file = $c->stash->{"${cluster_type}_result_file"};
        }
        else {
            $c->controller('solGS::Cluster')->cluster_result_file($c);
            $cached_file = $c->stash->{"${cluster_type}_result_newick_file"};
        }
        if ( -s $cached_file ) {
            return 1;
        }
        else {
            return 0;
        }
    }

}

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

#####
1;    ###
####

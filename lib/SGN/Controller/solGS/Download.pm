package SGN::Controller::solGS::Download;


use Moose;
use namespace::autoclean;


BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => {
        'application/json' => 'JSON'
    },
);


sub download_training_pop_data :Path('/solgs/download/training/pop/data') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    $c->stash->{rest}{training_pop_raw_geno_file} = $self->download_raw_geno_data_file($c);
    $c->stash->{rest}{training_pop_raw_pheno_file} = $self->download_raw_pheno_data_file($c);
    $c->stash->{rest}{traits_acronym_file} = $self->download_traits_acronym_file($c);

}

sub download_selection_pop_data :Path('/solgs/download/selection/pop/data') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $geno_file = $self->download_selection_pop_filtered_geno_data_file($c);
    my $log_file = $self->download_selection_prediction_report_file($c);

    $c->stash->{rest}{selection_pop_filtered_geno_file} = $geno_file;
    $c->stash->{rest}{selection_prediction_report_file} = $log_file;
}

sub download_model_input_data :Path('/solgs/download/model/input/data') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $geno_file = $self->download_model_geno_data_file($c);
    my $pheno_file = $self->download_model_pheno_data_file($c);
    my $log_file = $self->download_model_analysis_report_file($c);

    $c->stash->{rest}{model_geno_data_file} = $geno_file;
    $c->stash->{rest}{model_pheno_data_file} = $pheno_file;
    $c->stash->{rest}{model_analysis_report_file} = $log_file;

}

sub download_gebvs :Path('/solgs/download/gebvs/pop') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $gebvs_file;
    my $genetic_values_file;
    my $type;

    if ($c->stash->{selection_pop_id}) {
        $type = 'selection';
        $gebvs_file = $self->download_selection_gebvs_file($c);
        $genetic_values_file = $self->download_selection_genetic_values_file($c);
    } else {
        $type = 'training';
        $gebvs_file = $self->download_training_gebvs_file($c);
        $genetic_values_file = $self->download_training_genetic_values_file($c);
    }

    my $file_id = $c->controller('solGS::Files')->gebvs_file_id($c, $type);

    $c->stash->{rest}{gebvs_file} = $gebvs_file;
    $c->stash->{rest}{genetic_values_file} = $genetic_values_file;
    $c->stash->{rest}{gebvs_file_id} = $file_id;

}

sub download_marker_effects :Path('/solgs/download/model/marker/effects') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $marker_effects_file = $self->download_marker_effects_file($c);
    $c->stash->{rest}{marker_effects_file} = $marker_effects_file;
    
}

sub download_traits_acronym :Path('/solgs/download/traits/acronym') Args(0) {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $acronyms_file = $self->download_traits_acronym_file($c);
    $c->stash->{rest}{traits_acronym_file} = $acronyms_file;
    
}

sub selection_prediction_download_urls {
    my ($self, $c, $training_pop_id, $selection_pop_id) = @_;

    my $training_model_traits_ids = $c->stash->{training_traits_ids} || [$c->stash->{trait_id}];
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    no warnings 'uninitialized';

    my $url_args = {
      'training_pop_id' => $training_pop_id,
      'selection_pop_id' => $selection_pop_id,
      'genotyping_protocol_id' => $protocol_id,
    };

    my $selection_pop_analyzed_traits_ids;

    if ($selection_pop_id) {
        $c->controller('solGS::Gebvs')->selection_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
        $selection_pop_analyzed_traits_ids = $c->stash->{selection_pop_analyzed_traits_ids};
    }

    my @selection_pop_traits_ids;
    @selection_pop_traits_ids = sort(@$selection_pop_analyzed_traits_ids) if $selection_pop_analyzed_traits_ids->[0];
    my @selected_model_traits_ids;
    @selected_model_traits_ids = sort(@$training_model_traits_ids) if $training_model_traits_ids->[0];

    my $page = $c->req->referer;
    my $data_set_type = $page =~ /combined/ ? 'combined_populations' : 'single_population';
    $url_args->{data_set_type} = $data_set_type;

    my $sel_pop_page;
    my $download_url;

    if (@selected_model_traits_ids ~~ @selection_pop_traits_ids) {
        foreach my $trait_id (@selection_pop_traits_ids) {
            $url_args->{trait_id} = $trait_id;

            $c->controller('solGS::Trait')->get_trait_details($c, $trait_id);
            my $trait_abbr = $c->stash->{trait_abbr};

            $sel_pop_page =  $c->controller('solGS::Path')->selection_page_url($url_args);

            if ($page =~ /solgs\/traits\/all\/|solgs\/models\/combined\//) {
                $download_url .= " | " if $download_url;
            }

            $download_url .= qq |<a href="$sel_pop_page">$trait_abbr</a> |;
        }
    }

    if (!$download_url) {
        my $trait_id = $selected_model_traits_ids[0];
        $url_args->{trait_id} = $trait_id;

        $sel_pop_page =  $c->controller('solGS::Path')->selection_page_url($url_args);
        $download_url = qq | <a href ="$sel_pop_page"  onclick="solGS.waitPage(this.href); return false;">[ Predict ]</a>|;
    }

    $c->stash->{selection_prediction_download} = $download_url;

}

sub download_raw_pheno_data_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{training_pop_id};
    my $data_set_type = $c->stash->{data_set_type};

    my @trials_ids;
    if ($data_set_type =~ /combined_populations/) {
        my $trials_ids = $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $pop_id);
        @trials_ids = @$trials_ids;
    } else {
        push @trials_ids, $pop_id;
    }

    my @files;

    foreach my $trial_id (@trials_ids) {
        my $file = $c->controller('solGS::Files')->phenotype_file_name($c, $trial_id);
        $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

        push @files, $file;
    }

    return \@files;

}

sub download_raw_geno_data_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{training_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $data_set_type = $c->stash->{data_set_type};

    my @trials_ids;
    if ($data_set_type =~ /combined_populations/) {
        my $trials_ids = $c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $pop_id);
        @trials_ids = @$trials_ids;
    } else {
        push @trials_ids, $pop_id;
    }

    my @files;

    foreach my $trial_id (@trials_ids) {
        my $file = $c->controller('solGS::Files')->genotype_file_name($c, $trial_id, $protocol_id);
        $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

        push @files, $file;
    }

    return \@files;

}

sub download_selection_pop_filtered_geno_data_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->filtered_selection_genotype_file($c);
    my $file = $c->stash->{filtered_selection_genotype_file};
    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

    return $file;

}


sub download_model_geno_data_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Trait')->get_trait_details($c, $c->stash->{trait_id});

    my $file = $c->controller('solGS::Files')->model_genodata_file($c);
    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

    return $file;

}

sub download_model_pheno_data_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Trait')->get_trait_details($c, $c->stash->{trait_id});
    
    my $file = $c->controller('solGS::Files')->model_phenodata_file($c);
    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

    return $file;

}

sub download_model_analysis_report_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Trait')->get_trait_details($c, $c->stash->{trait_id});

    my $page = $c->controller('solGS::Path')->page_type($c, $c->req->referer);

    if ($page =~ /training_model/) {
        $c->stash->{analysis_type} =  'training_model';
    }

    my $file = $c->controller('solGS::Files')->analysis_report_file($c);
    #$file = $c->controller('solGS::Files')->convert_txt_pdf($file);

    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

    return $file;

}

sub download_selection_prediction_report_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Trait')->get_trait_details($c, $c->stash->{trait_id});

    my $referer = $c->req->referer;
    $c->stash->{analysis_type} = $c->controller('solGS::Path')->page_type($c, $referer);
    
    my $file = $c->controller('solGS::Files')->analysis_report_file($c);
    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

    return $file;

}

sub download_training_gebvs_file {
    my ($self, $c) = @_;

    my $training_pop_id = $c->stash->{training_pop_id};
    my $trait_id = $c->stash->{trait_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    
    $c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $trait_id, $protocol_id);
    my $gebvs_file = $c->stash->{rrblup_training_gebvs_file};

    $gebvs_file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $gebvs_file, 'solgs');

    return $gebvs_file;

}

sub download_training_genetic_values_file {
    my ($self, $c) = @_;

    my $training_pop_id = $c->stash->{training_pop_id};
    my $trait_id = $c->stash->{trait_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    
    $c->controller('solGS::Files')->rrblup_training_genetic_values_file($c, $training_pop_id, $trait_id, $protocol_id);
    my $genetic_values_file = $c->stash->{rrblup_training_genetic_values_file};

    $genetic_values_file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $genetic_values_file, 'solgs');

    return $genetic_values_file;

}

sub download_selection_gebvs_file {
    my ($self, $c) = @_;

    my $training_pop_id = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $trait_id = $c->stash->{trait_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    
    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id, $protocol_id);
    my $gebvs_file = $c->stash->{rrblup_selection_gebvs_file};

    $gebvs_file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $gebvs_file, 'solgs');

    return $gebvs_file;

}

sub download_selection_genetic_values_file {
    my ($self, $c) = @_;

    my $training_pop_id = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $trait_id = $c->stash->{trait_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    
    $c->controller('solGS::Files')->rrblup_selection_genetic_values_file($c, $training_pop_id, $selection_pop_id, $trait_id, $protocol_id);
    my $genetic_values_file = $c->stash->{rrblup_selection_genetic_values_file};

    $genetic_values_file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $genetic_values_file, 'solgs');

    return $genetic_values_file;

}

sub download_marker_effects_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Trait')->get_trait_details($c, $c->stash->{trait_id});
    
    my $file = $c->controller('solGS::Files')->marker_effects_file($c);
    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

    return $file;
}

sub download_traits_acronym_file {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->traits_acronym_file($c, $c->stash->{training_pop_id});
    my $file = $c->stash->{traits_acronym_file};

    $file = $c->controller('solGS::Files')->copy_to_tempfiles_subdir($c, $file, 'solgs');

    return $file;
}

sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

#####
1;
#####

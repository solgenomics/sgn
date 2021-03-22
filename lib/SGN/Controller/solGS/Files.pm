package SGN::Controller::solGS::Files;

use Moose;
use namespace::autoclean;

use File::Basename;
use File::Copy;
use File::Path qw / mkpath  /;
use File::Temp qw / tempfile tempdir /;
use File::Spec::Functions qw / catfile catdir/;
use File::Slurp qw /write_file read_file/;
use Cache::File;
use CXGN::People::Person;

BEGIN { extends 'Catalyst::Controller' }


sub marker_effects_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $trait  = $c->stash->{trait_abbr};

    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $file_id = "${pop_id}-${trait}-GP-${protocol_id}";

    no warnings 'uninitialized';

    my $data_set_type = $c->stash->{data_set_type};

    my   $cache_data = {key    => 'marker_effects_' . $file_id,
                      file      => 'marker_effects_' . $file_id . '.txt',
                      stash_key => 'marker_effects_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
       };

    $self->cache_file($c, $cache_data);

}


sub variance_components_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{training_pop_id} || $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};

    my $data_set_type = $c->stash->{data_set_type};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $file_id = "${pop_id}-${trait}-GP-${protocol_id}";

    no warnings 'uninitialized';


    my $cache_data = {key    => 'variance_components_' . $file_id,
		      file      => 'variance_components_' . $file_id. '.txt',
		      stash_key => 'variance_components_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);
}


sub model_phenodata_file {
    my ($self, $c) = @_;

    my $pop_id        = $c->stash->{pop_id} || $c->stash->{combo_pops_id} ;
    my $trait_abbr    = $c->stash->{trait_abbr};
    my $protocol_id   = $c->stash->{genotyping_protocol_id};

    my $id =   "${pop_id}-${trait_abbr}-${protocol_id}";
    if ($trait_abbr)
    {
	no warnings 'uninitialized';

	my $cache_data = {key       => 'model_phenodata_' . $id,
			  file      => 'model_phenodata_' .  $id . '.txt',
			  stash_key => 'model_phenodata_file',
			  cache_dir => $c->stash->{solgs_cache_dir}
	};

	$self->cache_file($c, $cache_data);
    }
}


sub model_info_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{combo_pops_id};
    my $trait_id = $c->stash->{trait_id};
    my $trait_abbr = $c->stash->{trait_abbr};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $file_id  = "${trait_id}-${pop_id}-GP-${protocol_id}";

    my $cache_data = { key       => 'model_info_file_' . $file_id,
                       file      => 'model_info_file_' . $file_id . '.txt',
                       stash_key => 'model_info_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);
}


sub filtered_training_genotype_file {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $pop_id = $c->stash->{training_pop_id} || $c->stash->{pop_id} || $c->{stash}->{combo_pops_id} if !$pop_id;

    $protocol_id = $c->stash->{genotyping_protocol_id} if !$protocol_id;
    my $file_id = "${pop_id}-GP-${protocol_id}";

    my $cache_data = { key       => 'filtered_genotype_data_' . $file_id,
                       file      => 'filtered_genotype_data_' . $file_id . '.txt',
                       stash_key => 'filtered_training_genotype_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);
}


sub filtered_selection_genotype_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{prediction_pop_id} || $c->stash->{selection_pop_id};

    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $file_id = "${pop_id}-GP-${protocol_id}";

    my $cache_data = { key       => 'filtered_genotype_data_' . $file_id,
                       file      => 'filtered_genotype_data_' . $file_id . '.txt',
                       stash_key => 'filtered_selection_genotype_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);
}


sub formatted_phenotype_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id};
    $pop_id = $c->{stash}->{combo_pops_id} if !$pop_id;

    my $cache_data = { key       => 'formatted_phenotype_data_' . $pop_id,
                       file      => 'formatted_phenotype_data_' . $pop_id . '.txt',
                       stash_key => 'formatted_phenotype_file',
		       cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);
}


sub phenotype_file_name {
    my ($self, $c, $pop_id, $trait_id) = @_;

    $pop_id = $c->stash->{pop_id} || $c->{stash}->{combo_pops_id} if !$pop_id;
    # my $trait_id = $c-stash->{trait_id} if !$trait_id;

    # if
    my $dir;
    if ($pop_id =~ /list/)
    {
	$dir = $c->stash->{solgs_lists_dir};
    }
    elsif ($pop_id =~ /dataset/)
    {
	$dir = $c->stash->{solgs_datasets_dir};
    }
    else
    {
	$dir = $c->stash->{solgs_cache_dir};
    }

    my $cache_data = { key       => 'phenotype_data_' . $pop_id,
		       file      => 'phenotype_data_' . $pop_id . '.txt',
		       stash_key => 'phenotype_file_name',
		       cache_dir => $dir
    };

    $self->cache_file($c, $cache_data);

	return $c->stash->{phenotype_file_name};
	
}


sub analysis_error_file {
    my ($self, $c) = @_;

    my $type      = $c->stash->{analysis_type};
    my $cache_dir = $c->stash->{cache_dir}  || $c->stash->{solgs_cache_dir};
    my $file_id   = $c->stash->{file_id};

    my $name = "${type}_error_${file_id}";

    my $cache_data = { key       => $name,
		       file      => $name . '.txt',
		       cache_dir => $cache_dir,
		       stash_key => "${type}_error_file",
    };

    $self->cache_file($c, $cache_data);

}


sub analysis_report_file {
    my ($self, $c) = @_;

    my $type      = $c->stash->{analysis_type};
    my $cache_dir = $c->stash->{cache_dir} || $c->stash->{solgs_cache_dir};
    my $file_id   = $c->stash->{file_id};

    my	$name = "${type}_report_${file_id}";

    my $cache_data = { key       => $name,
		       file      => $name . '.txt',
		       cache_dir => $cache_dir,
		       stash_key => "${type}_report_file",
    };

    $self->cache_file($c, $cache_data);

}


sub genotype_file_name {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $protocol_id = $c->stash->{genotyping_protocol_id} if !$protocol_id;

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $protocol_id = $c->stash->{genotyping_protocol_id};

    my $dir;
    if ($pop_id =~ /list/)
    {
	$dir = $c->stash->{solgs_lists_dir};
    }
    elsif ($pop_id =~ /dataset/)
    {
	$dir = $c->stash->{solgs_datasets_dir};
    }
    else
    {
	$dir = $c->stash->{solgs_cache_dir};
    }

    my $file_id = $pop_id . '-GP-' . $protocol_id;

    my $cache_data = { key       => 'genotype_data_' . $file_id,
		       file      => 'genotype_data_' . $file_id . '.txt',
		       stash_key => 'genotype_file_name',
		       cache_dir => $dir
    };

    $self->cache_file($c, $cache_data);

}


sub relationship_matrix_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $data_set_type = $c->stash->{data_set_type};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $file_id = $pop_id . '_GP_' . $protocol_id;

    no warnings 'uninitialized';

    my $cache_data = {key    => 'relationship_matrix_table_' . $file_id ,
		      file      => 'relationship_matrix_table_' . $file_id . '.txt',
		      stash_key => 'relationship_matrix_table_file',
		      cache_dir => $c->stash->{kinship_cache_dir}
    };

    $self->cache_file($c, $cache_data);

    my $cache_data = {key    => 'relationship_matrix_json_' . $file_id ,
		      file      => 'relationship_matrix_json_' . $file_id . '.txt',
		      stash_key => 'relationship_matrix_json_file',
		      cache_dir => $c->stash->{kinship_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub relationship_matrix_adjusted_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $data_set_type = $c->stash->{data_set_type};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $trait_abbr = $c->stash->{trait_abbr} || $pop_id;

    my $file_id = $pop_id ."_${trait_abbr}_GP_${protocol_id}";

    no warnings 'uninitialized';

    my $cache_data = {key    => 'relationship_matrix_table_' . $file_id ,
		      file      => 'relationship_matrix_adjusted_table_' . $file_id . '.txt',
		      stash_key => 'relationship_matrix_adjusted_table_file',
		      cache_dir => $c->stash->{kinship_cache_dir}
    };

    $self->cache_file($c, $cache_data);

    my $cache_data = {key    => 'relationship_matrix_json_' . $file_id ,
		      file      => 'relationship_matrix_adjusted_json_' . $file_id . '.txt',
		      stash_key => 'relationship_matrix_adjusted_json_file',
		      cache_dir => $c->stash->{kinship_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub average_kinship_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $trait_abbr = $c->stash->{trait_abbr} || $pop_id;

    my $file_id =  $trait_abbr ? "${pop_id}_${trait_abbr}_GP_${protocol_id}" : "${pop_id}_GP_${protocol_id}";

    no warnings 'uninitialized';

    my $cache_data = {key    => 'average_kinship_file' . $file_id ,
		      file      => 'average_kinship_file_' . $file_id . '.txt',
		      stash_key => 'average_kinship_file',
		      cache_dir => $c->stash->{kinship_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub inbreeding_coefficients_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $file_id = "${pop_id}_GP_${protocol_id}";

    no warnings 'uninitialized';

    my $cache_data = {key    => 'inbreeding_coefficients' . $file_id ,
		      file      => 'inbreeding_coefficients_' . $file_id . '.txt',
		      stash_key => 'inbreeding_coefficients_file',
		      cache_dir => $c->stash->{kinship_cache_dir}
    };


    $self->cache_file($c, $cache_data);

}


sub validation_file {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{training_pop_id} || $c->stash->{pop_id};
    my $trait  = $c->stash->{trait_abbr};

    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $file_id = $pop_id . '-' . $trait . '-GP-' . $protocol_id;


    my $data_set_type = $c->stash->{data_set_type};
    no warnings 'uninitialized';


    my $cache_data = {
	key       => 'cross_validation_' . $file_id,
	file      => 'cross_validation_' . $file_id . '.txt',
	stash_key => 'validation_file',
	cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);
}


sub combined_gebvs_file {
    my ($self, $c, $identifier) = @_;

    my $pop_id = $c->stash->{pop_id};

    my $cache_data = {
	key       => 'selected_traits_gebv_' . $pop_id . '_' . $identifier,
	file      => 'selected_traits_gebv_' . $pop_id . '_' . $identifier . '.txt',
	stash_key => 'selected_traits_gebv_file',
	cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub trait_phenotype_file {
    my ($self, $c, $pop_id, $trait) = @_;

    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $dir = $c->stash->{solgs_cache_dir};
    my $exp = "phenotype_data_${trait}_${pop_id}";
    my $file = $self->grep_file($dir, $exp);

    $c->stash->{trait_phenotype_file} = $file;

}


sub all_traits_file {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{pop_id} ||  $c->stash->{training_pop_id} if !$pop_id;

    my $cache_data = {key       => 'all_traits_pop' . $pop_id,
                      file      => 'all_traits_pop_' . $pop_id . '.txt',
                      stash_key => 'all_traits_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub traits_list_file {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id} if !$pop_id;

    my $cache_data = {key       => 'traits_list_pop' . $pop_id,
                      file      => 'traits_list_pop_' . $pop_id . '.txt',
                      stash_key => 'traits_list_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub population_metadata_file {
    my ($self, $c, $dir, $file_id) = @_;

    my $user_id;
    my $owner_id;

    if ($c->stash->{list_id})
    {
	my $list = CXGN::List->new({ dbh => $c->dbc()->dbh(),
				     list_id => $c->stash->{list_id}
				   });

	$owner_id = $list->owner;

    }
    elsif ($c->stash->{dataset_id})
    {
	$owner_id = $c->model('solGS::solGS')->get_dataset_owner($c->stash->{dataset_id});
    }

    my $person = CXGN::People::Person->new($c->dbc()->dbh(), $owner_id);
    $user_id = $person->get_username();

    my $cache_data = {key       => "metadata_${user_id}_${file_id}",
                      file      => "metadata_${user_id}_${file_id}",
                      stash_key => 'population_metadata_file',
		      cache_dir => $dir,
    };

    $self->cache_file($c, $cache_data);

}


sub phenotype_metadata_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'phenotype_metadata',
                      file      => 'phenotype_metadata' . '.txt',
                      stash_key => 'phenotype_metadata_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub rrblup_training_gebvs_file {
    my ($self, $c, $identifier, $trait_id) = @_;

    $identifier = $c->stash->{pop_id} || $c->stash->{training_pop_id} || $c->stash->{combo_pops_id} if !$identifier;
    $trait_id  = $c->stash->{trait_id} if !$trait_id;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr  = $c->stash->{trait_abbr};

    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $file_id = "$identifier-${trait_abbr}-GP-${protocol_id}";

    my $cache_data = {key       => 'rrblup_training_gebvs_' . $file_id,
                      file      => 'rrblup_training_gebvs_' . $file_id  . '.txt',
                      stash_key => 'rrblup_training_gebvs_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub rrblup_selection_gebvs_file {
    my ($self, $c, $training_pop_id, $selection_pop_id, $trait_id) = @_;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr  = $c->stash->{trait_abbr};

    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $file_id = "${training_pop_id}_${selection_pop_id}-${trait_abbr}-GP-${protocol_id}";

    my $cache_data = {key       => 'rrblup_selection_gebvs_' . $file_id,
                      file      => 'rrblup_selection_gebvs_' . $file_id . '.txt',
                      stash_key => 'rrblup_selection_gebvs_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub list_of_prediction_pops_file {
    my ($self, $c, $training_pop_id)= @_;

    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $file_id = $training_pop_id . '-GP-' . $protocol_id;

    my $cache_data = {key       => 'list_of_prediction_pops_' . $file_id,
                      file      => 'list_of_prediction_pops_' . $file_id . '.txt',
                      stash_key => 'list_of_prediction_pops_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub first_stock_genotype_file {
    my ($self, $c, $pop_id, $protocol_id) = @_;

    $protocol_id = $c->stash->{genotyping_protocol_id} if !$protocol_id;

    my $file_id = $pop_id . '-GP-' . $protocol_id;

    my $cache_data = {key       => 'first_stock_genotype_file_'. $file_id,
                      file      => 'first_stock_genotype_file_' . $file_id . '.txt',
                      stash_key => 'first_stock_genotype_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub selection_population_file {
    my ($self, $c, $pred_pop_id) = @_;

    my $tmp_dir = $c->stash->{solgs_tempfiles_dir};

    my $file = "selection_population_file_${pred_pop_id}";
    my $tempfile = $self->create_tempfile($tmp_dir, $file);

    $c->stash->{prediction_pop_id} = $pred_pop_id;
    $c->stash->{selection_pop_id}  = $pred_pop_id;
    $self->filtered_selection_genotype_file($c);
    my $filtered_geno_file = $c->stash->{filtered_selection_genotype_file};

    my $geno_files = $filtered_geno_file;

    $self->genotype_file_name($c, $pred_pop_id);
    $geno_files .= "\t" . $c->stash->{genotype_file_name};

    write_file($tempfile, {binmode => ':utf8'}, $geno_files);

    $c->stash->{selection_population_file} = $tempfile;

}


sub traits_acronym_file {
    my ($self, $c, $pop_id) = @_;

    my $cache_data = {key       => 'traits_acronym_pop' . $pop_id,
                      file      => 'traits_acronym_pop_' . $pop_id . '.txt',
                      stash_key => 'traits_acronym_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $self->cache_file($c, $cache_data);

}


sub template {
    my ($self, $file) = @_;

    $file =~ s/(^\/)//;
    my $dir = '/solgs';

    return  catfile($dir, $file);

}


sub cache_file {
    my ($self, $c, $cache_data) = @_;

    my $cache_dir = $cache_data->{cache_dir} || $c->stash->{cache_dir} ||  $c->stash->{solgs_cache_dir};

    my $file_cache  = Cache::File->new(cache_root => $cache_dir,
				       lock_level => Cache::File::LOCK_NFS()
	);

    $file_cache->purge();

    my $file  = $file_cache->get($cache_data->{key});

    no warnings 'uninitialized';

    unless (-s $file > 1)
    {
        $file = catfile($cache_dir, $cache_data->{file});

        write_file($file, {binmode => ':utf8'});
        $file_cache->set($cache_data->{key}, $file, '30 days');
    }

    $c->stash->{$cache_data->{stash_key}} = $file;

}


sub create_file_id {
    my ($self, $c) = @_;

    my $training_pop_id  = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $data_structure   = $c->stash->{data_structure};
    my $list_id          = $c->stash->{list_id};
    my $list_type        = $c->stash->{list_type};
    my $dataset_id       = $c->stash->{dataset_id};
    my $cluster_type     = $c->stash->{cluster_type};
    my $combo_pops_id    = $c->stash->{combo_pops_id};
    my $data_type        = $c->stash->{data_type};
    my $k_number         = $c->stash->{k_number};
    my $sindex_name      = $c->stash->{sindex_weigths} || $c->stash->{sindex_name};
    my $sel_prop         = $c->stash->{selection_proportion};
    my $protocol_id      = $c->stash->{genotyping_protocol_id};
    my $cluster_pop_id   = $c->stash->{cluster_pop_id};

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $protocol_id = $c->stash->{genotyping_protocol_id};

    my $traits_ids = $c->stash->{training_traits_ids};
    my @traits_ids =  @{$traits_ids} if $traits_ids->[0];

    my $trait_id =  $c->stash->{trait_id} if !@{$traits_ids};
    my $traits_selection_id;
    if (scalar(@traits_ids > 1))
    {
	$traits_selection_id = $c->controller('solGS::TraitsGebvs')->create_traits_selection_id($traits_ids);
    }
    elsif (scalar(@traits_ids == 1))
    {
	$trait_id = $traits_ids[0];
    }

    my $file_id;
    my $referer = $c->req->referer;

    my $selection_pages = 'solgs\/selection\/'
	. '|solgs\/combined\/model\/\d+\/selection\/'
	. '|/solgs\/traits\/all\/population\/'
	. '|solgs\/models\/combined\/trials\/';


    if ($referer =~ /cluster\/analysis\/|\/solgs\/model\/combined\/populations\// && $combo_pops_id)
    {
	$c->controller('solGS::combinedTrials')->get_combined_pops_list($c, $combo_pops_id);
        $c->stash->{pops_ids_list} = $c->stash->{combined_pops_list};
	$file_id = $combo_pops_id;
	$c->stash->{data_set_type} = 'combined_populations';
    }
    elsif ($referer =~ /$selection_pages/)
    {
	if ($selection_pop_id)
	{
	    $file_id =  $selection_pop_id  && $selection_pop_id != $training_pop_id ?
		$training_pop_id . '-' . $selection_pop_id :
		$training_pop_id;
	}
	else
	{
	    $file_id =  $cluster_pop_id && $cluster_pop_id != $training_pop_id ?
		$training_pop_id . '-' . $cluster_pop_id :
		$training_pop_id;
	}

    }
    else
    {
	$file_id = $training_pop_id;
    }

    if ($data_structure =~ /list/)
    {
	$file_id = "list_${list_id}";
    }
    elsif ($data_structure =~ /dataset/)
    {
	$file_id = "dataset_${dataset_id}";
    }

    if ($sindex_name)
    {
	if ($sindex_name ne $selection_pop_id)
	{
	    $file_id = $sindex_name ? $file_id . '-' . $sindex_name : $file_id;
	}
    }

    if (!$sindex_name)
    {
	$file_id = $file_id . '-traits-' . $traits_selection_id if $traits_selection_id;
    }

    if (!$traits_selection_id && $trait_id)
    {
	$file_id = $file_id . '-' . $trait_id;
    }


    $file_id = $data_type ? $file_id . '-' . $data_type : $file_id;
    $file_id = $k_number  ? $file_id . '-k-' . $k_number : $file_id;
    $file_id = $protocol_id && $data_type =~ /genotype/i ? $file_id . '-gp-' . $protocol_id : $file_id;

    if ($sindex_name)
    {
	$file_id = $sel_prop ? $file_id . '-sp-' . $sel_prop : $file_id;
    }

    return $file_id;

}


sub format_cluster_output_url {
    my ($self, $c, $path) = @_;

    my $pop_id = $c->stash->{pop_id};

    my $host = $c->req->base;

    if ( $host !~ /localhost/)
    {
	$host =~ s/:\d+//;
	$host =~ s/http\w?/https/;
    }

    my $end = substr($path, -1, 1);
    my $front = substr($path, 0, 1);

    $path = $path . '/' if $end !~ /\//;
    $path =~ s/\///  if $front =~ /\//;

    my $output_link = $host . $path . $pop_id;

    return $output_link;
}


sub create_tempfile {
    my ($self, $dir, $name, $ext) = @_;

    $ext = '.' . $ext if $ext;

    my ($fh, $file) = tempfile($name . "-XXXXX",
			       SUFFIX => $ext,
                               DIR => $dir,
        );

    $fh->close;

    return $file;

}


sub copy_file {
    my ($self, $file, $dir) = @_;

    mkpath($dir, 0, 755);

    copy($file, $dir)
	or die "could not copy $file to $dir";

    return catfile($dir, basename($file));
}


sub grep_file {
    my ($self, $dir, $exp) = @_;

    opendir my $dh, $dir
        or die "can't open $dir: $!\n";

    my ($file)  = grep { /^$exp/ && -f "$dir/$_" }  readdir($dh);
    close $dh;

    if ($file)
    {
        $file = catfile($dir, $file);
    }

    return $file;
}


sub get_solgs_dirs {
    my ($self, $c) = @_;

    my $geno_version    = $c->config->{default_genotyping_protocol};
    $geno_version       = 'analysis-data' if ($geno_version =~ /undefined/) || !$geno_version;
    $geno_version       =~ s/\s+//g;
    my $tmp_dir         = $c->site_cluster_shared_dir;
    $tmp_dir            = catdir($tmp_dir, $geno_version);
    my $solgs_dir       = catdir($tmp_dir, "solgs");
    my $solgs_cache     = catdir($tmp_dir, 'solgs', 'cache');
    my $solgs_tempfiles = catdir($tmp_dir, 'solgs', 'tempfiles');
    my $solqtl_cache    = catdir($tmp_dir, 'solqtl', 'cache');
    my $solqtl_tempfiles = catdir($tmp_dir, 'solqtl', 'tempfiles');
    my $solgs_lists     = catdir($tmp_dir, 'solgs', 'tempfiles', 'lists');
    my $solgs_datasets  = catdir($tmp_dir, 'solgs', 'tempfiles', 'datasets');
    my $histogram_cache = catdir($tmp_dir, 'histogram', 'cache');
    my $histogram_temp  = catdir($tmp_dir, 'histogram', 'tempfiles');
    my $log_dir         = catdir($tmp_dir, 'log', 'cache');
    my $anova_cache     = catdir($tmp_dir, 'anova', 'cache');
    my $anova_temp      = catdir($tmp_dir, 'anova', 'tempfiles');
    my $corre_cache     = catdir($tmp_dir, 'correlation', 'cache');
    my $corre_temp      = catdir($tmp_dir, 'correlation', 'tempfiles');
    my $h2_cache        = catdir($tmp_dir, 'heritability', 'cache');
    my $h2_temp         = catdir($tmp_dir, 'heritability', 'tempfiles');
    my $qc_cache        = catdir($tmp_dir, 'qualityControl', 'cache');
    my $qc_temp         = catdir($tmp_dir, 'qualityControl', 'tempfiles');
    my $pca_cache       = catdir($tmp_dir, 'pca', 'cache');
    my $pca_temp        = catdir($tmp_dir, 'pca', 'tempfiles');
    my $cluster_cache   = catdir($tmp_dir, 'cluster', 'cache');
    my $cluster_temp    = catdir($tmp_dir, 'cluster', 'tempfiles');
    my $sel_index_cache = catdir($tmp_dir, 'selectionIndex', 'cache');
    my $sel_index_temp  = catdir($tmp_dir, 'selectionIndex', 'tempfiles');
    my $kinship_cache   = catdir($tmp_dir, 'kinship', 'cache');
    my $kinship_temp    = catdir($tmp_dir, 'kinship', 'tempfiles');

    mkpath (
	[
	 $solgs_dir, $solgs_cache, $solgs_tempfiles, $solgs_lists,  $solgs_datasets,
	 $pca_cache, $pca_temp, $histogram_cache, $histogram_temp, $log_dir, $corre_cache, $corre_temp,
	 $h2_temp, $h2_cache,  $qc_cache, $qc_temp, $anova_temp,$anova_cache, $solqtl_cache, $solqtl_tempfiles,
	 $cluster_cache, $cluster_temp, $sel_index_cache,  $sel_index_temp, $kinship_cache, $kinship_temp
	],
	0, 0755
	);

    $c->stash(solgs_dir                 => $solgs_dir,
              solgs_cache_dir           => $solgs_cache,
              solgs_tempfiles_dir       => $solgs_tempfiles,
              solgs_lists_dir           => $solgs_lists,
	      solgs_datasets_dir        => $solgs_datasets,
	      pca_cache_dir             => $pca_cache,
	      pca_temp_dir              => $pca_temp,
	      cluster_cache_dir         => $cluster_cache,
	      cluster_temp_dir          => $cluster_temp,
              correlation_cache_dir     => $corre_cache,
	      correlation_temp_dir      => $corre_temp,
	      heritability_cache_dir    => $h2_cache,
	      heritability_temp_dir     => $h2_temp,
	      qualityControl_cache_dir    => $qc_cache,
	      qualityControl_temp_dir     => $qc_temp,
	      histogram_cache_dir       => $histogram_cache,
	      histogram_temp_dir        => $histogram_temp,
	      analysis_log_dir          => $log_dir,
              anova_cache_dir           => $anova_cache,
	      anova_temp_dir            => $anova_temp,
	      solqtl_cache_dir          => $solqtl_cache,
              solqtl_tempfiles_dir      => $solqtl_tempfiles,
	      cache_dir                 => $solgs_cache,
	      selection_index_cache_dir => $sel_index_cache,
	      selection_index_temp_dir  => $sel_index_temp,
	      kinship_cache_dir         => $kinship_cache,
	      kinship_temp_dir          => $kinship_temp
        );

}


###
1;#
##

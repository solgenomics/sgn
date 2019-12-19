package SGN::Controller::solGS::Dataset;

use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use JSON;
use POSIX qw(strftime);

#BEGIN { extends 'Catalyst::Controller' }

BEGIN { extends 'Catalyst::Controller::REST' }



__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 
		   'text/html' => 'JSON' },
    );



sub get_dataset_trials :Path('/solgs/get/dataset/trials') Args(0) {
    my ($self, $c)  = @_;
    
    my $dataset_id = $c->req->param('dataset_id');
    
    croak "Dataset id missing." if !$dataset_id;
    
    $c->stash->{dataset_id} = $dataset_id;
    $self->get_dataset_trials_details($c);
    
    my $trials_ids = $c->stash->{trials_ids};
    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trials_names = $c->stash->{trials_names};
    
    $c->stash->{rest}{'trials_ids'} = $trials_ids;
    $c->stash->{rest}{'combo_pops_id'} = $combo_pops_id;
    $c->stash->{rest}{'trials_names'} = $trials_names;
       
}


sub check_predicted_dataset_selection :Path('/solgs/check/predicted/dataset/selection') Args(0) {
    my ($self, $c) = @_;
    
    my $args = $c->req->param('arguments');

    my $json = JSON->new();
    $args = $json->decode($args);
    
    my $training_pop_id  = $args->{training_pop_id};
    my $selection_pop_id = $args->{selection_pop_id};
    $c->stash->{training_traits_ids} = $args->{training_traits_ids};
    
    $c->controller("solGS::solGS")->download_prediction_urls($c, $training_pop_id, $selection_pop_id);
   
    my $ret->{output} = $c->stash->{download_prediction};

    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_dataset_trials_ids {
    my ($self, $c) = @_;
    my $dataset_id = $c->stash->{dataset_id};
  
    my $model = $self->get_model();
    my $data = $model->get_dataset_data($dataset_id);
    my $trials_ids = $data->{categories}->{trials};
    $c->stash->{dataset_trials_ids} = $trials_ids;
    $c->stash->{trials_ids} = $trials_ids;

}


sub get_dataset_trials_details {
    my ($self, $c) = @_;
    
    $self->get_dataset_trials_ids($c);
    $c->controller('solGS::combinedTrials')->process_trials_list_details($c);

}


sub get_dataset_genotypes_genotype_data {
    my ($self, $c) = @_;
     
    $self->get_dataset_genotypes_list($c);
    $c->controller('solGS::List')->genotypes_list_genotype_file($c);
    
}


sub get_dataset_genotypes_list {
    my ($self, $c) = @_;

    my $dataset_id = $c->stash->{dataset_id};

    my $model = $self->get_model();    
    my $genotypes_ids = $model->get_genotypes_from_dataset($dataset_id);
    my $genotypes  = $c->controller('solGS::List')->transform_uniqueids_genotypes($c, $genotypes_ids);
    
    $c->stash->{genotypes_list} = $genotypes;
    $c->stash->{genotypes_ids}  = $genotypes_ids;
    
}

sub submit_dataset_training_data_query {
    my ($self, $c) = @_;
    
    my $dataset_id = $c->stash->{dataset_id};
   
    my $model = $self->get_model();
    my $data = $model->get_dataset_data($dataset_id);
       
    my $query_jobs_file;

    if (@{$data->{categories}->{plots}})	
    {
	###### write dataset training data query job function instead...
	$c->stash->{plots_names} = $data->{categories}->{plots};
	$self->get_dataset_genotypes_list($c);
   
	$c->controller('solGS::List')->get_list_training_data_query_jobs_file($c);
	$query_jobs_file = $c->stash->{list_training_data_query_jobs_file};
    }
    elsif (@{$data->{categories}->{trials}})	
    {	
	my $trials = $data->{categories}->{trials};
	$c->controller('solGS::solGS')->get_training_pop_data_query_job_args_file($c, $trials);
	$query_jobs_file  = $c->stash->{training_pop_data_query_job_args_file};
    }
    
    $c->stash->{dependent_jobs} = $query_jobs_file;
    $c->controller('solGS::solGS')->run_async($c);
}



sub get_dataset_phenotype_data {
    my ($self, $c) = @_;
    
    my $dataset_id = $c->stash->{dataset_id};

    #$self->get_dataset_plots_list($c);

    my $model = $self->get_model();
    my $data = $model->get_dataset_data($dataset_id);

    if ($data->{categories}->{plots}->[0])	
    {
	$c->stash->{plots_names} = $data->{categories}->{plots};
	
	$c->controller('solGS::List')->plots_list_phenotype_file($c);
	$c->stash->{phenotype_file} = $c->stash->{plots_list_phenotype_file};	
    } 
    elsif ($data->{categories}->{trials}->[0])
    {
	my $trials = $data->{categories}->{trials};
	$c->stash->{pops_ids_list} = $data->{categories}->{trials};
	$c->controller('solGS::List')->get_trials_list_pheno_data($c);	
    }    
}


sub create_dataset_pheno_data_query_jobs {
    my ($self, $c) = @_;
    
    my $dataset_id = $c->stash->{dataset_id};

    my $model = $self->get_model();
    my $data = $model->get_dataset_data($dataset_id);

    if ($data->{categories}->{plots}->[0])	
    {
	$c->stash->{plots_names} = $data->{categories}->{plots};
	my $plots = $data->{categories}->{plots};

	$c->controller('solGS::List')->plots_list_phenotype_query_job($c);
	$c->stash->{dataset_pheno_data_query_jobs} = $c->stash->{plots_list_phenotype_query_job};
    } 
    elsif ($data->{categories}->{trials}->[0])
    {
	my $trials_ids = $data->{categories}->{trials};
	
	$c->controller('solGS::combinedTrials')->multi_pops_pheno_files($c, $trials_ids);
	$c->stash->{phenotype_files_list} = $c->stash->{multi_pops_pheno_files};
	
	$c->controller('solGS::solGS')->get_cluster_phenotype_query_job_args($c, $trials_ids);
	$c->stash->{dataset_pheno_data_query_jobs} = $c->stash->{cluster_phenotype_query_job_args};
    }    
}


sub create_dataset_geno_data_query_jobs {
    my ($self, $c) = @_;
    
    my $dataset_id = $c->stash->{dataset_id};

    my $model = $self->get_model();
    my $data = $model->get_dataset_data($dataset_id);

    if ($data->{categories}->{accessions}->[0])	
    {
	$self->get_dataset_genotypes_list($c);

	$c->controller('solGS::List')->genotypes_list_genotype_query_job($c);  
	$c->stash->{dataset_geno_data_query_jobs} = $c->stash->{genotypes_list_genotype_query_job};
    } 
    elsif ($data->{categories}->{trials}->[0])
    {
	my $trials_ids = $data->{categories}->{trials};
	$c->controller('solGS::combinedTrials')->multi_pops_geno_files($c, $trials_ids);
	$c->stash->{genotype_files_list} = $c->stash->{multi_pops_geno_files};
	$c->controller('solGS::solGS')->get_cluster_genotype_query_job_args($c, $trials_ids);
	$c->stash->{dataset_geno_data_query_jobs} = $c->stash->{cluster_genotype_query_job_args};
    }    
}


sub get_dataset_plots_list {
    my ($self, $c) = @_;

    my $dataset_id = $c->stash->{dataset_id};
 
    my $model = $self->get_model();   
    my $plots = $model->get_dataset_plots_list($dataset_id);

    $c->stash->{plots_names} = $plots;
    $c->controller('solGS::List')->get_plots_list_elements_ids($c);
    
}


sub get_model {
    my $self = shift;

    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")
					      });

    return $model;
}


sub dataset_population_summary {
    my ($self, $c) = @_;

    my $dataset_id = $c->stash->{dataset_id};
    my $file_id =  $self->dataset_file_id($c);	
    my $tmp_dir = $c->stash->{solgs_datasets_dir};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    
    my $meta= $c->model('solGS::solGS')->get_dataset_metadata($dataset_id);
    my $dataset_name = $meta->{name};
    my $owner_id = $meta->{owner_id};
    my $desc = $meta->{desc};
    $desc = 'NA' if $desc == 'undefined';
     
    my $person = CXGN::People::Person->new($c->dbc()->dbh(), $owner_id);
    my $owner = $person->get_first_name() . ' ' . $person->get_last_name();

    my $user_role;
    my $user_id;
 
    if ($c->user)
    {
	$user_role = $c->user->get_object->get_user_type();
	$user_id = $c->user->get_object->get_sp_person_id();
    }
    
    if (($user_role =~ /submitter|user/  &&  $user_id != $owner_id) || !$c->user)
    {
	my $page = "/" . $c->req->path;
	$c->res->redirect("/solgs/login/message?page=$page");
	$c->detach;
    }
    else
    {
        my $protocol_url = $c->controller('solGS::solGS')->create_protocol_url($c, $protocol_id);

	$c->stash(project_id          => $file_id,
		  project_name        => $dataset_name,
		  selection_pop_name  => $dataset_name,
		  project_desc        => $desc,
		  owner               => $owner,
		  protocol            => $protocol_url,
	    );  
    }
    
}


sub create_dataset_population_metadata {
    my ($self, $c) = @_;

    my $dataset_id = $c->stash->{dataset_id};
    
    my $meta= $c->model('solGS::solGS')->get_dataset_metadata($dataset_id);
    my $dataset_name = $meta->{name};
    
    my $metadata = 'key' . "\t" . 'value';
    $metadata .= "\n" . 'user_id' . "\t" . $c->user->id;
    $metadata .= "\n" . 'dataset_name' . "\t" . $dataset_name;
    $metadata .= "\n" . 'description' . "\t" . 'Uploaded on: ' . strftime "%a %b %e %H:%M %Y", localtime;
    
    $c->stash->{dataset_metadata} = $metadata;
  
}


sub create_dataset_population_metadata_file {
    my ($self, $c) = @_;

    my $file_id = $self->dataset_file_id($c);
    
    my $tmp_dir = $c->stash->{solgs_datasets_dir};
    
    $c->controller('solGS::Files')->population_metadata_file($c,  $tmp_dir, $file_id,);   
    my $file = $c->stash->{population_metadata_file};
   
    $self->create_dataset_population_metadata($c);
    my $metadata = $c->stash->{dataset_metadata};
    
    write_file($file, $metadata);
 
    $c->stash->{dataset_metadata_file} = $file; 
  
}



sub create_dataset_pop_data_files {
    my ($self, $c) = @_;

    my $file_id = $self->dataset_file_id($c);
    #my $dataset_id = $c->stash->{dataset_id}
    $c->controller('solGS::Files')->phenotype_file_name($c, $file_id);
    my $pheno_file = $c->stash->{phenotype_file_name};

    $c->controller('solGS::Files')->genotype_file_name($c, $file_id);
    my $geno_file = $c->stash->{genotype_file_name};
    
    my $files = { pheno_file => $pheno_file, geno_file => $geno_file};
    
    return $files;

}


sub dataset_plots_list_phenotype_file {
    my ($self, $c) = @_;

    my $dataset_id  = $c->stash->{dataset_id};
    my $plots_ids = $c->model('solGS::solGS')->get_dataset_plots_list($dataset_id);        
    my $file_id = $self->dataset_file_id($c);
    
    $c->stash->{pop_id} = $file_id;
    $c->controller('solGS::Files')->traits_list_file($c);    
    my $traits_file =  $c->stash->{traits_list_file};
  
    my $data_dir = $c->stash->{solgs_datasets_dir};

    $c->controller('solGS::Files')->phenotype_file_name($c, $file_id);
    my $pheno_file = $c->stash->{phenotype_file_name};
    #$c->stash->{dataset_plots_list_phenotype_file} = $pheno_file;

    $c->controller('solGS::Files')->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};
    
    my $args = {
	'dataset_id'     => $dataset_id,
	'plots_ids'      => $plots_ids,
	'traits_file'    => $traits_file,
	#'data_dir'       => $data_dir,
	'phenotype_file' => $pheno_file,
	'metadata_file'  => $metadata_file,
	'r_temp_file'    => 'dataset-phenotype-data-query',
	'population_type' => 'plots_list'
    };
    
    $c->controller('solGS::List')->submit_list_phenotype_data_query($c, $args);
    $c->stash->{phenotype_file} = $c->stash->{dataset_plots_list_phenotype_file};

}


sub dataset_file_id {
    my ($self, $c) = @_;

    my $dataset_id = $c->stash->{dataset_id};
    if ( $dataset_id =~ /dataset/) {
	return $dataset_id;
    }  else {
	return 'dataset_' . $dataset_id;
    }	  
    
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####

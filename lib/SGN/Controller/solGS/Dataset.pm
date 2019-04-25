package SGN::Controller::solGS::Dataset;

use Moose;
use namespace::autoclean;

#use File::Basename;
#use File::Spec::Functions qw / catfile catdir/;
#use File::Path qw / mkpath  /;
#use File::Temp qw / tempfile tempdir /;

#use JSON;

#use CXGN::List;

use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
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
    my $trials_ids = $c->stash->{dataset_trials_ids};
    my $combo_pops_id = $c->stash->{dataset_combo_trials_id};

    print STDERR "\n dataset id: $dataset_id - trials ids: @$trials_ids - combo pops ids: $combo_pops_id\n";
    if ($trials_ids) 
    {	
	$c->stash->{rest}{'trials_ids'} = $trials_ids;
	$c->stash->{rest}{'combo_pops_id'} = $combo_pops_id;
    }
       
}


sub get_dataset_trials_details {
    my ($self, $c) = @_;
    my $dataset_id = $c->stash->{dataset_id};
  
    my $model = $self->get_model();
    my $data = $model->get_dataset_data($dataset_id);
    my $trials_ids = $data->{categories}->{trials};
    $c->stash->{dataset_trials_ids} = $trials_ids;

    if (scalar(@$trials_ids) > 1)
    {
	$c->stash->{pops_ids_list} = $trials_ids;
	#$self->create_combined_pops_id($c);

	$c->controller('solGS::List')->process_trials_list_details($c);
	$c->stash->{dataset_combo_trials_id} = $c->stash->{combo_pops_id};
    }
   
       
}


sub get_dataset_genotypes_genotype_data {
    my ($self, $c) = @_;
    
    my $dataset_id = $c->stash->{dataset_id};

    
    $self->get_dataset_genotypes_list($c);
    $c->controller('solGS::List')->genotypes_list_genotype_file($c, $dataset_id);
    
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


sub get_dataset_phenotype_data {
    my ($self, $c) = @_;
    
    my $dataset_id = $c->stash->{dataset_id};

    $self->get_dataset_plots_list($c);

    my $model = $self->get_model();

    my $data = $model->get_dataset_data($dataset_id);

    if (@{$data->{categories}->{plots}})	
    {
	$c->stash->{plots_names} = $data->{categories}->{plots};
	$c->controller('solGS::List')->plots_list_phenotype_file($c);
	$c->stash->{phenotype_file} = $c->stash->{plots_list_phenotype_file};	
    } 
    elsif (@{$data->{categories}->{trials}})
    {
	$c->stash->{pops_ids_list} = $data->{categories}->{trials};
	$c->controller('solGS::List')->get_trials_list_pheno_data($c);	
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
    my ($self, $c, $dataset_id) = @_;

    $dataset_id = $c->stash->{dataset_id} if !$dataset_id;

    $dataset_id =  'dataset_' . $dataset_id  if $dataset_id !~ /dataset_/;
    
    my $tmp_dir = $c->stash->{solgs_datasets_dir};
   
    if (!$c->user)
    {
	my $page = "/" . $c->req->path;
	$c->res->redirect("/solgs/login/message?page=$page");
	$c->detach;
    }
    else
    {
	my $user_name = $c->user->id;  
        my $protocol  = $c->controller('solGS::solGS')->create_protocol_url($c);

	if ($dataset_id) 
	{
	    $c->controller('solGS::Files')->population_metadata_file($c, $dataset_id, $tmp_dir);   
	    my $metadata_file = $c->stash->{population_metadata_file};
       
	    my @metadata = read_file($metadata_file);
       
	    my ($key, $dataset_name, $desc);
     
	    ($desc)        = grep {/description/} @metadata;       
	    ($key, $desc)  = split(/\t/, $desc);
      
	    ($dataset_name)       = grep {/dataset_name/} @metadata;      
	    ($key, $dataset_name) = split(/\t/, $dataset_name); 
	   
	    $c->stash(project_id          => $dataset_id,
		      project_name        => $dataset_name,
		      prediction_pop_name => $dataset_name,
		      project_desc        => $desc,
		      owner               => $user_name,
		      protocol            => $protocol,
		);  
	}
    }
}


sub create_dataset_population_metadata {
    my ($self, $c) = @_;
    
    my $metadata = 'key' . "\t" . 'value';
    $metadata .= "\n" . 'user_id' . "\t" . $c->user->id;
    $metadata .= "\n" . 'dataset_name' . "\t" . $c->{stash}->{dataset_name};
    $metadata .= "\n" . 'description' . "\t" . 'Uploaded on: ' . strftime "%a %b %e %H:%M %Y", localtime;
    
    $c->stash->{dataset_metadata} = $metadata;
  
}


sub create_dataset_population_metadata_file {
    my ($self, $c, $dataset_id) = @_;

    $dataset_id =  'dataset_' . $dataset_id  if $dataset_id !~ /dataset_/;
    
    my $user_id = $c->user->id;
    my $tmp_dir = $c->stash->{solgs_datasets_dir};
    
    $c->controller('solGS::Files')->population_metadata_file($c, $dataset_id, $tmp_dir);   
    my $file = $c->stash->{population_metadata_file};
   
    $self->create_dataset_population_metadata($c);
    my $metadata = $c->stash->{dataset_metadata};
    
    write_file($file, $metadata);
 
    $c->stash->{dataset_metadata_file} = $file;
 
  
}

sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####

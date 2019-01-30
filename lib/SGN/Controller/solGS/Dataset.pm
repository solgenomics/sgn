package SGN::Controller::solGS::Dataset;

use Moose;
use namespace::autoclean;

#use File::Basename;
#use File::Spec::Functions qw / catfile catdir/;
#use File::Path qw / mkpath  /;
#use File::Temp qw / tempfile tempdir /;
#use File::Slurp qw /write_file read_file :edit prepend_file/;
#use JSON;

#use CXGN::List;


BEGIN { extends 'Catalyst::Controller' }


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


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####

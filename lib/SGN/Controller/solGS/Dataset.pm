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

    
    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")
					      });
    
    my $genotypes_ids = $model->get_genotypes_from_dataset($dataset_id);


    my $genotypes  = $c->controller('solGS::List')->transform_uniqueids_genotypes($c, $genotypes_ids);
    
    $c->stash->{genotypes_list} = $genotypes;
    $c->stash->{genotypes_ids}  = $genotypes_ids;
    
}



sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



__PACKAGE__->meta->make_immutable;

####
1;
####

package solGS::Cluster;


use Moose;
use namespace::autoclean;

use CXGN::Tools::Run;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file/;
use Try::Tiny;
use Storable qw/ nstore retrieve /;
use solGS::AnalysisReport;
use Carp qw/ carp confess croak /;

use SGN::Model::solGS::solGS;
use SGN::Controller::solGS::solGS;
use SGN::Controller::solGS::List;

with 'MooseX::Getopt';
with 'MooseX::Runnable';


has "data_type" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );


has "population_type" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "args_file" => (
     is       => 'ro',
     isa      => 'Str',
     required => 1, 
 );




sub run {
    my $self = shift;
    
    my $args_file  = $self->args_file;
    my $data_type  = $self->data_type;
    my $pop_type   = $self->population_type;
  
    print STDERR "\nrun data type: $data_type\n";
    print STDERR "\nrun pop type: $pop_type\n";
    print STDERR "\nrun report file: $args_file\n";
   
    if  ($self->population_type =~ /trial/) {
	if ($self->data_type =~ /phenotype/) {
	    $self->trial_phenotype_data();
	} elsif ($self->data_type =~ /genotype/) {
	    $self->trial_genotype_data();	
	}
    } elsif ($self->population_type =~ /list/) {
	
	if ($self->data_type =~ /phenotype/) {
	    $self->plots_list_phenotype_data();
	} elsif ($self->data_type =~ /genotype/) {
	    $self->genotypes_list_genotype_data();	
	}   
    }
   
}


sub trial_genotype_data {
    my $self = shift;

    my $args       = retrieve($self->args_file);

    my $geno_file  = $args->{genotype_file}; 
    my $pop_id     = ($args->{prediction_id} ? $args->{prediction_id} : $args->{population_id});

    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});
					      
    my $geno_data = $model->genotype_data($args);
   
    if ($geno_data)
    {
	write_file($geno_file, $geno_data);
    }
    
}


sub trial_phenotype_data {
    my $self = shift;
    
    my $args       = retrieve($self->args_file);
    
    my $pheno_file  = $args->{phenotype_file};
    my $pop_id      = $args->{population_id};
    my $traits_file = $args->{traits_list_file};

    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});
   
    my $pheno_data = $model->phenotype_data($pop_id);

    if ($pheno_data)
    {
	my $pheno_data = SGN::Controller::solGS::solGS->format_phenotype_dataset($pheno_data, $traits_file);
	write_file($pheno_file, $pheno_data);
    }
    
}


sub genotypes_list_genotype_data {
    my $self = shift;
    
    my $args = retrieve($self->args_file);
    
    my $list_pop_id   = $args->{model_id} || $args->{list_pop_id} || $args->{selection_pop_id};
    my $genotypes     = $args->{genotypes_list};
    my $genotypes_ids = $args->{genotypes_ids};
    my $data_dir      = $args->{list_data_dir};
    my $geno_file     = $args->{genotype_file};
   
    my $model = SGN::Model::solGS::solGS->new({context => 'SGN::Context', 
					       schema => SGN::Context->dbic_schema("Bio::Chado::Schema")
					      });

    my $geno_data = $model->genotypes_list_genotype_data($genotypes_ids);
   
    write_file($geno_file, $geno_data);

}


sub plots_list_phenotype_data {
    my $self= shift;

    my $args = retrieve($self->args_file);
    
    my $model_id    = $args->{model_id};
    my $plots_names = $args->{plots_names};
    my $plots_ids   = $args->{plots_ids};
    my $traits_file = $args->{traits_file};
    my $data_dir    = $args->{list_data_dir};
   
    my $model = SGN::Model::solGS::solGS->new({schema => SGN::Context->dbic_schema("Bio::Chado::Schema")});
    my $pheno_data = $model->plots_list_phenotype_data($plots_names);
  
    $pheno_data = SGN::Controller::solGS::solGS->format_phenotype_dataset($pheno_data, $traits_file);
    
    my $files = SGN::Controller::solGS::List->create_list_pop_tempfiles($data_dir, $model_id);
    my $pheno_file = $files->{pheno_file};
    
    write_file($pheno_file, $pheno_data);
      
}






__PACKAGE__->meta->make_immutable;




####
1; #
####

package solGS::queryJobs;


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
use Data::Dumper;
use Bio::Chado::Schema;
use CXGN::People::Schema;

with 'MooseX::Getopt';
with 'MooseX::Runnable';


has 'data_type' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    );

has 'dbname' => (isa => 'Str',
is=>'rw',
required=> 1

);

has 'dbhost' => (isa => 'Str',
is=>'rw',
required=> 1

);

has 'dbport' => (isa => 'Int',
is=>'rw',
default => 5432

);

has 'dbpass' => (isa => 'Str',
is=>'rw',
required=> 1

);

has 'dbuser' => (isa => 'Str',
is=>'rw',
required=> 1

);

has 'population_type' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    );

has 'args_file' => (
     is       => 'ro',
     isa      => 'Str',
     required => 1,

    );

has 'check_data_exists' => (
    is => 'ro',
    isa => 'Num',
    required => 0,
    );


sub run {
    my $self = shift;

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
    } elsif ($self->population_type =~ /dataset/) {

	if ($self->data_type =~ /phenotype/) {
	    $self->plots_list_phenotype_data();
	} elsif ($self->data_type =~ /genotype/) {
	    $self->dataset_genotype_data();
	}
    }

}

sub get_args {
	my $self = shift;
	return retrieve($self->args_file);
}


sub trial_genotype_data {
    my $self = shift;

    my $args  = $self->get_args();
    my $geno_file  = $args->{genotype_file};

    my $model = $self->get_model();

    my $search_obj = $model->genotype_data($args);
    $self->write_geno_data($search_obj, $geno_file);

}


sub write_geno_data {
    my ($self, $search_obj, $file) = @_;

    my $exists = $self->check_data_exists;
    my $count = 1;
    my $marker_headers;

    my $model = $self->get_model();
    my $add_headers = 1;
    while (my $geno = $search_obj->get_next_genotype_info())
    {
        my $geno_data;
       
        if ($count == 1)
        {
            my $geno_hash = $geno->{selected_genotype_hash};
            $marker_headers = $model->get_dataset_markers($geno_hash);
        }  else {
            $add_headers = 0;
        }
    
        $geno_data  = $model->structure_genotype_data($geno, $marker_headers, $add_headers);
        write_file($file, {append => 1, binmode => ':utf8'}, $$geno_data);
          
        $count++;
        if ($self->check_data_exists)
        {
            last if $$geno_data;
        }
    }

}


sub trial_phenotype_data {
    my $self = shift;

    my $args  =  $self->get_args();

    my $pheno_file  = $args->{phenotype_file};
    my $pop_id      = $args->{population_id};
    my $traits_file = $args->{traits_list_file};
    my $metadata_file = $args->{metadata_file};

    my $model = $self->get_model();
    my $pheno_data = $model->phenotype_data($pop_id);
    my $metadata   = $model->trial_metadata();

    if ($pheno_data)
    {
	my $pheno_data = SGN::Controller::solGS::solGS->format_phenotype_dataset($pheno_data, $metadata, $traits_file);
	write_file($pheno_file, {binmode => ':utf8'}, $pheno_data);
    }

    write_file($metadata_file, {binmode => ':utf8'}, join("\t", @$metadata));
}


sub genotypes_list_genotype_data {
    my $self = shift;
	my $genotypes_ids = shift;

    my $args =  $self->get_args();
    $genotypes_ids  = $args->{genotypes_ids} if !$genotypes_ids->[0];

    my $data_dir      = $args->{data_dir};
    my $geno_file    = $args->{genotype_file};
    my $protocol_id = $args->{genotyping_protocol_id};

    my $model = $self->get_model();
    my $search_obj = $model->genotypes_list_genotype_data($genotypes_ids, $protocol_id);

    ###empty cached geno file first
    write_file($geno_file);
    $self->write_geno_data($search_obj, $geno_file);

}


sub plots_list_phenotype_data {
    my $self= shift;

    my $args =  $self->get_args();

    my $list_id = $args->{list_id};
    my $plots_ids   = $args->{plots_ids};
    my $traits_file = $args->{traits_file};
    #my $data_dir    = $args->{data_dir};
    my $pheno_file  = $args->{phenotype_file};
    my $metadata_file = $args->{metadata_file};

    my $model = $self->get_model();
    my $pheno_data = $model->plots_list_phenotype_data($plots_ids);
    my $metadata = $model->trial_metadata();

    $pheno_data = SGN::Controller::solGS::solGS->format_phenotype_dataset($pheno_data, $metadata, $traits_file);

    write_file($pheno_file, {binmode => ':utf8'}, $pheno_data);
    write_file($metadata_file, {binmode => ':utf8'}, join("\t", @$metadata));

}


sub dataset_genotype_data {
    my $self = shift;

    my $args =  $self->get_args();
    my $dataset_id = $args->{dataset_id};
	my $model = $self->get_model();

	my $genotypes_ids = $model->get_genotypes_from_dataset ($dataset_id);
    # my $cnt = @$genotypes_ids;
	if (@{$genotypes_ids})
	{
		$self->genotypes_list_genotype_data($genotypes_ids);
	}
	else
	{
		my $model = $self->get_model();
		my $protocol_id = $args->{genotyping_protocol_id};
      	my $search_obj = $model->get_dataset_genotype_data($dataset_id);
		my $geno_file = $args->{genotype_file};
        ###empty cached dataset geno file first
        write_file($geno_file);
   		$self->write_geno_data($model, $search_obj, $geno_file);
	}

}


sub get_model {
    my $self = shift;

    my $dbname = $self->dbname;
    my $dbhost = $self->dbhost;

    my $dbuser = $self->dbuser;
    my $dbpass = $self->dbpass;

    my $dsn = "dbi:Pg:database=$dbname;host=$dbhost";

    my $bcs_schema = Bio::Chado::Schema->connect($dsn, $dbuser, $dbpass);
    my $people_schema = CXGN::People::Schema->connect($dsn,  $dbuser, $dbpass, { on_connect_do => [ 'SET search_path TO sgn_people, public, sgn' ]});


    my $model = SGN::Model::solGS::solGS->new({
					       schema => $bcs_schema,
                       people_schema =>$people_schema });


    return $model;

}



__PACKAGE__->meta->make_immutable;




####
1; #
####

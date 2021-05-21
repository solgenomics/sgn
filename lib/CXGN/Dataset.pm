
=head1 NAME

CXGN::Dataset - a class to easily query the database for breeding data

=head1 DESCRIPTION

CXGN::Dataset can be used to flexibly define datasets for breeding applications. For example, a dataset can be defined using a list of germplasm, a list of trials, a list of years, etc, or a combination of the above. Once defined, it allows to easily obtain related phenotypes and genotypes and other data.

Datasets can be stored in the database and retrieved for later use.

Currently, there are three incarnations of CXGN::Dataset:

=over 5

=item CXGN::Dataset

Unbuffered output of the queries

=item CXGN::Dataset::File

Writes results to files

=item CXGN::Dataset::Cache

Returns output like CXGN::Dataset, but uses a disk-cache for the response data

=back

=head1 SYNOPSYS

 my $ds = CXGN::Dataset->new( { people_schema => $p, schema => $s } );
 $ds->accessions([ 'a', 'b', 'c' ]);
 my $trials = $ds->retrieve_trials();
 my $sp_dataset_id = $ds->store();
 #...
 my $restored_ds = CXGN::Dataset( {  people_schema => $p, schema => $s, sp_dataset_id => $sp_dataset_id } );
 my $years = $restored_ds->retrieve_years();
 #...

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>


=head1 ACCESSORS

=cut


package CXGN::Dataset;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use JSON::Any;
use CXGN::BreederSearch;
use CXGN::People::Schema;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Genotype::Search;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;

=head2 people_schema()

accessor for CXGN::People::Schema database object

=cut

has 'people_schema' => (isa => 'CXGN::People::Schema',  is => 'rw', required => 1 );

=head2 schema()

accessor for Bio::Chado::Schema database object

=cut

has 'schema' =>       ( isa => "Bio::Chado::Schema", is => 'rw', required => 1 );

=head2 sp_dataset_id()

accessor for sp_dataset primary key

=cut


has 'sp_dataset_id' => ( isa => 'Int',
			 is => 'rw',
			 predicate => 'has_sp_dataset_id',
    );

=head2 data()

accessor for the json-formatted data structure (as used for the backend storage)

=cut

has 'data' =>        ( isa => 'HashRef',
		       is => 'rw'
    );

=head2 name()

accessor for the name of this dataset

=cut

has 'name' =>        ( isa => 'Maybe[Str]',
		       is => 'rw',
    );

=head2 description()

accessor for the descrition of this dataset

=cut

has 'description' => ( isa => 'Maybe[Str]',
		       is => 'rw'
    );

=head2 sp_person_id()

accessor for sp_person_id (owner of the dataset)

=cut

has 'sp_person_id' => ( isa => 'Maybe[Int]',
			is => 'rw',
    );


=head2 accessions()

accessor for defining the accessions that are part of this dataset (ArrayRef).

=cut

has 'accessions' =>  ( isa => 'Maybe[ArrayRef]',
		       is => 'rw',
		       predicate => 'has_accessions',
    );

=head2 plots()

accessor for defining the plots that are part of this dataset (ArrayRef).

=cut

has 'plots' =>       ( isa => 'Maybe[ArrayRef]',
		       is => 'rw',
		       predicate => 'has_plots',
    );

=head2 plants()

accessor for defining the plants that are part of this dataset (ArrayRef).

=cut

has 'plants' =>       ( isa => 'Maybe[ArrayRef]',
		       is => 'rw',
		       predicate => 'has_plants',
    );



=head2 trials()

accessor for defining the trials that are part of this dataset (ArrayRef).

=cut


has 'trials' =>      ( isa => 'Maybe[ArrayRef]',
		       is => 'rw',
		       predicate => 'has_trials',
    );


=head2 traits()

=cut

has 'traits' =>      ( isa => 'Maybe[ArrayRef]',
		       is => 'rw',
		       predicate => 'has_traits',
    );

=head2 years()

=cut


has 'years' =>       ( isa => 'Maybe[ArrayRef]',
		       is => 'rw',
		       predicate => 'has_years',
    );

=head2 breeding_programs()

=cut

has 'breeding_programs' => ( isa => 'Maybe[ArrayRef]',
			     is => 'rw',
			     predicate => 'has_breeding_programs',
			     default => sub { [] },
    );

=head2 genotyping_protocols()

=cut

has 'genotyping_protocols' =>      ( isa => 'Maybe[ArrayRef]',
		       is => 'rw',
		       predicate => 'has_genotyping_protocols',
    );

=head2 trial_types()

=cut

has 'trial_types' => ( isa => 'Maybe[ArrayRef]',
		     is => 'rw',
		     predicate => 'has_trial_types',
    );

=head2 trial_designs()

=cut

has 'trial_designs' => ( isa => 'Maybe[ArrayRef]',
		     is => 'rw',
		     predicate => 'has_trial_designs',
    );

=head2 locations()

=cut

has 'locations' => ( isa => 'Maybe[ArrayRef]',
		     is => 'rw',
		     predicate => 'has_locations',
    );


has 'category_order' => ( isa => 'Maybe[ArrayRef]',
			  is => 'rw',
			  predicate => 'has_category_order',
    );

has 'is_live' =>     ( isa => 'Bool',
		       is => 'rw',
		       default => 0,
    );

has 'is_public' => ( isa => 'Bool',
			is => 'rw',
			default => 0,
    );


=head2 data_level()

=cut

has 'data_level' =>  ( isa => 'String',
		       is => 'rw',
		       isa => enum([qw[ plot plant subplot ]]),
		       default => 'plot',
    );

=head2 exclude_phenotype_outlier()

=cut

has 'exclude_phenotype_outlier' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

has 'breeder_search' => (isa => 'CXGN::BreederSearch', is => 'rw');

=head2 autopopulate_accessions_from_trials()

=cut

has 'autopopulate_accessions_from_trials' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

sub BUILD {
    my $self = shift;

    my $bs = CXGN::BreederSearch->new(dbh => $self->schema->storage->dbh());
    $self->breeder_search($bs);

    if ($self->has_sp_dataset_id()) {
        print STDERR "Processing dataset_id ".$self->sp_dataset_id()."\n";
        my $row = $self->people_schema()->resultset("SpDataset")->find({ sp_dataset_id => $self->sp_dataset_id() });
        if (!$row) { die "The dataset with id ".$self->sp_dataset_id()." does not exist"; }
        my $dataset = JSON::Any->decode($row->dataset());
        $self->data($dataset);
        $self->name($row->name());
        $self->description($row->description());
        $self->sp_person_id($row->sp_person_id());
        $self->accessions($dataset->{categories}->{accessions});
        $self->plots($dataset->{categories}->{plots});
        $self->plants($dataset->{categories}->{plants});
        $self->trials($dataset->{categories}->{trials});
        $self->traits($dataset->{categories}->{traits});
        $self->years($dataset->{categories}->{years});
        $self->locations($dataset->{categories}->{locations});
        $self->breeding_programs($dataset->{categories}->{breeding_programs});
        $self->genotyping_protocols($dataset->{categories}->{genotyping_protocols});
        $self->trial_designs($dataset->{categories}->{trial_designs});
        $self->trial_types($dataset->{categories}->{trial_types});
        $self->category_order($dataset->{category_order});
        $self->is_live($dataset->{is_live});
        $self->is_public($dataset->{is_public});

        if ($self->autopopulate_accessions_from_trials) {
            if ( (!$self->accessions || scalar(@{$self->accessions}) == 0 ) && $self->trials && scalar(@{$self->trials}) > 0) {
                my @all_trial_accessions;
                foreach my $trial_id (@{$self->trials}) {
                    my $trial = CXGN::Trial->new( { bcs_schema => $self->schema, trial_id => $trial_id });
                    my $accessions = $trial->get_accessions();
                    foreach (@$accessions) {
                        push @all_trial_accessions, $_->{stock_id};
                    }
                }
                $self->accessions(\@all_trial_accessions);
            }
        }
    }
    else { print STDERR "Creating empty dataset object\n"; }

}


=head1 CLASS METHODS

=head2 datasets_by_user()


=cut

sub get_datasets_by_user {
    my $class = shift;
    my $people_schema = shift;
    my $sp_person_id = shift;
    my $found;

    my $rs = $people_schema->resultset("SpDataset")->search( { sp_person_id => $sp_person_id });

    my @datasets;
    my @datasets_id;
    while (my $row = $rs->next()) {
	push @datasets,  [ $row->sp_dataset_id(), $row->name(), $row->description() ];
	push @datasets_id, $row->sp_dataset_id();
    }

    $rs = $people_schema->resultset("SpDataset")->search( { is_public => 1 });

    while (my $row = $rs->next()) {
	$found = 0;
	for (@datasets_id) {
	    if ( $_ == $row->sp_dataset_id() ) {
	        $found = 1;
	    }
	}
        if (!$found) {
            push @datasets,  [ $row->sp_dataset_id(), 'public - ' . $row->name(), $row->description() ];
        }
    }
    return \@datasets;
}

=head2 datasets_public()

=cut

sub get_datasets_public {
    my $class = shift;
    my $people_schema = shift;

    my $rs = $people_schema->resultset("SpDataset")->search( { is_public => 1 });

    my @datasets;
    while (my $row = $rs->next()) {
        push @datasets,  [ $row->sp_dataset_id(), $row->name(), $row->description() ];
    }

    return \@datasets;
}

=head2 datasets_public()

=cut

sub set_dataset_public {
    my $self = shift;

    my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });

    if (! $row) {
        return "The specified dataset does not exist";
    } else {
        eval {
	   $row->is_public(1);
	   $row->sp_person_id($self->sp_person_id());
	   $row->sp_dataset_id($self->sp_dataset_id());
	   $row->update();
        };
        if ($@) {
            return "An error occurred, $@";
        } else {
            return undef;
        }
    }
}

=head2 datasets_public()

=cut

sub set_dataset_private {
    my $self = shift;

    my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });

    if (! $row) {
        return "The specified dataset does not exist";
    } else {
        eval {
           $row->is_public(0);
           $row->sp_person_id($self->sp_person_id());
           $row->sp_dataset_id($self->sp_dataset_id());
           $row->update();
        };
        if ($@) {
            return "An error occurred, $@";
        } else {
            return undef;
        }
    }
}

=head2 exists_dataset_name

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub exists_dataset_name {
    my $class = shift;
    my $people_schema = shift;
    my $name = shift;

    my $rs = $people_schema->resultset("SpDataset")->search( { name  =>  { -ilike => $name}});

    if ($rs->count() > 0) {
	return 1;
    }
    else {
	return 0;
    }
}


=head1 METHODS


=head2 to_hashref()


=cut

sub to_hashref {
    my $self = shift;

    my $dataref = $self->get_dataset_data();

    my $json = JSON::Any->encode($dataref);

    my $data = {
	name => $self->name(),
	description => $self->description(),
	sp_person_id => $self->sp_person_id(),
	dataset => $json,
    };

    return $data;


}

=head2 store()

=cut

sub store {
    my $self = shift;

    print STDERR "dataset_id = ".$self->sp_dataset_id()."\n";
    if (!$self->has_sp_dataset_id()) {
	print STDERR "Creating new dataset row... ".$self->sp_dataset_id()."\n";
	my $row = $self->people_schema()->resultset("SpDataset")->create($self->to_hashref());
	$self->sp_dataset_id($row->sp_dataset_id());
	return $row->sp_dataset_id();
    }
    else {
	print STDERR "Updating dataset row ".$self->sp_dataset_id()."\n";
	my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });
	if ($row) {
	    $row->name($self->name());
	    $row->description($self->description());
	    $row->dataset(JSON::Any->encode($self->to_hashref()));
	    $row->sp_person_id($self->sp_person_id());
	    $row->update();
	    return $row->sp_dataset_id();
	}
	else {
	    print STDERR "Weird... has ".$self->sp_dataset_id()." but no data in db\n";
	}
    }
}

sub get_dataset_data {
    my $self = shift;
    my $dataref;
    $dataref->{categories}->{accessions} = $self->accessions() if $self->has_accessions();
    $dataref->{categories}->{plots} = $self->plots() if $self->has_plots();
		$dataref->{categories}->{plants} = $self->plants() if $self->has_plants();
    $dataref->{categories}->{trials} = $self->trials() if $self->has_trials();
    $dataref->{categories}->{traits} = $self->traits() if $self->has_traits();
    $dataref->{categories}->{years} = $self->years() if $self->has_years();
    $dataref->{categories}->{breeding_programs} = $self->breeding_programs() if $self->has_breeding_programs();
		$dataref->{categories}->{genotyping_protocols} = $self->genotyping_protocols() if $self->has_genotyping_protocols();
		$dataref->{categories}->{trial_designs} = $self->trial_designs() if $self->has_trial_designs();
		$dataref->{categories}->{trial_types} = $self->trial_types() if $self->has_trial_types();
    $dataref->{categories}->{locations} = $self->locations() if $self->has_locations();
    $dataref->{category_order} = $self->category_order();
    return $dataref;
}

sub _get_dataref {
    my $self = shift;
    my $dataref;

    $dataref->{accessions} = join(",", @{$self->accessions()}) if $self->has_accessions();
    $dataref->{plots} = join(",", @{$self->plots()}) if $self->has_plots();
    $dataref->{plants} = join(",", @{$self->plants()}) if $self->has_plants();
    $dataref->{trials} = join(",", @{$self->trials()}) if $self->has_trials();
    $dataref->{traits} = join(",", @{$self->traits()}) if $self->has_traits();
    $dataref->{years} = join(",", @{$self->years()}) if $self->has_years();
    $dataref->{breeding_programs} = join(",", @{$self->breeding_programs()}) if $self->has_breeding_programs();
    $dataref->{genotyping_protocols} = join(",", @{$self->genotyping_protocols()}) if $self->has_genotyping_protocols();
    $dataref->{trial_designs} = join(",", @{$self->trial_designs()}) if $self->has_trial_designs();
    $dataref->{trial_types} = join(",", @{$self->trial_types()}) if $self->has_trial_types();
    $dataref->{locations} = join(",", @{$self->locations()}) if $self->has_locations();
    return $dataref;
}

sub _get_source_dataref {
    my $self = shift;
    my $source_type = shift;

    my $dataref;

    $dataref->{$source_type} = $self->_get_dataref();

    return $dataref;
}

=head2 retrieve_genotypes()

Retrieves genotypes as a listref of hashrefs.

=cut

sub retrieve_genotypes {
    my $self = shift;
    my $protocol_id = shift;
    my $genotypeprop_hash_select = shift || ['DS'];
    my $protocolprop_top_key_select = shift || [];
    my $protocolprop_marker_hash_select = shift || [];
    my $return_only_first_genotypeprop_for_stock = shift || 1;
    my $chromosome_list = shift || [];
    my $start_position = shift;
    my $end_position = shift;
    my $marker_name_list = shift || [];

    my $genotypes_search = CXGN::Genotype::Search->new(
        bcs_schema => $self->schema(),
        people_schema=>$self->people_schema,
        accession_list => $self->accessions(),
        trial_list => $self->trials(),
        protocol_id_list => [$protocol_id],
        chromosome_list => $chromosome_list,
        start_position => $start_position,
        end_position => $end_position,
        marker_name_list => $marker_name_list,
        genotypeprop_hash_select=>$genotypeprop_hash_select, #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
        protocolprop_top_key_select=>$protocolprop_top_key_select, #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
        protocolprop_marker_hash_select=>$protocolprop_marker_hash_select, #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
        return_only_first_genotypeprop_for_stock=>$return_only_first_genotypeprop_for_stock #FOR MEMORY REASONS TO LIMIT DATA
    );
    my ($total_count, $dataref) = $genotypes_search->get_genotype_info();
    return $dataref;
}

=head2 retrieve_phenotypes()

retrieves phenotypes as a listref of listrefs

=cut

sub retrieve_phenotypes {
    my $self = shift;
	my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
		search_type=>'MaterializedViewTable',
		bcs_schema=>$self->schema(),
		data_level=>$self->data_level(),
		trait_list=>$self->traits(),
		trial_list=>$self->trials(),
		accession_list=>$self->accessions(),
        exclude_phenotype_outlier=>$self->exclude_phenotype_outlier
	);
	my @data = $phenotypes_search->get_phenotype_matrix();
    return \@data;
}

=head2 retrieve_phenotypes_ref()

retrieves phenotypes as a hashref representation

=cut

sub retrieve_phenotypes_ref {
    my $self = shift;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->schema(),
            data_level=>$self->data_level(),
            trait_list=>$self->traits(),
            trial_list=>$self->trials(),
            accession_list=>$self->accessions(),
            exclude_phenotype_outlier=>$self->exclude_phenotype_outlier
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    return ($data, $unique_traits);
}

=head2 retrieve_high_dimensional_phenotypes()

retrieves high-dimensional phenotypes (NIRS, transcriptomics, and metabolomics) as a hashref representation. Will return both the data-matrix and the identifier metadata (transcripts and metabolites)

=cut

sub retrieve_high_dimensional_phenotypes {
    my $self = shift;
    my $nd_protocol_id = shift;
    my $high_dimensional_phenotype_type = shift; #NIRS, Transcriptomics, or Metabolomics
    my $query_associated_stocks = shift || 1;
    my $high_dimensional_phenotype_identifier_list = shift || [];

    if (!$nd_protocol_id) {
        die "Must provide the protocol id!\n";
    }
    if (!$high_dimensional_phenotype_type) {
        die "Must provide the high dimensional phenotype type!\n";
    }

    my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
        bcs_schema=>$self->schema(),
        nd_protocol_id=>$nd_protocol_id,
        high_dimensional_phenotype_type=>$high_dimensional_phenotype_type,
        query_associated_stocks=>$query_associated_stocks,
        high_dimensional_phenotype_identifier_list=>$high_dimensional_phenotype_identifier_list,
        accession_list=>$self->accessions(),
        plot_list=>$self->plots(),
        plant_list=>$self->plants(),
    });
    my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();

    return ($data_matrix, $identifier_metadata, $identifier_names);
}

=head2 retrieve_accessions()

retrieves accessions as a listref of listref [stock_id, uniquname]

=cut

sub retrieve_accessions {
    my $self = shift;
    my $accessions;
    if ($self->has_accessions()) {
	return $self->accessions();
    }
    else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "accessions";

	$accessions = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("accessions"));
    }
    return $accessions->{results};
}

=head2 retrieve_plots()

Retrieves plots as a listref of listrefs.

=cut

sub retrieve_plots {
    my $self = shift;
    my $plots;
    if ($self->has_plots()) {
	return $self->plots();
    }
    else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "plots";
	$plots = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("plots"));
    }
    return $plots->{results};
}

=head2 retrieve_plants()

Retrieves plants as a listref of listrefs.

=cut

sub retrieve_plants {
    my $self = shift;
    my $plants;
    if ($self->has_plants()) {
	return $self->plants();
    }
    else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "plants";
	$plants = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("plants"));
    }
    return $plants->{results};
}

=head2 retrieve_trials()

retrieves trials as a listref of listrefs.

=cut

sub retrieve_trials {
    my $self = shift;
    my $trials;
    if ($self->has_trials()) {
        return $self->trials();
    }
    else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "trials";
	$trials = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("trials"));
    }
    print STDERR "TRIALS: ".Dumper($trials);
    return $trials->{results};
}

=head2 retrieve_traits()

retrieves traits as a listref of listrefs.

=cut

sub retrieve_traits {
    my $self = shift;
    my $traits;
    if ($self->has_traits()) {
	return $self->traits();
    }
    else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "traits";
	$traits = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("traits"));
    }
    return $traits->{results};

}

=head2 retrieve_years()

retrieves years as a listref of listrefs

=cut

sub retrieve_years {
    my $self = shift;
    my @years;
    if ($self->has_years()) {
	return $self->years();
    }
    else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "years";
	my $year_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("years"));
	my $year_list = $year_data->{result};

	foreach my $y (@$year_list) {
	    push @years, $y->[0];
	}
    }
    return \@years;
}

=head2 retrieve_years()

retrieves years as a listref of listrefs

=cut

sub retrieve_locations {
    my $self = shift;
    my @locations;
    if ($self->has_locations()) {
	return $self->locations();
    }
    else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "locations";
	my $location_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("locations"));
	my $location_list = $location_data->{result};

	foreach my $y (@$location_list) {
	    push @locations, $y->[0];
	}
    }
    return \@locations;
}

=head2 retrieve_breeding_programs

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub retrieve_breeding_programs {
    my $self = shift;
		my @breeding_programs;
		if ($self->has_breeding_programs()) {
	return $self->breeding_programs();
		}
		else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "breeding_programs";
	my $breeding_program_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("breeding_programs"));
	my $breeding_program_list = $breeding_program_data->{result};

	foreach my $y (@$breeding_program_list) {
			push @breeding_programs, $y->[0];
	}
		}
		return \@breeding_programs;
}

=head2 retrieve_genotyping_protocols

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub retrieve_genotyping_protocols {
    my $self = shift;
		my @genotyping_protocols;
		if ($self->has_genotyping_protocols()) {
	return $self->genotyping_protocols();
		}
		else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "genotyping_protocols";
	my $breeding_program_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("genotyping_protocols"));
	my $breeding_program_list = $breeding_program_data->{result};

	foreach my $y (@$breeding_program_list) {
			push @genotyping_protocols, $y->[0];
	}
		}
		return \@genotyping_protocols;
}

=head2 retrieve_trial_designs

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub retrieve_trial_designs {
    my $self = shift;
		my @trial_designs;
		if ($self->has_trial_designs()) {
	return $self->trial_designs();
		}
		else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "trial_designs";
	my $breeding_program_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("trial_designs"));
	my $breeding_program_list = $breeding_program_data->{result};

	foreach my $y (@$breeding_program_list) {
			push @trial_designs, $y->[0];
	}
		}
		return \@trial_designs;
}


=head2 retrieve_trial_types

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub retrieve_trial_types {
    my $self = shift;
		my @trial_types;
		if ($self->has_trial_types()) {
	return $self->trial_types();
		}
		else {
	my $criteria = $self->get_dataset_definition();
	push @$criteria, "trial_types";
	my $breeding_program_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("trial_types"));
	my $breeding_program_list = $breeding_program_data->{result};

	foreach my $y (@$breeding_program_list) {
			push @trial_types, $y->[0];
	}
		}
		return \@trial_types;
}


sub get_dataset_definition  {
    my $self = shift;
    my @criteria;

    if ($self->has_accessions()) {
	push @criteria, "accessions";
    }
    if ($self->has_plots()) {
	push @criteria, "plots";
    }
		if ($self->has_plants()) {
	push @criteria, "plants";
    }
    if ($self->has_trials()) {
	push @criteria, "trials";
    }
    if ($self->has_traits()) {
	push @criteria, "traits";
    }
    if ($self->has_years()) {
	push @criteria, "years";
    }
    if ($self->has_locations()) {
	push @criteria, "locations";
    }
		if ($self->has_breeding_programs()) {
	push @criteria, "breeding_programs";
		}
		if ($self->has_genotyping_protocols()) {
	push @criteria, "genotyping_protocols";
		}
		if ($self->has_trial_types()) {
	push @criteria, "trial_types";
		}
		if ($self->has_trial_designs()) {
	push @criteria, "trial_designs";
		}


    return \@criteria;

}

=head2 delete()

 Usage:        $dataset->delete();
 Desc:         Deletes the specified dataset. Returns a string with an
               error message is unsuccessful.
 Ret:          string if failure, undef if success
 Args:
 Side Effects: The function does not check for ownership of the dataset,
               this has to be implemented in the calling function.
 Example:

=cut

sub delete {
    my $self = shift;

    my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });

    if (! $row) {
	return "The specified dataset does not exist";
    }

    else {
	eval {
	    $row->delete();
	};
	if ($@) {
	    return "An error occurred, $@";
	}

	else {
	    return undef;
	}

    }
}



1;

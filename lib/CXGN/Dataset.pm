
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
use JSON::XS;
use CXGN::BreederSearch;
use CXGN::People::Schema;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Genotype::Search;
use CXGN::Genotype::Protocol;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;
use CXGN::Trial;
use CXGN::Trait;

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


has 'sp_dataset_id' => ( isa => 'Maybe[Int]',
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


has 'years' =>       ( isa => 'Maybe[ArrayRef[Str]]',
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

=head2 genotyping_projects()

=cut

has 'genotyping_projects' =>      ( isa => 'Maybe[ArrayRef]',
                       is => 'rw',
                       predicate => 'has_genotyping_projects',
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

=head2 outliers()

=cut

has 'outliers' => (
    isa => 'Maybe[ArrayRef]',
    is => 'rw',
    predicate => 'has_outliers',
    default => sub { [] },
);

=head2 outlier_cutoff()

=cut

has 'outlier_cutoffs' => (
    isa => 'Maybe[ArrayRef]',
    is => 'rw',
    predicate => 'has_outlier_cutoffs',
    default => sub { [] },
);

=head2 exclude_dataset_outliers()

=cut

has 'exclude_dataset_outliers' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

=head2 include_phenotype_primary_key()

=cut

has 'include_phenotype_primary_key' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

=head2 tool_compatibility()

=cut

has 'tool_compatibility' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    # default => ""
);

has 'breeder_search' => (isa => 'CXGN::BreederSearch', is => 'rw');

sub BUILD {
    my $self = shift;
    my $args = shift;


    my $bs = CXGN::BreederSearch->new(dbh => $self->schema->storage->dbh());
    $self->breeder_search($bs);

    if ($self->has_sp_dataset_id()) {
        #print STDERR "Processing dataset_id ".$self->sp_dataset_id()."\n";
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
        $self->breeding_programs($dataset->{categories}->{breeding_programs});
        $self->genotyping_protocols($dataset->{categories}->{genotyping_protocols});
	    $self->genotyping_projects($dataset->{categories}->{genotyping_projects});
        $self->locations($dataset->{categories}->{locations});
        $self->trial_designs($dataset->{categories}->{trial_designs});
        $self->trial_types($dataset->{categories}->{trial_types});
        $self->category_order($dataset->{category_order});
        $self->tool_compatibility($dataset->{tool_compatibility});
        $self->is_live($dataset->{is_live});
        $self->is_public($dataset->{is_public}); 
        if ($args->{outliers}) { $self->outliers($args->{outliers})} else { $self->outliers($dataset->{outliers}); }
        if ($args->{outlier_cutoffs}) { $self->outlier_cutoffs } else {($dataset->{outlier_cutoffs}); };
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
            return;
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
            return;
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

    my $dataset = $self->get_dataset_data();

    my $data = {
        name => $self->name(),
        description => $self->description(),
        sp_person_id => $self->sp_person_id(),
        dataset => $dataset,
    };

    return $data;
}

=head2 store()

=cut

sub store {
    my $self = shift;

    #print STDERR "dataset_id = ".$self->sp_dataset_id()."\n";
    if (!$self->has_sp_dataset_id()) {
        #print STDERR "Creating new dataset row... ".$self->sp_dataset_id()."\n";
        my $row = $self->people_schema()->resultset("SpDataset")->create({
            name => $self->name(),
            description => $self->description(),
            sp_person_id => $self->sp_person_id(),
            dataset => JSON::Any->encode($self->get_dataset_data()),
        });
        $self->sp_dataset_id($row->sp_dataset_id());
        return $row->sp_dataset_id();
    }
    else {
        #print STDERR "Updating dataset row ".$self->sp_dataset_id()."\n";
        my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });
        if ($row) {
            $row->name($self->name());
            $row->description($self->description());
            $row->dataset(JSON::Any->encode($self->to_hashref()->{dataset}));
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
    $dataref->{categories}->{accessions} = $self->accessions() if $self->accessions && scalar(@{$self->accessions})>0;
    $dataref->{categories}->{plots} = $self->plots() if $self->plots && scalar(@{$self->plots})>0;
    $dataref->{categories}->{plants} = $self->plants() if $self->plants && scalar(@{$self->plants})>0;
    $dataref->{categories}->{trials} = $self->trials() if $self->trials && scalar(@{$self->trials})>0;
    $dataref->{categories}->{traits} = $self->traits() if $self->traits && scalar(@{$self->traits})>0;
    @{$dataref->{categories}->{years}} = @{$self->years()} if $self->years && scalar(@{$self->years})>0;
    $dataref->{categories}->{breeding_programs} = $self->breeding_programs() if $self->breeding_programs && scalar(@{$self->breeding_programs})>0;
    $dataref->{categories}->{genotyping_protocols} = $self->genotyping_protocols() if $self->genotyping_protocols && scalar(@{$self->genotyping_protocols})>0;
    $dataref->{categories}->{genotyping_projects} = $self->genotyping_projects() if $self->genotyping_projects && scalar(@{$self->genotyping_projects})>0;
    $dataref->{categories}->{trial_designs} = $self->trial_designs() if $self->trial_designs && scalar(@{$self->trial_designs})>0;
    $dataref->{categories}->{trial_types} = $self->trial_types() if $self->trial_types && scalar(@{$self->trial_types})>0;
    $dataref->{categories}->{locations} = $self->locations() if $self->locations && scalar(@{$self->locations})>0;
    $dataref->{category_order} = $self->category_order();
    $dataref->{outliers} = $self->outliers() if $self->outliers;
    $dataref->{outlier_cutoffs} = $self->outlier_cutoffs() if $self->outliers;
    $dataref->{tool_compatibility} = ($self->tool_compatibility) ? $self->tool_compatibility() : undef;
    return $dataref;
}

sub _get_dataref {
    my $self = shift;
    my $dataref;

    $dataref->{accessions} = join(",", @{$self->accessions()}) if $self->accessions && scalar(@{$self->accessions})>0;
    $dataref->{plots} = join(",", @{$self->plots()}) if $self->plots && scalar(@{$self->plots})>0;
    $dataref->{plants} = join(",", @{$self->plants()}) if $self->plants && scalar(@{$self->plants})>0;
    $dataref->{trials} = join(",", @{$self->trials()}) if $self->trials && scalar(@{$self->trials})>0;
    $dataref->{traits} = join(",", @{$self->traits()}) if $self->traits && scalar(@{$self->traits})>0;
    $dataref->{years} = join(",", map { "'".$_."'" } @{$self->years()}) if $self->years && scalar(@{$self->years})>0;
    $dataref->{breeding_programs} = join(",", @{$self->breeding_programs()}) if $self->breeding_programs && scalar(@{$self->breeding_programs})>0;
    $dataref->{genotyping_protocols} = join(",", @{$self->genotyping_protocols()}) if $self->genotyping_protocols && scalar(@{$self->genotyping_protocols})>0;
    $dataref->{genotyping_projects} = join(",", @{$self->genotyping_projects()}) if $self->genotyping_projects && scalar(@{$self->genotyping_projects})>0;
    $dataref->{trial_designs} = join(",", @{$self->trial_designs()}) if $self->trial_designs && scalar(@{$self->trial_designs})>0;
    $dataref->{trial_types} = join(",", @{$self->trial_types()}) if $self->trial_types && scalar(@{$self->trial_types})>0;
    $dataref->{locations} = join(",", @{$self->locations()}) if $self->locations && scalar(@{$self->locations})>0;
    $dataref->{tool_compatibility} = $self->tool_compatibility() if $self->tool_compatibility;
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
    # print STDERR "CXGN::Dataset retrieve_genotypes\n";

    my $accessions = $self->retrieve_accessions();

    #print STDERR "ACCESSIONS: ".Dumper($accessions);

    my @accession_ids;
    foreach (@$accessions) {
        push @accession_ids, $_->[0];
    }

    #print STDERR "ACCESSION IDS: ".Dumper(\@accession_ids);

    my $trials = $self->retrieve_trials();
    my @trial_ids;
    foreach (@$trials) {
        push @trial_ids, $_->[0];
    }

    my @protocols;
    if (!$protocol_id) {
        my $genotyping_protocol_ref = $self->retrieve_genotyping_protocols();
        foreach my $p (@$genotyping_protocol_ref) {
            push @protocols, $p->[0];
        }
    } else {
        @protocols = ($protocol_id);
    }

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema => $self->schema(),
        people_schema=>$self->people_schema,
        accession_list => \@accession_ids,
        trial_list => \@trial_ids,
        protocol_id_list => \@protocols,
        chromosome_list => $chromosome_list,
        start_position => $start_position,
        end_position => $end_position,
        marker_name_list => $marker_name_list,
        genotypeprop_hash_select=>$genotypeprop_hash_select, #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
        protocolprop_top_key_select=>$protocolprop_top_key_select, #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
        protocolprop_marker_hash_select=>$protocolprop_marker_hash_select, #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
        return_only_first_genotypeprop_for_stock=>$return_only_first_genotypeprop_for_stock #FOR MEMORY REASONS TO LIMIT DATA
    });
    my ($total_count, $dataref) = $genotypes_search->get_genotype_info();
    return $dataref;
}

=head2 retrieve_phenotypes()

retrieves phenotypes as a listref of listrefs

=cut

sub retrieve_phenotypes {
    my $self = shift;

    my $accessions = $self->retrieve_accessions();
    my @accession_ids;
    foreach (@$accessions) {
        push @accession_ids, $_->[0];
    }

    my $trials = $self->retrieve_trials();
    my @trial_ids;
    foreach (@$trials) {
        push @trial_ids, $_->[0];
    }

    my $traits = $self->retrieve_traits();
    my @trait_ids;
    foreach (@$traits) {
        push @trait_ids, $_->[0];
    }

    my $dataset_excluded_outliers = $self->exclude_dataset_outliers() ? $self->outliers() : undef;

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        search_type=>'MaterializedViewTable',
        bcs_schema=>$self->schema(),
        data_level=>$self->data_level(),
        trait_list=>\@trait_ids,
        trial_list=>\@trial_ids,
        accession_list=>\@accession_ids,
        exclude_phenotype_outlier=>$self->exclude_phenotype_outlier,
        include_phenotype_primary_key=>$self->include_phenotype_primary_key,
        dataset_excluded_outliers=>$dataset_excluded_outliers
    );
    my @data = $phenotypes_search->get_phenotype_matrix();
    return \@data;
}

=head2 retrieve_phenotypes_ref()

retrieves phenotypes as a hashref representation

=cut

sub retrieve_phenotypes_ref {
    my $self = shift;

    my $accessions = $self->retrieve_accessions();
    my @accession_ids;
    foreach (@$accessions) {
        push @accession_ids, $_->[0];
    }

    my $trials = $self->retrieve_trials();
    my @trial_ids;
    foreach (@$trials) {
        push @trial_ids, $_->[0];
    }

    my $traits = $self->retrieve_traits();
    my @trait_ids;
    foreach (@$traits) {
        push @trait_ids, $_->[0];
    }

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->schema(),
            data_level=>$self->data_level(),
            trait_list=>\@trait_ids,
            trial_list=>\@trial_ids,
            accession_list=>\@accession_ids,
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

    my $accessions = $self->retrieve_accessions();
    my @accession_ids;
    foreach (@$accessions) {
        push @accession_ids, $_->[0];
    }

    my $plots = $self->retrieve_plots();
    my @plot_ids;
    foreach (@$plots) {
        push @plot_ids, $_->[0];
    }

    my $plants = $self->retrieve_plants();
    my @plant_ids;
    foreach (@$plants) {
        push @plant_ids, $_->[0];
    }

    my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
        bcs_schema=>$self->schema(),
        nd_protocol_id=>$nd_protocol_id,
        high_dimensional_phenotype_type=>$high_dimensional_phenotype_type,
        query_associated_stocks=>$query_associated_stocks,
        high_dimensional_phenotype_identifier_list=>$high_dimensional_phenotype_identifier_list,
        accession_list=>\@accession_ids,
        plot_list=>\@plot_ids,
        plant_list=>\@plant_ids,
    });

    my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();

    return ($data_matrix, $identifier_metadata, $identifier_names);
}

=head2 retrieve_high_dimensional_phenotypes_relationship_matrix()

retrieves high-dimensional phenotypes relationship matrix (NIRS, transcriptomics, and metabolomics) as a hashref representation. Will return both the data-matrix and the identifier metadata (transcripts and metabolites)

=cut

sub retrieve_high_dimensional_phenotypes_relationship_matrix {
    my $self = shift;
    my $nd_protocol_id = shift;
    my $high_dimensional_phenotype_type = shift; #NIRS, Transcriptomics, or Metabolomics
    my $query_associated_stocks = shift || 1;
    my $temp_data_file = shift;
    my $download_file_tempfile = shift;

    if (!$nd_protocol_id) {
        die "Must provide the protocol id!\n";
    }
    if (!$high_dimensional_phenotype_type) {
        die "Must provide the high dimensional phenotype type!\n";
    }

    my $accessions = $self->retrieve_accessions();
    my @accession_ids;
    foreach (@$accessions) {
        push @accession_ids, $_->[0];
    }

    my $plots = $self->retrieve_plots();
    my @plot_ids;
    foreach (@$plots) {
        push @plot_ids, $_->[0];
    }

    my $plants = $self->retrieve_plants();
    my @plant_ids;
    foreach (@$plants) {
        push @plant_ids, $_->[0];
    }

    my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesRelationshipMatrix->new({
        bcs_schema=>$self->schema,
        nd_protocol_id=>$nd_protocol_id,
        temporary_data_file=>$temp_data_file,
        relationship_matrix_file=>$download_file_tempfile,
        high_dimensional_phenotype_type=>$high_dimensional_phenotype_type,
        query_associated_stocks=>$query_associated_stocks,
        accession_list=>\@accession_ids,
        plot_list=>\@plot_ids,
        plant_list=>\@plant_ids
    });
    my ($relationship_matrix_data, $data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
    # print STDERR Dumper $relationship_matrix_data;
    # print STDERR Dumper $data_matrix;
    # print STDERR Dumper $identifier_metadata;
    # print STDERR Dumper $identifier_names;

    return ($relationship_matrix_data, $data_matrix, $identifier_metadata, $identifier_names);
}

=head2 retrieve_accessions()

retrieves accessions as a listref of listref [stock_id, uniquename]

=cut

sub retrieve_accessions {
    my $self = shift;
    my $accessions;
    if ($self->accessions() && scalar(@{$self->accessions()})>0) {
        my @stocks;
        my $stock_rs = $self->schema->resultset("Stock::Stock")->search({'stock_id' => { -in => $self->accessions }});
        while (my $a = $stock_rs->next()) {
            push @stocks, [$a->stock_id, $a->uniquename];
        }
        return \@stocks;
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
    if ($self->plots && scalar(@{$self->plots})>0) {
        my @stocks;
        my $stock_rs = $self->schema->resultset("Stock::Stock")->search({'stock_id' => {-in => $self->plots}});
        while (my $a = $stock_rs->next()) {
            push @stocks, [$a->stock_id, $a->uniquename];
        }
        return \@stocks;
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
    if ($self->plants && scalar(@{$self->plants})>0) {
        my @stocks;
        my $stock_rs = $self->schema->resultset("Stock::Stock")->search({'stock_id' => {-in => $self->plants}});
        while (my $a = $stock_rs->next()) {
            push @stocks, [$a->stock_id, $a->uniquename];
        }
        return \@stocks;
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
    if ($self->trials && scalar(@{$self->trials})>0) {
        my @projects;
        my $rs = $self->schema->resultset("Project::Project")->search({'project_id' => {-in => $self->trials}});
        while (my $a = $rs->next()) {
            push @projects, [$a->project_id, $a->name];
        }
        return \@projects;
    }
    else {
        my $criteria = $self->get_dataset_definition();
        push @$criteria, "trials";
        $trials = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("trials"));
    }
    #print STDERR "TRIALS: ".Dumper($trials);
    return $trials->{results};
}

=head2 retrieve_traits()

retrieves traits as a listref of listrefs.

=cut

sub retrieve_traits {
    my $self = shift;
    my $traits;
    if ($self->traits && scalar(@{$self->traits})>0) {
        my @cvterms;
        my $rs = $self->schema->resultset("Cv::Cvterm")->search({'cvterm_id' => {-in => $self->traits}});
        while (my $a = $rs->next()) {
            push @cvterms, [$a->cvterm_id, $a->name];
        }
        return \@cvterms;
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
    if ($self->years() && scalar(@{$self->years()})>0) {
        foreach my $a (@{$self->years()}) {
            push @years, [$a, $a];
        }
    }
    else {
        my $criteria = $self->get_dataset_definition();
        push @$criteria, "years";
        my $year_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("years"));
        my $year_list = $year_data->{results};

        foreach my $y (@$year_list) {
            push @years, [$y->[0], $y->[0]];
        }
    }
    return \@years;
}

=head2 retrieve_years()

retrieves years as a listref of listrefs

=cut

sub retrieve_locations {
    my $self = shift;
    my $locations;
    if ($self->locations && scalar(@{$self->locations})>0) {
        my @locs;
        my $rs = $self->schema->resultset("NaturalDiversity::NdGeolocation")->search({'nd_geolocation_id' => {-in => $self->locations}});
        while (my $a = $rs->next()) {
            push @locs, [$a->nd_geolocation_id, $a->description];
        }
        return \@locs;
    }
    else {
        my $criteria = $self->get_dataset_definition();
        push @$criteria, "locations";
        $locations = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("locations"));
    }
    return $locations->{results};
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
    my $breeding_programs;
    if ($self->breeding_programs && scalar(@{$self->breeding_programs})>0) {
        my @projects;
        my $rs = $self->schema->resultset("Project::Project")->search({'project_id' => {-in => $self->breeding_programs}});
        while (my $a = $rs->next()) {
            push @projects, [$a->project_id, $a->name];
        }
        return \@projects;
    }
    else {
        my $criteria = $self->get_dataset_definition();
        push @$criteria, "breeding_programs";
        $breeding_programs = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("breeding_programs"));
    }
    return $breeding_programs->{results};
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
    my $genotyping_protocols;
    if ($self->genotyping_protocols && scalar(@{$self->genotyping_protocols})>0) {
        my @protocols;
        my $rs = $self->schema->resultset("NaturalDiversity::NdProtocol")->search({'nd_protocol_id' => {-in => $self->genotyping_protocols}});
        while (my $a = $rs->next()) {
            push @protocols, [$a->nd_protocol_id, $a->name];
        }
        return \@protocols;
    }
    else {
        my $criteria = $self->get_dataset_definition();
        push @$criteria, "genotyping_protocols";
        $genotyping_protocols = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("genotyping_protocols"));
    }
    return $genotyping_protocols->{results};
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
    if ($self->trial_designs && scalar(@{$self->trial_designs})>0) {
        foreach my $a (@{$self->trial_designs()}) {
            push @trial_designs, [$a, $a];
        }
    }
    else {
        my $criteria = $self->get_dataset_definition();
        push @$criteria, "trial_designs";
        my $breeding_program_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("trial_designs"));
        my $breeding_program_list = $breeding_program_data->{results};

        foreach my $y (@$breeding_program_list) {
            push @trial_designs, [$y->[0], $y->[0]];
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
    if ($self->trial_types && scalar(@{$self->trial_types})>0) {
        foreach my $a (@{$self->trial_types()}) {
            push @trial_types, [$a, $a];
        }
    }
    else {
        my $criteria = $self->get_dataset_definition();
        push @$criteria, "trial_types";
        my $breeding_program_data = $self->breeder_search()->metadata_query($criteria, $self->_get_source_dataref("trial_types"));
        my $breeding_program_list = $breeding_program_data->{results};

        foreach my $y (@$breeding_program_list) {
            push @trial_types, [$y->[0], $y->[0]];
        }
    }
    return \@trial_types;
}

=head2 retrieve_tool_compatibility

Returns precalculated tool compatibility as a JSON string, if any. 

=cut

sub retrieve_tool_compatibility {
    my $self = shift;

    if ($self->tool_compatibility) {
        return JSON::Any->encode($self->tool_compatibility);
    } else {
        return "(not calculated)";
    }
}

=head2 retrieve_compatible_tool_list

Returns a listref containing the tools this dataset is putatively compatible with (without warnings). Returns undef if no compatible tools found. 

=cut

sub retrieve_compatible_tool_list {
    my $self = shift;

    my @compatible_tools = ();

    my $tool_compatibility = $self->tool_compatibility();

    if (!$tool_compatibility) {
        return @compatible_tools;
    }

    @compatible_tools = grep { ($tool_compatibility->{$_}->{compatible} && !$tool_compatibility->{$_}->{warn}) } keys(%{$tool_compatibility});

    return \@compatible_tools;
}

=head2 calculate_tool_compatibility

Creates a hashref of analysis tools that this dataset can be used with. For example, a dataset with genotype data but no trait phenotypes cannot be used with GWAS.
Note that this function should only ever be called once for a dataset and have the data stored as part of the dataset definition JSON, since retrieving high dimensional phenotype and genotype
data can be time consuming. 

Takes one parameter, passed from Controller: the name of the default genotyping protocol to use as a fallback if none is found in the dataset. 

=cut

sub calculate_tool_compatibility {
    my $self = shift;
    my $default_genotyping_protocol_name = shift;

    my $tool_compatibility = {
        'GWAS' => {
            'compatible' => 0
        },
        # 'solGS' => {
        #     'compatible' => 0
        # },
        'Population Structure' => {
            'compatible' => 0
        },
        'Clustering' => {
            'compatible' => 0
        },
        'Kinship & Inbreeding' => {
            'compatible' => 0
        },
        'Stability' => {
            'compatible' => 0
        },
        'Heritability' => {
            'compatible' => 0
        },
        'Mixed Models' => {
            'compatible' => 0
        },
        'Boxplotter' => {
            'compatible' => 0
        },
        'Correlation' => {
            'compatible' => 0
        },
        'NIRS' => {
            'compatible' => 0
        },
        'Data Summary' => {
            'markers per genotyping protocol' => [],
            'number of phenotyped accessions per trait' => [],
            'number of observations per trait' => [],
            'number of genotyped accessions per protocol' => [],
            'trait observations per location' => {},
            'number of accessions per trial' => []
        }
    };

    my $trials = $self->retrieve_trials(); # faster and easier than pulling it out of the phenotypes_ref
        # listref of listrefs, first index is trialID, second is trial name

    my @trial_ids = map {$_->[0]} @{$trials};
    my $nirs_query = "SELECT DISTINCT nd_protocol.nd_protocol_id FROM project 
    JOIN nd_experiment_project ON nd_experiment_project.project_id=project.project_id 
    JOIN nd_experiment_protocol ON nd_experiment_protocol.nd_experiment_id=nd_experiment_project.nd_experiment_id 
    JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id=nd_protocol.nd_protocol_id 
    WHERE project.project_id in (SELECT unnest(string_to_array(?, ',')::int[]));
    ";
    my $h = $self->schema->storage()->dbh()->prepare($nirs_query);
    $h->execute(join(", ",@trial_ids));
    my @nirs_protocol_ids;
    while (my $nirs_protocol_id = $h->fetchrow_array) {
        push @nirs_protocol_ids, $nirs_protocol_id;
    }
    if (@nirs_protocol_ids) {
        $tool_compatibility->{'NIRS'}->{'compatible'} = 1; #having any nirs protocol ids at all from this query should only really happen if there was a nirs experiment linked to the trial. 
    }
    my $all_traits = $self->retrieve_traits();
    my $traits = [];
    foreach my $trait (@{$all_traits}) { #filter for quantitative traits
        my $trait_obj = CXGN::Trait->new({
            bcs_schema => $self->schema,
            cvterm_id => $trait->[0]
        });
        if ($trait_obj->categories eq ""){# ??? Not sure how to filter properly
            push @{$traits}, $trait;
        }
    }

    my $trial_designs = $self->retrieve_trial_designs();
    my $genotyping_methods = $self->retrieve_genotyping_protocols();# listref of listrefs. First index is 
        # method ID, second is method name
    if (scalar(@{$genotyping_methods}) == 0) {
        my $geno_method_query = "SELECT nd_protocol_id FROM nd_protocol
        WHERE name ilike ?";
        my $h = $self->schema->storage()->dbh()->prepare($geno_method_query);
        $h->execute($default_genotyping_protocol_name);
        my $default_genotyping_protocol_id = $h->fetchrow_array();
        push @{$genotyping_methods}, [$default_genotyping_protocol_id, $default_genotyping_protocol_name];
    }
    my $locations = $self->retrieve_locations(); # faster and easier than pulling it out of the phenotypes_ref
        # listref of listrefs, first index is locationID, second is location name
    my ($phenotypes, undef) = $self->retrieve_phenotypes_ref(); # Returns data as a listref with two hashrefs. First hashref is a list of all phenotypes in this dataset, which is an observational unit w/ a list 
        # of trait observations. Each OU is a stock (plot, accession, etc). Second hashref has all unique traits in the phenotype list. 
        # Relevant hash keys: observations, trial_id, trial_location_id, germplasm_stock_id, trait_id, trait_name, value
    my $accessions = $self->retrieve_accessions();
    my $genotype_counts = {};

    my @accession_ids = map {$_->[0]} @{$accessions};

    my $accessions_in_common = {};
    foreach my $trial (@{$trials}) {
        my $trial_obj = CXGN::Trial->new({
            bcs_schema => $self->schema,
            trial_id => $trial->[0]
        });
        my $current_accessions = $trial_obj->get_accessions();
        push @{$tool_compatibility->{"Data Summary"}->{'number of accessions per trial'}}, $trial->[1]." : ".scalar(@{$current_accessions});
        foreach my $accession (@{$current_accessions}) {
            $accessions_in_common->{$accession->{"stock_id"}}++; 
        }
    }
    my $num_shared_accessions = scalar(grep {$accessions_in_common->{$_} > 1} keys(%{$accessions_in_common}));
    push @{$tool_compatibility->{"Data Summary"}->{'number of accessions per trial'}}, "Shared across all trials : $num_shared_accessions";

    foreach my $method (@{$genotyping_methods}) {
        my $genotype_query = "SELECT COUNT(DISTINCT(stock_id, nd_protocol_id)) FROM stock 
        JOIN nd_experiment_stock USING(stock_id) 
        JOIN nd_experiment_genotype USING(nd_experiment_id) 
        JOIN genotypeprop USING(genotype_id) 
        JOIN nd_experiment_protocol ON(nd_experiment_genotype.nd_experiment_id=nd_experiment_protocol.nd_experiment_id)
            WHERE stock_id IN (SELECT unnest(string_to_array(?, ',')::int[])) AND nd_protocol_id=?;";
        $h = $self->schema->storage()->dbh()->prepare($genotype_query);
        $h->execute(join(", ",@accession_ids), $method->[0]);

        $genotype_counts->{$method->[0]}->{"num_accessions"} = $h->fetchrow_array;

        my $marker_query = "SELECT DISTINCT LENGTH(genotypeprop.value::text) FROM genotypeprop 
        JOIN nd_experiment_genotype USING(genotype_id) 
        JOIN nd_experiment_protocol ON(nd_experiment_genotype.nd_experiment_id=nd_experiment_protocol.nd_experiment_id)
            WHERE nd_protocol_id=?;";
        $h = $self->schema->storage()->dbh()->prepare($marker_query);
        $h->execute($method->[0]);

        $genotype_counts->{$method->[0]}->{"num_markers"} = $h->fetchrow_array;
    }

    my $obs_by_trait = {};
    my $pheno_represented_accessions = {};

    foreach my $observation (@{$phenotypes}){ # hash map of count of every trait observation at every location
        my $location = $observation->{'trial_location_id'};
        $pheno_represented_accessions->{$observation->{'germplasm_stock_id'}} = 1;
        my @obs_traits = map {$_->{'trait_id'}} @{$observation->{'observations'}};
        foreach my $trait (@obs_traits) {
            if (!exists($obs_by_trait->{$trait}->{$location})){
                $obs_by_trait->{$trait}->{$location} = 1;
            } else {
                $obs_by_trait->{$trait}->{$location}++;
            }
            if (!exists($obs_by_trait->{$trait}->{$observation->{'germplasm_stock_id'}})){
                $obs_by_trait->{$trait}->{'accessions'}->{$observation->{'germplasm_stock_id'}} = 1;
            } else {
                $obs_by_trait->{$trait}->{'accessions'}->{$observation->{'germplasm_stock_id'}} += 1;
            }
        }
    }
    my $num_phenotyped_accessions = scalar(%{$pheno_represented_accessions});

    foreach my $method (@{$genotyping_methods}){
        my $num_markers = $genotype_counts->{$method->[0]}->{"num_markers"};
        my $num_accessions = $genotype_counts->{$method->[0]}->{"num_accessions"};

        push @{$tool_compatibility->{"Data Summary"}->{"markers per genotyping protocol"}}, $method->[1]." : ".$num_markers;
        push @{$tool_compatibility->{"Data Summary"}->{"number of genotyped accessions per protocol"}}, $method->[1]." : ".$num_accessions;

        if ($num_markers > 1) {
            if ($num_accessions < 30) {
                $tool_compatibility->{'Population Structure'}->{'warn'}->{"You may not have enough accessions (n=$num_accessions) genotyped for ".$method->[1].", ($num_markers markers) for strong results."} = "";
                $tool_compatibility->{'Kinship & Inbreeding'}->{'warn'}->{"You may not have enough accessions (n=$num_accessions) genotyped for ".$method->[1].", ($num_markers markers) for strong results."} = "";
                $tool_compatibility->{'Clustering'}->{'warn'}->{"You may not have enough accessions (n=$num_accessions) genotyped for ".$method->[1].", ($num_markers markers) for strong genotype clustering."} = "";
            }
            $tool_compatibility->{'Population Structure'}->{'compatible'} = 1;
            $tool_compatibility->{'Population Structure'}->{'types'}->{'Genotype'} = 1;
            $tool_compatibility->{'Kinship & Inbreeding'}->{'compatible'} = 1;
            $tool_compatibility->{'Clustering'}->{'compatible'} = 1;
            $tool_compatibility->{'Clustering'}->{'types'}->{'Genotype'} = "";
        }
    }

    if ($num_phenotyped_accessions > 1 && scalar(@{$traits}) > 1) { #dont need to go trait by trait for clustering, since all traits are combined to eigenvectors. just need plenty of trait measurements
        if (scalar(@{$traits}) < 5) {
            $tool_compatibility->{'Clustering'}->{'warn'}->{"You may not have enough measured traits (only ".scalar(@{$traits}).") for strong phenotype clustering."} = "";
            $tool_compatibility->{'Population Structure'}->{'warn'}->{"You have only ".scalar(@{$traits})." measured traits, which will limit the number of principal components in a phenotype PCA."} = "";
        }
        if ($num_phenotyped_accessions < 30) {
            $tool_compatibility->{'Clustering'}->{'warn'}->{"You may not have enough phenotyped accessions (n=$num_phenotyped_accessions) for strong phenotype clustering."} = "";
            $tool_compatibility->{'Population Structure'}->{'warn'}->{"You may not have enough phenotyped accessions (n=$num_phenotyped_accessions) for a strong phenotype PCA."} = "";
        }
        $tool_compatibility->{'Clustering'}->{'compatible'} = 1;
        $tool_compatibility->{'Clustering'}->{'types'}->{'Phenotype'} = "";
        $tool_compatibility->{'Population Structure'}->{'compatible'} = 1;
        $tool_compatibility->{'Population Structure'}->{'types'}->{'Phenotype'} = "";
    }

    if (exists $tool_compatibility->{'Clustering'}->{'types'}) {
        $tool_compatibility->{'Clustering'}->{'types'} = [keys(%{$tool_compatibility->{'Clustering'}->{'types'}})];
    }
    if (exists $tool_compatibility->{'Population Structure'}->{'types'}) {
        $tool_compatibility->{'Population Structure'}->{'types'} = [keys(%{$tool_compatibility->{'Population Structure'}->{'types'}})];
    }

    foreach my $trait (@{$traits}){ # For each trait, we need to check for number of observations (plus locations for stability)
        my $total_obs = 0;
        my @location_counts = ();
        foreach my $location (@{$locations}){
            $total_obs += $obs_by_trait->{$trait->[0]}->{$location->[0]};
            push @location_counts, $obs_by_trait->{$trait->[0]}->{$location->[0]};
            push @{$tool_compatibility->{"Data Summary"}->{"trait observations per location"}->{$location->[1]}}, $trait->[1]." : ".$obs_by_trait->{$trait->[0]}->{$location->[0]};
        }
        
        my $num_accessions_phenotyped_for_this_trait = scalar(keys(%{$obs_by_trait->{$trait->[0]}->{'accessions'}}));

        push @{$tool_compatibility->{"Data Summary"}->{"number of phenotyped accessions per trait"}}, $trait->[1]." : ".$num_accessions_phenotyped_for_this_trait;
        push @{$tool_compatibility->{"Data Summary"}->{"number of observations per trait"}}, $trait->[1]." : ".$total_obs;

        if ($total_obs > 0) { # This trait was measured

            if ($total_obs < 30) {
                $tool_compatibility->{'Boxplotter'}->{'warn'}->{"There may not be enough observations (n=$total_obs) of ". $trait->[1]." to get meaningful data."} = "";
                $tool_compatibility->{'Correlation'}->{'warn'}->{"There may not be enough observations (n=$total_obs) of ". $trait->[1]." to get meaningful data."} = "";
            }
            $tool_compatibility->{'Boxplotter'}->{'compatible'} = 1;
            push @{$tool_compatibility->{'Boxplotter'}->{'traits'}}, $trait->[1];
            $tool_compatibility->{'Correlation'}->{'compatible'} = 1;
            push @{$tool_compatibility->{'Correlation'}->{'traits'}}, $trait->[1];

            if ($num_accessions_phenotyped_for_this_trait > 1 && scalar(@{$trials}) > 1 && $num_shared_accessions > 2){ #the presence of trial designs implies the presence of trials and differences in "environment" or treatment group. We also need to check that multiple accessions were measured for this trait
                if ($num_accessions_phenotyped_for_this_trait < 30) {
                    $tool_compatibility->{'Heritability'}->{'warn'}->{"There may not be enough accessions (n=$num_accessions_phenotyped_for_this_trait) phenotyped for ".$trait->[1]." to get strong results."} = "";
                }
                if ($num_shared_accessions < 30) {
                    $tool_compatibility->{'Heritability'}->{'warn'}->{"There may not be enough accessions shared across all trials ($num_shared_accessions) to get strong results."} = "";
                }
                $tool_compatibility->{'Heritability'}->{'compatible'} = 1;
                push @{$tool_compatibility->{'Heritability'}->{'traits'}}, $trait->[1];
            }
            if (scalar(grep {$_ > 0} @location_counts) > 1 && $num_accessions_phenotyped_for_this_trait > 1) { # More than one location had measurements, and more than one accession was measured
                if ($num_accessions_phenotyped_for_this_trait < 30) {
                    $tool_compatibility->{'Stability'}->{'warn'}->{"There may not be enough accessions (n=$num_accessions_phenotyped_for_this_trait) phenotyped for ".$trait->[1]." to get strong results."} = "";
                }
                if (scalar(grep {$_ < 30} @location_counts) > 1) {#If any of the locations had too few pheno observations
                    $tool_compatibility->{'Stability'}->{'warn'}->{"There may not be enough phenotype observations at all trial locations to get strong results."} = "";
                }
                if ($total_obs < $num_accessions_phenotyped_for_this_trait) {# If total observations is lower than number of accessions, accessions were probably not replicated
                    $tool_compatibility->{'Stability'}->{'warn'}->{"There may not be enough replicated measurements of ".$trait->[1]."."} = "";
                }
                $tool_compatibility->{'Stability'}->{'compatible'} = 1;
                push @{$tool_compatibility->{'Stability'}->{'traits'}}, $trait->[1];
            }
            if(scalar(@{$trial_designs}) > 0 && $num_accessions_phenotyped_for_this_trait > 1) {
                if ($num_accessions_phenotyped_for_this_trait < 30) {
                    $tool_compatibility->{'Mixed Models'}->{'warn'}->{"There may not be enough accessions (n=$num_accessions_phenotyped_for_this_trait) phenotyped for ".$trait->[1]." to build a strong model."} = "";
                }
                $tool_compatibility->{'Mixed Models'}->{'compatible'} = 1;
                push @{$tool_compatibility->{'Mixed Models'}->{'traits'}}, $trait->[1];
            }
        }

        foreach my $method (@{$genotyping_methods}){ # There needs to be consistent genotyping protocol for genomic modeling
            my $num_markers = $genotype_counts->{$method->[0]}->{"num_markers"};
            my $num_genotyped_accessions = $genotype_counts->{$method->[0]}->{"num_accessions"};
            my $num_accessions_phenotyped_for_this_trait = scalar( keys(%{$obs_by_trait->{$trait->[0]}->{'accessions'}}) );
            if ($total_obs > 100 && $num_markers > 100 && $num_accessions_phenotyped_for_this_trait > 50 && $num_genotyped_accessions > 50 && scalar(@{$trials}) > 0) { # If lots of markers, lots of accessions, and lots of phenotype measurements, then you can do genomic modeling
                if ($total_obs < 300) {
                    $tool_compatibility->{'GWAS'}->{'warn'}->{"There may not be enough observations (n=$total_obs) of ".$trait->[1]." to identify associated loci."} = "";
                }
                if ($num_markers < 2500) {
                    $tool_compatibility->{'GWAS'}->{'warn'}->{"There may not be enough SNPs ($num_markers) genotyped for method ".$method->[1]." to identify associated loci."} = "";
                }
                if ($num_accessions_phenotyped_for_this_trait < 300 || $num_genotyped_accessions < 300) {
                    $tool_compatibility->{'GWAS'}->{'warn'}->{"There may not be enough accessions (n=$num_genotyped_accessions) both genotyped and assayed for ".$trait->[1]." to identify associated loci."} = "";
                }
                push @{$tool_compatibility->{'GWAS'}->{'traits'}}, $trait->[1];
                $tool_compatibility->{'GWAS'}->{'compatible'} = 1;
                # push @{$tool_compatibility->{'solGS'}->{'traits'}}, $trait->[1];
            }
        }
    }

    foreach my $tool (keys(%{$tool_compatibility})) {
        if (exists($tool_compatibility->{$tool}->{"warn"})){
            $tool_compatibility->{$tool}->{"warn"} = join("\n", keys(%{$tool_compatibility->{$tool}->{"warn"}}));
        }
    }

    $self->tool_compatibility($tool_compatibility);

    #return JSON::Any->encode($tool_compatibility);
    return $tool_compatibility;
}

=head2 update_tool_compatibility

Recalculates and stores tool compatibility individually without updating other dataset characteristics. Used in a button in the dataset details page. 

=cut

sub update_tool_compatibility {
    my $self = shift;

    $self->calculate_tool_compatibility();

    my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });
    if (! $row) {
        return "The specified dataset does not exist";
    } else {
        eval {
            $row->sp_person_id($self->sp_person_id());
            $row->sp_dataset_id($self->sp_dataset_id());
            $row->dataset(JSON::Any->encode($self->to_hashref()->{dataset}));
            $row->update();
        };
        if ($@) {
            return "An error occurred, $@";
        } else {
            return;
        }
    }
}

sub get_dataset_definition  {
    my $self = shift;
    my @criteria;

    if ($self->accessions && scalar(@{$self->accessions})>0) {
        push @criteria, "accessions";
    }
    if ($self->plots && scalar(@{$self->plots})>0) {
        push @criteria, "plots";
    }
    if ($self->plants && scalar(@{$self->plants})>0) {
        push @criteria, "plants";
    }
    if ($self->trials && scalar(@{$self->trials})>0) {
        push @criteria, "trials";
    }
    if ($self->traits && scalar(@{$self->traits})>0) {
        push @criteria, "traits";
    }
    if ($self->years && scalar(@{$self->years})>0) {
        push @criteria, "years";
    }
    if ($self->locations && scalar(@{$self->locations})>0) {
        push @criteria, "locations";
    }
    if ($self->breeding_programs && scalar(@{$self->breeding_programs})>0) {
        push @criteria, "breeding_programs";
    }
    if ($self->genotyping_protocols && scalar(@{$self->genotyping_protocols})>0) {
        push @criteria, "genotyping_protocols";
    }
    if ($self->genotyping_projects && scalar(@{$self->genotyping_projects})>0) {
        push @criteria, "genotyping_projects";
    }
    if ($self->trial_types && scalar(@{$self->trial_types})>0) {
        push @criteria, "trial_types";
    }
    if ($self->trial_designs && scalar(@{$self->trial_designs})>0) {
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
    } else {
	eval {
	    $row->delete();
	};
	if ($@) {
	    return "An error occurred, $@";
        } else {
	    return;
	}

    }
}

sub update_description {
    my $self = shift;
    my $description = shift;
    my $row = $self->people_schema()->resultset("SpDataset")->find( { sp_dataset_id => $self->sp_dataset_id() });
    if (! $row) {
        return "The specified dataset does not exist";
    } else {
        eval {
            $row->sp_person_id($self->sp_person_id());
            $row->sp_dataset_id($self->sp_dataset_id());
            $row->description($description);
            $row->update();
        };
        if ($@) {
            return "An error occurred, $@";
        } else {
            return;
        }
    }
}

=head2 get_child_analyses()

# Retrieves the list of analyses that use this dataset. 

=cut

sub get_child_analyses {
    my $self = shift;
    my $dataset_id = $self->sp_dataset_id();

    my $dbh = $self->schema->storage->dbh();

    my $analysis_info_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'analysis_metadata_json', 'project_property')->cvterm_id();

    my $analysis_q = "select DISTINCT project.name, project.project_id FROM projectprop 
    JOIN project USING (project_id) 
    WHERE projectprop.type_id=$analysis_info_type_id 
        AND analysisinfo.value::json->>'dataset_id'=?;";
    my $h = $dbh->prepare($analysis_q);
    $h->execute($dataset_id);

    my @html = ();

    while (my ($analysis_name, $analysis_id) = $h->fetchrow_array()){
        push @html, "<a href=/analyses/".$analysis_id.">".$analysis_name."</a>";
    }

    return join(" | ", @html);
}



1;

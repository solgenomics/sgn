package CXGN::Pedigree::AddCrosses;

=head1 NAME

CXGN::Pedigree::AddCrosses - a module to add cross.

=head1 USAGE

 my $cross_add = CXGN::Pedigree::AddCrosses->new({ schema => $schema, location => $location_name, program => $program_name, crosses =>  \@array_of_pedigree_objects} );
 my $validated = $cross_add->validate_crosses(); #is true when all of the crosses are valid and the accessions they point to exist in the database.
 $cross_add->add_crosses();

=head1 DESCRIPTION

Adds an array of crosses. The parents used in the cross must already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)
 Titima Tantikanjana (tt15@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use CXGN::Stock::StockLookup;
use CXGN::BreedersToolbox::Projects;
use CXGN::Trial;
use CXGN::Trial::Folder;
use SGN::Model::Cvterm;
use Data::Dumper;
use File::Basename qw | basename dirname|;
use CXGN::UploadFile;


class_type 'Pedigree', { class => 'Bio::GeneticRelationships::Pedigree' };

has 'chado_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_chado_schema',
    required => 1,
);

has 'phenome_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_phenome_schema',
    required => 1,
);

has 'metadata_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_metadata_schema',
    required => 0,
);

has 'dbh' => (
    is  => 'rw',
    predicate => 'has_dbh',
    required => 1,
);

has 'crosses' => (
    isa =>'ArrayRef[Pedigree]',
    is => 'rw',
    predicate => 'has_crosses',
    required => 1,
);

has 'user_id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_user_id',
    required => 1,
);

has 'crossing_trial_id' => (
    isa =>'Int',
    is => 'rw',
    predicate => 'has_crossing_trial_id',
    required => 1,
);

has 'archived_filename' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_archived_filename',
    required => 0,
);

has 'archived_file_type' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_archived_file_type',
    required => 0,
);


sub add_crosses {
    my $self = shift;
    my $chado_schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $metadata_schema = $self->get_metadata_schema();
    my $crossing_trial_id = $self->get_crossing_trial_id();
    my $owner_id = $self->get_user_id();
    my @crosses;
    my $transaction_error;
    my @added_stock_ids;
    my %nd_experiments;

    if (!$self->validate_crosses()) {
        print STDERR "Invalid pedigrees in array.  No crosses will be added\n";
        return;
    }

    #add all crosses in a single transaction
    my $coderef = sub {

        #get cvterms for parents
        my $female_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'female_parent', 'stock_relationship');
        my $male_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'male_parent', 'stock_relationship');

		#get cvterm for cross_combination
		my $cross_combination_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross_combination', 'stock_property');

        #get cvterm for cross_experiment
        my $cross_experiment_type_cvterm =  SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross_experiment', 'experiment_type');

        #get cvterm for stock type cross
        my $cross_stock_type_cvterm  =  SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross', 'stock_type');

        #get cvterm for female and male plots
        my $female_plot_of_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'female_plot_of', 'stock_relationship');
        my $male_plot_of_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'male_plot_of', 'stock_relationship');

        #get cvterm for female and male plants
        my $female_plant_of_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'female_plant_of', 'stock_relationship');
        my $male_plant_of_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'male_plant_of', 'stock_relationship');

		my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project location', 'project_property')->cvterm_id();
		my $geolocation_rs = $chado_schema->resultset("Project::Projectprop")->find({project_id => $crossing_trial_id, type_id => $project_location_cvterm_id});

        my $cross_identifier_cvterm  =  SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross_identifier', 'stock_property');

        @crosses = @{$self->get_crosses()};
        foreach my $pedigree (@crosses) {
            my $experiment;
            my $cross_stock;
            my $organism_id;
            my $female_parent_name;
            my $male_parent_name;
            my $female_parent;
            my $male_parent;
            my $population_stock;
            my $cross_type = $pedigree->get_cross_type();
            my $cross_name = $pedigree->get_name();
			my $cross_combination = $pedigree->get_cross_combination();
            my $female_plot_name;
            my $male_plot_name;
            my $female_plot;
            my $male_plot;
            my $female_plant_name;
            my $male_plant_name;
            my $female_plant;
            my $male_plant;

            $cross_name =~ s/^\s+|\s+$//g; #trim whitespace from both ends


            if ($pedigree->has_female_parent()) {
                $female_parent_name = $pedigree->get_female_parent()->get_name();
                if ($cross_type eq 'backcross') {
                    $female_parent = $self->_get_accession_or_cross($female_parent_name);
                } else {
                    $female_parent = $self->_get_accession($female_parent_name);
                }
            }

            if ($pedigree->has_male_parent()) {
                $male_parent_name = $pedigree->get_male_parent()->get_name();
                if ($cross_type eq 'backcross') {
                    $male_parent = $self->_get_accession_or_cross($male_parent_name);
                } else {
                    $male_parent = $self->_get_accession($male_parent_name);
                }
            }

            if ($pedigree->has_female_plot()) {
                $female_plot_name = $pedigree->get_female_plot()->get_name();
                $female_plot = $self->_get_plot($female_plot_name);
            }

            if ($pedigree->has_male_plot()) {
                $male_plot_name = $pedigree->get_male_plot()->get_name();
                $male_plot = $self->_get_plot($male_plot_name);
            }

            if ($pedigree->has_female_plant()) {
                $female_plant_name = $pedigree->get_female_plant()->get_name();
                $female_plant = $self->_get_plant($female_plant_name);
            }

            if ($pedigree->has_male_plant()) {
                $male_plant_name = $pedigree->get_male_plant()->get_name();
                $male_plant = $self->_get_plant($male_plant_name);
            }

            #organism of cross experiment will be the same as the female parent
            if ($female_parent) {
                $organism_id = $female_parent->organism_id();
            } else {
                $organism_id = $male_parent->organism_id();
            }

            my $previous_cross_stock_rs = $chado_schema->resultset("Stock::Stock")->search({
                organism_id => $organism_id,
                uniquename => $cross_name,
                type_id => $cross_stock_type_cvterm->cvterm_id,
            });
            if ($previous_cross_stock_rs->count > 0){
            #If cross already exists, just go to next cross
                next;
            }

            #create cross experiment
            $experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')->create({
                nd_geolocation_id => $geolocation_rs->value,
                type_id => $cross_experiment_type_cvterm->cvterm_id,
            });
            my $nd_experiment_id = $experiment->nd_experiment_id();
            $nd_experiments{$nd_experiment_id}++;

            #create a stock of type cross
            $cross_stock = $chado_schema->resultset("Stock::Stock")->find_or_create({
                organism_id => $organism_id,
                name => $cross_name,
                uniquename => $cross_name,
                type_id => $cross_stock_type_cvterm->cvterm_id,
            });

            #add stock_id of cross to an array so that the owner can be associated in the phenome schema after the transaction on the chado schema completes
            push (@added_stock_ids,  $cross_stock->stock_id());


            #link parents to the stock of type cross
            if ($female_parent) {
                $cross_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $female_parent_cvterm->cvterm_id(),
                    object_id => $cross_stock->stock_id(),
                    subject_id => $female_parent->stock_id(),
                    value => $cross_type,
                });
            }

            if ($male_parent) {
                $cross_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $male_parent_cvterm->cvterm_id(),
                    object_id => $cross_stock->stock_id(),
                    subject_id => $male_parent->stock_id(),
                });
            }

            if ($cross_type eq "self" && $female_parent) {
                $cross_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $male_parent_cvterm->cvterm_id(),
                    object_id => $cross_stock->stock_id(),
                    subject_id => $female_parent->stock_id(),
                });
            }

            #link cross to female_plot
            if ($female_plot) {
                $cross_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $female_plot_of_cvterm->cvterm_id(),
                    object_id => $cross_stock->stock_id(),
                    subject_id => $female_plot->stock_id(),
                });
            }

            #link cross to male_plot
            if ($male_plot) {
                $cross_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $male_plot_of_cvterm->cvterm_id(),
                    object_id => $cross_stock->stock_id(),
                    subject_id => $male_plot->stock_id(),
                });
            }

            #link cross to female_plant
            if ($female_plant) {
                $cross_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $female_plant_of_cvterm->cvterm_id(),
                    object_id => $cross_stock->stock_id(),
                    subject_id => $female_plant->stock_id(),
                });
            }

            #link cross to male_plant
            if ($male_plant) {
                $cross_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $male_plant_of_cvterm->cvterm_id(),
                    object_id => $cross_stock->stock_id(),
                    subject_id => $male_plant->stock_id(),
                });
            }

            #link cross to cross_combination
			if ($cross_combination) {
				$cross_stock->create_stockprops({$cross_combination_cvterm->name() => $cross_combination});
            }

            #link the stock of type cross to the experiment
            $experiment->find_or_create_related('nd_experiment_stocks' , {
	              stock_id => $cross_stock->stock_id(),
	              type_id  =>  $cross_experiment_type_cvterm->cvterm_id(),
		        });

            #link the experiment to the project
            $experiment->find_or_create_related('nd_experiment_projects', {
                project_id => $self->get_crossing_trial_id,
            });

            my $identifier_female_id;
            my $identifier_male_id;
            if ($female_plant){
                $identifier_female_id = $female_plant->stock_id();
            } elsif ($female_plot){
                $identifier_female_id = $female_plot->stock_id();
            } else {
                $identifier_female_id = $female_parent->stock_id();
            }

            if ($male_plant){
                $identifier_male_id = $male_plant->stock_id();
            } elsif ($male_plot){
                $identifier_male_id = $male_plot->stock_id();
            } elsif ($male_parent) {
                $identifier_male_id = $male_parent->stock_id();
            } else {
                $identifier_male_id = 'NA'
            }

            my $cross_identifier = $crossing_trial_id.'_'.$identifier_female_id.'_'.$identifier_male_id;
            $cross_stock->create_stockprops({$cross_identifier_cvterm->name() => $cross_identifier});
            print STDERR "CROSS IDENTIFIER =".Dumper($cross_identifier)."\n";
        }

    };

    #try to add all crosses in a transaction
    try {
        $chado_schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error creating a cross: $transaction_error\n";
        return;
    }

    foreach my $stock_id (@added_stock_ids) {
        #add the owner for this stock
        $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id => $stock_id,
            sp_person_id => $owner_id,
        });
    }

    #link nd_experiments to uploaded file
	my $archived_filename_with_path = $self->get_archived_filename;
    print STDERR "FILE =".Dumper($archived_filename_with_path)."\n";
    if ($archived_filename_with_path) {
        print STDERR "Generating md_file entry for cross file...\n";
        my $md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $owner_id});
        $md_row->insert();
        my $upload_file = CXGN::UploadFile->new();
        my $md5 = $upload_file->get_md5($archived_filename_with_path);
        my $md5checksum = $md5->hexdigest();
        my $file_row = $metadata_schema->resultset("MdFiles")->create({
            basename => basename($archived_filename_with_path),
            dirname => dirname($archived_filename_with_path),
            filetype => $self->get_archived_file_type,
            md5checksum => $md5checksum,
            metadata_id => $md_row->metadata_id(),
        });

        my $file_id = $file_row->file_id();
        print STDERR "FILE ID =".Dumper($file_id)."\n";

        foreach my $nd_experiment_id (keys %nd_experiments) {
            my $nd_experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")->create({
                nd_experiment_id => $nd_experiment_id,
                file_id => $file_id,
            });
        }
    }

    return 1;
}


sub validate_crosses {
    my $self = shift;
    my $chado_schema = $self->get_chado_schema();
    my @crosses = @{$self->get_crosses()};
    my $invalid_cross_count = 0;
    my $crossing_trial_lookup;
    my $crossing_trial;
    my $trial_lookup;

    $crossing_trial_lookup = CXGN::BreedersToolbox::Projects->new({ schema => $chado_schema});
    $crossing_trial = $crossing_trial_lookup->get_crossing_trials($self->get_crossing_trial_id());
    if (!$crossing_trial) {
        print STDERR "Crossing trial ". $self->get_crossing_trials() ." not found\n";
        return;
    }

    foreach my $cross (@crosses) {
        my $validated_cross = $self->_validate_cross($cross);

        if (!$validated_cross) {
            $invalid_cross_count++;
        }

    }

    if ($invalid_cross_count > 0) {
        print STDERR "There were $invalid_cross_count invalid crosses\n";
        return;
    }

    return 1;
}

sub _validate_cross {
    my $self = shift;
    my $pedigree = shift;
    my $chado_schema = $self->get_chado_schema();
    my $name = $pedigree->get_name();
    my $cross_type = $pedigree->get_cross_type();
    my $female_parent_name;
    my $male_parent_name;
    my $female_parent;
    my $male_parent;

    if ($cross_type eq "biparental") {
        $female_parent_name = $pedigree->get_female_parent()->get_name();
        $male_parent_name = $pedigree->get_male_parent()->get_name();
        $female_parent = $self->_get_accession($female_parent_name);
        $male_parent = $self->_get_accession($male_parent_name);

        if (!$female_parent || !$male_parent) {
            print STDERR "Parent $female_parent_name or $male_parent_name in pedigree is not a stock\n";
            return;
        }

    } elsif ($cross_type eq "self") {
        $female_parent_name = $pedigree->get_female_parent()->get_name();
        $female_parent = $self->_get_accession($female_parent_name);

        if (!$female_parent) {
            print STDERR "Parent $female_parent_name in pedigree is not a stock\n";
            return;
        }

    }  elsif ($cross_type eq "open") {
        $female_parent_name = $pedigree->get_female_parent()->get_name();
        $female_parent = $self->_get_accession($female_parent_name);

        if (!$female_parent) {
            print STDERR "Parent $female_parent_name in pedigree is not a stock\n";
            return;
        }
    } elsif ($cross_type eq 'backcross') {
	        $female_parent_name = $pedigree->get_female_parent()->get_name();
	        $male_parent_name = $pedigree->get_male_parent()->get_name();
	        $female_parent = $self->_get_accession_or_cross($female_parent_name);
	        $male_parent = $self->_get_accession_or_cross($male_parent_name);

        if (!$female_parent || !$male_parent) {
            print STDERR "Parent $female_parent_name or $male_parent_name in pedigree is not a stock\n";
            return;
	    }

	}

    #add support for other cross types here

    #else {
    #  return;
    #}

    return 1;
}

sub _get_accession {
    my $self = shift;
    my $accession_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');
    #not sure why vector_construct is in this function
    my $vector_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'vector_construct', 'stock_type');
    my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'population', 'stock_type');

    $stock_lookup->set_stock_name($accession_name);
    $stock = $stock_lookup->get_stock_exact();

    if (!$stock) {
        print STDERR "Parent name is not a stock\n";
        return;
    }

	#not sure why vector_construct is in this function
    if (($stock->type_id() != $accession_cvterm->cvterm_id()) && ($stock->type_id() != $population_cvterm->cvterm_id())  && ($stock->type_id() != $vector_cvterm->cvterm_id()) ) {
        print STDERR "Parent name is not a stock of type accession or population or vector_construct\n";
        return;
    }

    return $stock;
}

sub _get_plot {
    my $self = shift;
    my $plot_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;
    my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type');

    $stock_lookup->set_stock_name($plot_name);
    $stock = $stock_lookup->get_stock_exact();

    if (!$stock) {
        print STDERR "Parent name is not a stock\n";
        return;
    }

	if ($stock->type_id() != $plot_cvterm->cvterm_id()) {
        print STDERR "Parent name is not a stock of type plot\n";
        return;
    }

    return $stock;
}

sub _get_plant {
    my $self = shift;
    my $plant_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;
    my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type');

    $stock_lookup->set_stock_name($plant_name);
    $stock = $stock_lookup->get_stock_exact();

    if (!$stock) {
        print STDERR "Parent name is not a stock\n";
        return;
    }

	if ($stock->type_id() != $plant_cvterm->cvterm_id()) {
        print STDERR "Parent name is not a stock of type plant\n";
        return;
    }

    return $stock;
}

sub _get_accession_or_cross {
    my $self = shift;
    my $parent_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');
	my $cross_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross', 'stock_type');

    $stock_lookup->set_stock_name($parent_name);
    $stock = $stock_lookup->get_stock_exact();

    if (!$stock) {
        print STDERR "Parent name is not a stock\n";
        return;
    }

    if (($stock->type_id() != $accession_cvterm->cvterm_id()) && ($stock->type_id() != $cross_cvterm->cvterm_id())) {
        print STDERR "Parent name is not a stock of type accession or cross \n";
        return;
    }

    return $stock;
}

#######
1;
#######

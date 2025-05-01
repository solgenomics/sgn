=head1 NAME

CXGN::Transformation::Transformation - an object representing transformation in the database

=head1 DESCRIPTION


=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::Transformation::Transformation;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

has 'schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'project_id' => (
    isa => "Int",
    is => 'rw',
);

has 'transformation_stock_id' => (
    isa => "Int",
    is => 'rw',
);

has 'transformants' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy => 1,
    builder => '_get_transformants',
);

has 'obsoleted_transformants' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy => 1,
    builder => '_get_obsoleted_transformants',
);

has 'tracking_identifier' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy => 1,
    builder => '_get_tracking_identifier',
);

has 'transformation_control_stock_id' => (
    isa => "Int",
    is => 'rw',
);

has 'is_a_control' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);


sub get_active_transformations_in_project {
    my $self = shift;
    my $schema = $self->schema();
    my $project_id = $self->project_id();
    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
	my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
	my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $plant_material_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plant_material_of", "stock_relationship")->cvterm_id();
    my $vector_construct_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct_of", "stock_relationship")->cvterm_id();
    my $transformation_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_experiment', 'experiment_type')->cvterm_id();
    my $transformation_notes_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_notes', 'stock_property')->cvterm_id();
    my $completed_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'completed_metadata', 'stock_property')->cvterm_id;
    my $terminated_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'terminated_metadata', 'stock_property')->cvterm_id;
    my $is_a_transformation_control_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a_transformation_control', 'stock_property')->cvterm_id;
    my $control_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'control_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT transformation.stock_id, transformation.uniquename, plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value, stockprop2.value, control.stock_id, control.uniquename
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS transformation ON (nd_experiment_stock.stock_id = transformation.stock_id) AND transformation.type_id = ?
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformation.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stockprop AS stockprop2 ON (stockprop2.stock_id = transformation.stock_id) AND stockprop2.type_id = ?
        LEFT JOIN stock_relationship AS has_control ON (has_control.object_id =transformation.stock_id) AND has_control.type_id = ?
        LEFT JOIN stock AS control on (has_control.subject_id = control.stock_id)
        LEFT JOIN stockprop AS stockprop3 ON (stockprop3.stock_id = transformation.stock_id) AND stockprop3.type_id in (?, ?)
        WHERE nd_experiment_project.project_id = ? AND stockprop3.value IS NULL";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformation_type_id, $plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $is_a_transformation_control_type_id, $control_of_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $project_id);

    my @transformations = ();
    while (my ($transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes, $is_a_control, $control_id, $control_name) = $h->fetchrow_array()){
        push @transformations, [$transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes, $is_a_control, $control_id, $control_name]
    }

    return \@transformations;
}


sub get_inactive_transformations_in_project {
    my $self = shift;
    my $schema = $self->schema();
    my $project_id = $self->project_id();
    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
	my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
	my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $plant_material_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plant_material_of", "stock_relationship")->cvterm_id();
    my $vector_construct_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct_of", "stock_relationship")->cvterm_id();
    my $transformation_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_experiment', 'experiment_type')->cvterm_id();
    my $transformation_notes_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_notes', 'stock_property')->cvterm_id();
    my $completed_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'completed_metadata', 'stock_property')->cvterm_id;
    my $terminated_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'terminated_metadata', 'stock_property')->cvterm_id;
    my $is_a_transformation_control_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a_transformation_control', 'stock_property')->cvterm_id;
    my $control_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'control_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT transformation.stock_id, transformation.uniquename, plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value, stockprop2.value, control.stock_id, control.uniquename, cvterm.name
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS transformation ON (nd_experiment_stock.stock_id = transformation.stock_id) AND transformation.type_id = ?
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformation.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stockprop AS stockprop2 ON (stockprop2.stock_id = transformation.stock_id) and stockprop2.type_id = ?
        LEFT JOIN stock_relationship AS has_control ON (has_control.object_id =transformation.stock_id) AND has_control.type_id = ?
        LEFT JOIN stock AS control on (has_control.subject_id = control.stock_id)
        JOIN stockprop AS stockprop3 ON (stockprop3.stock_id = transformation.stock_id) AND stockprop3.type_id in (?, ?)
        JOIN cvterm ON (stockprop3.type_id = cvterm.cvterm_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformation_type_id, $plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $is_a_transformation_control_type_id, $control_of_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $project_id);

    my @transformations = ();
    while (my ($transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes, $is_a_control, $control_id, $control_name, $status_type) = $h->fetchrow_array()){
        push @transformations, [$transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes, $is_a_control, $control_id, $control_name, $status_type]
    }

    return \@transformations;
}


sub _get_transformants {
    my $self = shift;
    my $schema = $self->schema();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $transformant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM stock_relationship
        JOIN stock ON (stock_relationship.subject_id = stock.stock_id) and stock_relationship.type_id = ?
        where stock_relationship.object_id = ? AND stock.is_obsolete = 'F' ";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformant_of_type_id, $transformation_stock_id);

    my @transformants = ();
    while (my ($stock_id,  $stock_name) = $h->fetchrow_array()){
        push @transformants, [$stock_id,  $stock_name]
    }

    $self->transformants(\@transformants);
}


sub _get_obsoleted_transformants {
    my $self = shift;
    my $schema = $self->schema();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $transformant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, metadata.md_metadata.obsolete_note, metadata.md_metadata.modification_note, phenome.stock_owner.sp_person_id
        FROM stock_relationship
        JOIN stock ON (stock_relationship.subject_id = stock.stock_id) and stock_relationship.type_id = ?
        JOIN phenome.stock_owner ON (stock.stock_id = phenome.stock_owner.stock_id)
        JOIN metadata.md_metadata ON (phenome.stock_owner.metadata_id = metadata.md_metadata.metadata_id)
        where stock_relationship.object_id = ? AND stock.is_obsolete != 'F' ";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformant_of_type_id, $transformation_stock_id);

    my @obsoleted_transformants = ();
    while (my ($stock_id,  $stock_name, $obsolete_note, $obsolete_date, $sp_person_id) = $h->fetchrow_array()){
        push @obsoleted_transformants, [$stock_id,  $stock_name, $obsolete_note, $obsolete_date, $sp_person_id]
    }

    $self->obsoleted_transformants(\@obsoleted_transformants);

}


sub get_transformation_info {
    my $self = shift;
    my $schema = $self->schema();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $plant_material_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plant_material_of", "stock_relationship")->cvterm_id();
    my $vector_construct_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct_of", "stock_relationship")->cvterm_id();
    my $transformation_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_experiment', 'experiment_type')->cvterm_id();
    my $transformation_notes_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_notes', 'stock_property')->cvterm_id();
    my $completed_metadata_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'completed_metadata', 'stock_property')->cvterm_id();
    my $terminated_metadata_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'terminated_metadata', 'stock_property')->cvterm_id();
    my $is_a_transformation_control_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a_transformation_control', 'stock_property')->cvterm_id();
    my $control_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'control_of', 'stock_relationship')->cvterm_id();


    my $q = "SELECT plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value, stockprop2.value, control.stock_id, control.uniquename, cvterm.name
        FROM stock AS transformation
        JOIN stock_relationship AS plant_relationship ON (transformation.stock_id = plant_relationship.object_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stockprop AS stockprop2 ON (stockprop2.stock_id = transformation.stock_id) AND stockprop2.type_id = ?
        LEFT JOIN stock_relationship AS has_control ON (has_control.object_id =transformation.stock_id) AND has_control.type_id = ?
        LEFT JOIN stock AS control on (has_control.subject_id = control.stock_id)
        LEFT JOIN stockprop AS stockprop3 ON (stockprop3.stock_id = transformation.stock_id) AND stockprop3.type_id in (?, ?)
        LEFT JOIN cvterm ON (stockprop3.type_id = cvterm.cvterm_id)
        WHERE transformation.stock_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $is_a_transformation_control_type_id, $control_of_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $transformation_stock_id);

    my @transformation_info = ();
    while (my ($plant_id, $plant_name, $vector_id, $vector_name, $notes, $is_a_control, $control_id, $control_name, $updated_status) = $h->fetchrow_array()){
        push @transformation_info, [$plant_id, $plant_name, $vector_id, $vector_name, $notes, $is_a_control, $control_id, $control_name, $updated_status]
    }
    print STDERR "INFO =".Dumper(\@transformation_info)."\n";

    return \@transformation_info;

}


sub get_associated_projects {
    my $self = shift;
    my $schema = $self->schema();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $program_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();

    my $q = "SELECT project.project_id, project.name, program.project_id, program.name
        FROM nd_experiment_stock
        JOIN nd_experiment_project ON (nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id)
        JOIN project ON (nd_experiment_project.project_id = project.project_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id) AND project_relationship.type_id = ?
        JOIN project AS program ON (project_relationship.object_project_id = program.project_id)
        WHERE nd_experiment_stock.stock_id = ? ";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($program_relationship_cvterm_id, $transformation_stock_id);

    my @associated_projects = ();
    while (my ($project_id,  $project_name, $program_id, $program_name) = $h->fetchrow_array()){
        push @associated_projects, [$project_id,  $project_name, $program_id, $program_name]
    }

    return \@associated_projects;
}


sub _get_tracking_identifier {
    my $self = shift;
    my $schema = $self->schema();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $material_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "material_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM stock_relationship
        JOIN stock ON (stock_relationship.object_id = stock.stock_id) and stock_relationship.type_id = ?
        where stock_relationship.subject_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($material_of_type_id, $transformation_stock_id);

    my @tracking_identifier_info = ();
    while (my ($stock_id,  $stock_name) = $h->fetchrow_array()){
        push @tracking_identifier_info, [$stock_id,  $stock_name]
    }

    $self->tracking_identifier(\@tracking_identifier_info);

}


sub get_autogenerated_name_format {
    my $self = shift;
    my $schema = $self->schema();
    my $project_id = $self->project_id();
    my $format;

    my $name_format_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'autogenerated_name_format', 'project_property')->cvterm_id();
    my $name_format_rs = $schema->resultset("Project::Projectprop")->find ({
        project_id =>  $project_id,
        type_id => $name_format_cvterm_id
    });

    if($name_format_rs) {
        $format = $name_format_rs->value;
    }

    return $format;

}


sub get_default_plant_material {
    my $self = shift;
    my $schema = $self->schema();
    my $project_id = $self->project_id();
    my @default_plant_material = ();

    my $default_plant_material_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'default_plant_material', 'project_property')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $default_plant_material_rs = $schema->resultset("Project::Projectprop")->find ({
        project_id =>  $project_id,
        type_id => $default_plant_material_cvterm_id
    });

    if($default_plant_material_rs) {
        my $default_plant_material_id = $default_plant_material_rs->value;
        my $plant_material_name = $schema->resultset("Stock::Stock")->find ({ stock_id =>  $default_plant_material_id, type_id => $accession_cvterm_id })->uniquename();
        push @default_plant_material, ($default_plant_material_id, $plant_material_name);
    }

    return \@default_plant_material;

}


sub delete {
    my $self = shift;
    my $schema = $self->schema();
    my $dbh = $self->schema()->storage()->dbh();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $tracking_identifier = $self->tracking_identifier();
    my $transformants = $self->transformants();
    my $number_of_transformants = scalar(@$transformants);
    my $obsoleted_transformants = $self->obsoleted_transformants();
    my $number_of_obsoleted_transformants = scalar(@$obsoleted_transformants);

    eval {
        $dbh->begin_work();

        my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
        my $tracking_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "tracking_identifier", "stock_type")->cvterm_id();
        my $transformation_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_experiment', 'experiment_type')->cvterm_id();
        my $tracking_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id();

        if (($number_of_transformants > 0) || ($number_of_obsoleted_transformants > 0)) {
	        die "Transformation ID has associated transformants. Cannot delete.\n";
        }

        my $transformation_rs = $schema->resultset("Stock::Stock")->find ({stock_id => $transformation_stock_id, type_id => $transformation_type_id});
        if (!$transformation_rs) {
	        die "This stock id is not a transformation ID. Cannot delete.\n";
        }

        my $transformation_experiment_id;
        my $nd_q = "SELECT nd_experiment.nd_experiment_id FROM nd_experiment_stock
            JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
            WHERE nd_experiment.type_id = ? AND nd_experiment_stock.stock_id = ?";

        my $nd_h = $schema->storage->dbh()->prepare($nd_q);
        $nd_h->execute($transformation_experiment_type_id, $transformation_stock_id);
        my @nd_experiment_ids= $nd_h->fetchrow_array();
        if (scalar @nd_experiment_ids == 1) {
            $transformation_experiment_id = $nd_experiment_ids[0];
        } else {
            die "Error retrieving experiment id";
        }

        #delete the nd_experiment_md_files entries
        my $md_files_q = "DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id = ?";
        my $md_files_h = $schema->storage->dbh()->prepare($md_files_q);
        $md_files_h->execute($transformation_experiment_id);

	    # delete the nd_experiment entries
	    my $q2= "delete from nd_experiment where nd_experiment.nd_experiment_id = ? AND nd_experiment.type_id = ?";
	    my $h2 = $dbh->prepare($q2);
	    $h2->execute($transformation_experiment_id, $transformation_experiment_type_id);

	    # delete stock owner entries
	    #
	    my $q3 = "delete from phenome.stock_owner where stock_id=?";
	    my $h3 = $dbh->prepare($q3);
	    $h3->execute($transformation_stock_id);

	    # delete the stock entries
	    my $q4 = "delete from stock where stock.stock_id=? and stock.type_id = ?";
	    my $h4 = $dbh->prepare($q4);
	    $h4->execute($transformation_stock_id, $transformation_type_id);

        #if linking with tracking tool, delete tracking identifier entry
        if (scalar @$tracking_identifier > 0) {
            my $tracking_experiment_id;
            my $tracking_stock_id = $tracking_identifier->[0]->[0];
            my $tracking_nd_q = "SELECT nd_experiment.nd_experiment_id FROM nd_experiment_stock
                JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
                WHERE nd_experiment.type_id = ? AND nd_experiment_stock.stock_id = ?";

            my $tracking_nd_h = $schema->storage->dbh()->prepare($tracking_nd_q);
            $tracking_nd_h->execute($tracking_experiment_type_id, $tracking_stock_id);
            my @tracking_nd_experiment_ids= $tracking_nd_h->fetchrow_array();
            if (scalar @tracking_nd_experiment_ids == 1) {
                $tracking_experiment_id = $tracking_nd_experiment_ids[0];
            } else {
                die "Error retrieving experiment id";
            }

            # delete the tracking nd_experiment entries
    	    my $tracking_q2= "delete from nd_experiment where nd_experiment.nd_experiment_id = ? AND nd_experiment.type_id = ?";
    	    my $tracking_h2 = $dbh->prepare($tracking_q2);
    	    $tracking_h2->execute($tracking_experiment_id, $tracking_experiment_type_id);

    	    # delete tracking stock owner entries
    	    my $tracking_q3 = "delete from phenome.stock_owner where stock_id=?";
    	    my $tracking_h3 = $dbh->prepare($tracking_q3);
    	    $tracking_h3->execute($tracking_stock_id);

    	    # delete the tracking stock entries
    	    my $tracking_q4 = "delete from stock where stock.stock_id=? and stock.type_id = ?";
    	    my $tracking_h4 = $dbh->prepare($tracking_q4);
    	    $h4->execute($tracking_stock_id, $tracking_type_id);
        }
    };

    if ($@) {
	    print STDERR "An error occurred while deleting transformation id ".$transformation_stock_id."$@\n";
	    $dbh->rollback();
	    return $@;
    } else {
	    $dbh->commit();
	    return 0;
    }
}


sub set_transformation_control {
    my $self = shift;
    my $schema = $self->schema();
    my $dbh = $self->schema()->storage()->dbh();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $transformation_control_stock_id = $self->transformation_control_stock_id();

    eval {
        my $transformation_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation','stock_type')->cvterm_id();
        my $control_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'control_of','stock_relationship')->cvterm_id();
        my $transformation_rs = $schema->resultset("Stock::Stock")->find({stock_id => $transformation_stock_id, type_id => $transformation_cvterm_id });

        if ($transformation_control_stock_id) {
             $transformation_rs->find_or_create_related('stock_relationship_subjects', {
                type_id    => $control_of_cvterm_id,
                object_id  => $transformation_rs->stock_id(),
                subject_id => $transformation_control_stock_id,
            });
        }
    };

    if ($@) {
	    print STDERR "An error occurred while setting transformation control for stock id ".$transformation_stock_id."$@\n";
	    return $@;
    } else {
	    return 0;
    }

}


sub set_as_control {
    my $self = shift;
    my $schema = $self->schema();
    my $dbh = $self->schema()->storage()->dbh();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $is_a_control = $self->is_a_control();

    eval {
        my $transformation_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation','stock_type')->cvterm_id();
        my $is_a_transformation_control_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a_transformation_control', 'stock_property');
        my $transformation_rs = $schema->resultset("Stock::Stock")->find({stock_id => $transformation_stock_id, type_id => $transformation_cvterm_id });

        if ($transformation_rs && $is_a_control) {
            my $previous_stockprop_rs = $transformation_rs->stockprops({type_id=>$is_a_transformation_control_cvterm->cvterm_id});
            if ($previous_stockprop_rs) {
                die "This transformation ID has already been set as a control.\n";
            } else {
                $transformation_rs->create_stockprops({$is_a_transformation_control_cvterm->name() => $is_a_control});
            }
        }

    };

    if ($@) {
	    print STDERR "An error occurred while setting transformation as a control for stock id ".$transformation_stock_id."$@\n";
	    return $@;
    } else {
	    return 0;
    }

}




###
1;
###

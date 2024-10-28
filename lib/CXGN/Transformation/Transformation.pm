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

    my $q = "SELECT transformation.stock_id, transformation.uniquename, plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS transformation ON (nd_experiment_stock.stock_id = transformation.stock_id) AND transformation.type_id = ?
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformation.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stockprop AS stockprop2 ON (stockprop2.stock_id = transformation.stock_id) AND stockprop2.type_id in (?, ?)
        WHERE nd_experiment_project.project_id = ? AND stockprop2.value IS NULL";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformation_type_id, $plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $project_id);

    my @transformations = ();
    while (my ($transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes) = $h->fetchrow_array()){
        push @transformations, [$transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes]
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

    my $q = "SELECT transformation.stock_id, transformation.uniquename, plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value, cvterm.name
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS transformation ON (nd_experiment_stock.stock_id = transformation.stock_id) AND transformation.type_id = ?
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformation.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        JOIN stockprop AS stockprop2 ON (stockprop2.stock_id = transformation.stock_id) AND stockprop2.type_id in (?, ?)
        JOIN cvterm ON (stockprop2.type_id = cvterm.cvterm_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformation_type_id, $plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $project_id);

    my @transformations = ();
    while (my ($transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes, $status_type) = $h->fetchrow_array()){
        push @transformations, [$transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes, $status_type]
    }

    return \@transformations;
}


sub get_transformants {
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

    return \@transformants;
}


sub get_obsoleted_transformants {
    my $self = shift;
    my $schema = $self->schema();
    my $transformation_stock_id = $self->transformation_stock_id();
    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $transformant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM stock_relationship
        JOIN stock ON (stock_relationship.subject_id = stock.stock_id) and stock_relationship.type_id = ?
        where stock_relationship.object_id = ? AND stock.is_obsolete != 'F' ";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformant_of_type_id, $transformation_stock_id);

    my @obsoleted_transformants = ();
    while (my ($stock_id,  $stock_name) = $h->fetchrow_array()){
        push @obsoleted_transformants, [$stock_id,  $stock_name]
    }

    return \@obsoleted_transformants;
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

    my $q = "SELECT plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value, cvterm.name
        FROM stock AS transformation
        JOIN stock_relationship AS plant_relationship ON (transformation.stock_id = plant_relationship.object_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stockprop AS stockprop2 ON (stockprop2.stock_id = transformation.stock_id) AND stockprop2.type_id in (?, ?)
        LEFT JOIN cvterm ON (stockprop2.type_id = cvterm.cvterm_id)
        WHERE transformation.stock_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $transformation_stock_id);

    my @transformation_info = ();
    while (my ($plant_id, $plant_name, $vector_id, $vector_name, $notes, $updated_status) = $h->fetchrow_array()){
        push @transformation_info, [$plant_id, $plant_name, $vector_id, $vector_name, $notes, $updated_status]
    }
    print STDERR "TRANSFORMATION INFO =".Dumper(\@transformation_info)."\n";
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


sub get_tracking_identifier {
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

    my @tracking_identifiers = ();
    while (my ($stock_id,  $stock_name) = $h->fetchrow_array()){
        push @tracking_identifiers, [$stock_id,  $stock_name]
    }

    return \@tracking_identifiers;
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


###
1;
###

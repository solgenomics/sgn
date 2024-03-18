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


sub get_transformations_in_project {
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

    my $q = "SELECT transformation.stock_id, transformation.uniquename, plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS transformation ON (nd_experiment_stock.stock_id = transformation.stock_id) AND transformation.type_id = ?
        JOIN stock_relationship AS plant_relationship ON (plant_relationship.object_id = transformation.stock_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformation_type_id, $plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $project_id);

    my @transformations = ();
    while (my ($transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes) = $h->fetchrow_array()){
        push @transformations, [$transformation_id,  $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name, $notes]
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
        where stock_relationship.object_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($transformant_of_type_id, $transformation_stock_id);

    my @transformants = ();
    while (my ($stock_id,  $stock_name) = $h->fetchrow_array()){
        push @transformants, [$stock_id,  $stock_name]
    }

    return \@transformants;
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

    my $q = "SELECT plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, stockprop.value
        FROM stock AS transformation
        JOIN stock_relationship AS plant_relationship ON (transformation.stock_id = plant_relationship.object_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (vector_relationship.object_id = transformation.stock_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stockprop ON (stockprop.stock_id = transformation.stock_id) AND stockprop.type_id = ?
        WHERE transformation.stock_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($plant_material_of_type_id, $accession_type_id, $vector_construct_of_type_id, $vector_construct_type_id, $transformation_notes_type_id, $transformation_stock_id);

    my @transformation_info = ();
    while (my ($plant_id, $plant_name, $vector_id, $vector_name, $notes) = $h->fetchrow_array()){
        push @transformation_info, [$plant_id, $plant_name, $vector_id, $vector_name, $notes]
    }

    return \@transformation_info;

}


###
1;
###

=head1 NAME

CXGN::Transformation::Transformant - an object representing transformant info in the database

=head1 DESCRIPTION

=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::Transformation::Transformant;

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

has 'transformant_stock_id' => (
    isa => "Int",
    is => 'rw',
);

sub get_transformant_experiment_info {
    my $self = shift;
    my $schema = $self->schema();
    my $transformant_stock_id = $self->transformant_stock_id();

    my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $transformant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformant_of", "stock_relationship")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my $q = "SELECT plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, transformation.stock_id, transformation.uniquename
        FROM stock AS transformant
        JOIN stock_relationship AS plant_relationship ON (transformant.stock_id = plant_relationship.object_id) AND plant_relationship.type_id = ?
        JOIN stock AS plant ON (plant_relationship.subject_id = plant.stock_id) AND plant.type_id = ?
        JOIN stock_relationship AS vector_relationship ON (transformant.stock_id = vector_relationship.object_id) AND vector_relationship.type_id = ?
        JOIN stock AS vector ON (vector_relationship.subject_id = vector.stock_id) AND vector.type_id = ?
        LEFT JOIN stock_relationship AS transformation_relationship ON (transformation_relationship.subject_id = transformant.stock_id) AND transformation_relationship.type_id = ?
        LEFT JOIN stock AS transformation ON (transformation_relationship.object_id = transformation.stock_id) AND transformation.type_id = ?
        WHERE transformant.stock_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $vector_construct_type_id, $transformant_of_type_id, $transformation_type_id, $transformant_stock_id);

    my @transformation_info = ();
    while (my ($plant_id, $plant_name, $vector_id, $vector_name, $transformation_id, $transformation_name) = $h->fetchrow_array()){
        push @transformation_info, [$plant_id, $plant_name, $vector_id, $vector_name, $transformation_id, $transformation_name]
    }

    return \@transformation_info;

}


###
1;
###

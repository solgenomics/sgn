=head1 NAME

CXGN::Stock::CompileCatalogItems

=head1 DESCRIPTION


=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::Stock::CompileCatalogItems;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'catalog_stock_type' => (
    isa => "Str",
    is => 'rw',
);

has 'catalog_stock_property' => (
    isa => "Str",
    is => 'rw',
);

has 'catalog_stock_property_value' => (
    isa => "Str",
    is => 'rw',
);


sub compile_catalog_items_based_on_type {
    my $self = shift;
    my $schema = $self->schema();
    my $catalog_stock_type = $self->catalog_stock_type();
    my $catalog_stock_property = $self->catalog_stock_property();
    my $catalog_stock_property_value = $self->catalog_stock_property_value();
    my @catalog_items = ();

    if (($catalog_stock_type eq 'accession') && ($catalog_stock_property eq 'transgenic') && ($catalog_stock_property_value eq '1')) {

        my $stock_property_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, $catalog_stock_property, 'stock_property')->cvterm_id;
        my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
        my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'male_parent', 'stock_relationship')->cvterm_id();
        my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
        my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'female_parent', 'stock_relationship')->cvterm_id();

        my $q = "SELECT transformant.stock_id, transformant.uniquename, plant.stock_id, plant.uniquename, vector.stock_id, vector.uniquename, organism.species
            FROM stock AS transformant
            JOIN stockprop ON (transformant.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
            JOIN stock_relationship AS plant_relationship ON (transformant.stock_id = plant_relationship.object_id) AND plant_relationship.type_id = ?
            JOIN stock AS plant ON (plant.stock_id = plant_relationship.subject_id) AND plant.type_id = ?
            JOIN stock_relationship AS vector_relationship ON (transformant.stock_id = vector_relationship.object_id) AND vector_relationship.type_id = ?
            JOIN stock AS vector ON (vector.stock_id = vector_relationship.subject_id) AND vector.type_id = ?
            JOIN organism ON (transformant.organism_id = organism.organism_id)
            WHERE transformant.type_id = ? AND stockprop.value = ? AND transformant.is_obsolete = 'F' ";

        my $h = $schema->storage->dbh()->prepare($q);

        $h->execute($stock_property_type_id, $female_parent_type_id, $accession_type_id, $male_parent_type_id, $vector_construct_type_id, $accession_type_id, $catalog_stock_property_value);

        while (my ($transformant_id,  $transformant_name, $plant_id, $plant_name, $vector_id, $vector_name, $species) = $h->fetchrow_array()){
            push @catalog_items, [$transformant_id,  $transformant_name, $plant_id, $plant_name, $vector_id, $vector_name, $species];
        }

    }

    return \@catalog_items;
}


sub compile_specified_catalog_items {
    my $self = shift;
    my $schema = $self->schema();
    my @catalog_items = ();

    my $catalog_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'catalog', 'stock_property')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, organism.species
        FROM stock
        JOIN stockprop ON (stockprop.stock_id = stock.stock_id)
        JOIN organism ON (stock.organism_id = organism.organism_id)
        WHERE stockprop.type_id = ? AND stock.is_obsolete = 'F'";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($catalog_type_id);
    while (my ($stock_id,  $stock_name, $species) = $h->fetchrow_array()){
        push @catalog_items, [$stock_id,  $stock_name, $species];
    }

    return \@catalog_items;
}



###
1;
###

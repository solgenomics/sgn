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


sub compile_catalog_items {
    my $self = shift;
    my $schema = $self->schema();
    my $catalog_stock_type = $self->catalog_stock_type();
    my $catalog_stock_property = $self->catalog_stock_property();
    my $catalog_stock_property_value = $self->catalog_stock_value();
    my @catalog_items = ();

    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $catalog_stock_type, "stock_type")->cvterm_id();
    my $stock_property_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, $catalog_stock_property, 'stock_property')->cvterm_id;

    my $q = "SELECT stock.stock_id, stock.uniquename
        FROM stock
        JOIN stockprop ON (stock.stock_id = stockprop.stock_id) AND stockprop.type_id = ? and stockprop.value = ?
        WHERE stock.type_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($stock_property_type_id, $catalog_stock_property_value, $stock_type_id);

    while (my ($stock_id,  $stock_name) = $h->fetchrow_array()){
        push @catalog_items, [$stock_id,  $stock_name]
    }

    return \@catalog_items;
}


###
1;
###

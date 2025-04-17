package CXGN::Stock::ObsoletedStocks;

use strict;
use warnings;
use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'obsoleted_stock_list' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
);

has 'obsoleted_stock_ids' => (
    isa => 'ArrayRef[Int]',
    is => 'ro',
);


sub get_obsolete_metadata {
    my $self = shift;
    my $obsoleted_stock_ids = $self->obsoleted_stock_ids();
    my $schema = $self->bcs_schema();

    my $stock_list_query = join ("," , @$obsoleted_stock_ids);

    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name, metadata.md_metadata.obsolete_note, metadata.md_metadata.modification_note, phenome.stock_owner.sp_person_id
        FROM stock
        JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
        JOIN phenome.stock_owner ON (stock.stock_id = phenome.stock_owner.stock_id)
        JOIN metadata.md_metadata ON (phenome.stock_owner.metadata_id = metadata.md_metadata.metadata_id)
        where stock.stock_id IN ($stock_list_query) AND stock.is_obsolete = 't' ORDER BY stock.uniquename";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute();

    my @obsoleted_stocks = ();
    while (my ($stock_id,  $stock_name, $stock_type, $obsolete_note, $obsolete_date, $sp_person_id) = $h->fetchrow_array()){
        push @obsoleted_stocks, [$stock_id, $stock_name, $stock_type, $obsolete_note, $obsolete_date, $sp_person_id]
    }

    return \@obsoleted_stocks;

}


1;

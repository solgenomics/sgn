
package CXGN::Stock::RelatedStocks;

use strict;
use warnings;
use Moose;
use SGN::Model::Cvterm;

has 'dbic_schema' => (isa => 'Bio::Chado::Schema',
        is => 'rw',
        required => 1,
);

has 'stock_id' => (isa => 'Str',
        is => 'rw',
        required => 1,
);


sub get_trial_related_stock {
    my $self = shift;
    my $ stock_id = $self->stock_id;
    my $ schema = $self->dbic_schema();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $subplot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of_subplot', 'stock_relationship')->cvterm_id();
    my $seed_transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seed transaction', 'stock_relationship')->cvterm_id();
    my $tissue_sample_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship
            INNER JOIN stock ON (stock_relationship.subject_id = stock.stock_id)
            INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
            WHERE stock_relationship.object_id = ? AND (stock_relationship.type_id = ?
            OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ?)

            UNION ALL

            SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship
            INNER JOIN stock ON (stock_relationship.object_id = stock.stock_id)
            INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
            WHERE stock_relationship.subject_id = ? AND (stock_relationship.type_id = ?
            OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ? OR stock_relationship.type_id = ?) ";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($stock_id, $plot_of_type_id, $plant_of_type_id, $subplot_of_type_id, $plant_of_subplot_type_id, $seed_transaction_type_id, $tissue_sample_of_type_id, $stock_id, $plot_of_type_id, $plant_of_type_id, $subplot_of_type_id, $plant_of_subplot_type_id, $seed_transaction_type_id, $tissue_sample_of_type_id);

    my @trial_related_stock =();
    while(my($stock_id, $stock_name, $cvterm_name) = $h->fetchrow_array()){

      push @trial_related_stock, [$stock_id, $stock_name, $cvterm_name]
    }

    return\@trial_related_stock;
}


sub get_progenies {
    my $self = shift;
    my $stock_id = $self->stock_id;
    my $ schema = $self->dbic_schema();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $q = "SELECT cvterm.name, stock.stock_id, stock.uniquename FROM stock_relationship
             INNER JOIN stock ON (stock_relationship.object_id = stock.stock_id)
             INNER JOIN cvterm ON (stock_relationship.type_id =cvterm.cvterm_id)
             WHERE stock_relationship.subject_id = ? AND(stock_relationship.type_id =?
             OR stock_relationship.type_id = ?) AND stock.type_id = ? ORDER BY cvterm.name DESC, stock.uniquename ASC";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($stock_id, $female_parent_type_id, $male_parent_type_id, $accession_type_id);

    my @progenies =();
        while(my($cvterm_name, $stock_id, $stock_name) = $h->fetchrow_array()){
        push @progenies, [$cvterm_name, $stock_id, $stock_name]
        }

        return\@progenies;

}


sub get_group_and_member {
    my $self = shift;
    my $ stock_id = $self->stock_id;
    my $ schema = $self->dbic_schema();
    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.object_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.subject_id = ? and stock_relationship.type_id = ?

             UNION ALL

             SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.subject_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.object_id = ? and stock_relationship.type_id = ?

             ";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($stock_id, $member_of_type_id, $stock_id, $member_of_type_id);

    my @group =();
        while(my($stock_id, $stock_name, $cvterm_name) = $h->fetchrow_array()){
        push @group, [$stock_id, $stock_name, $cvterm_name]
        }

        return\@group;

}


sub get_stock_for_tissue {
    my $self = shift;
    my $ stock_id = $self->stock_id;
    my $ schema = $self->dbic_schema();
    my $tissue_sample_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    my $q = "SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.object_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.subject_id = ? and stock_relationship.type_id = ?

             UNION ALL

             SELECT stock.stock_id, stock.uniquename, cvterm.name FROM stock_relationship INNER JOIN stock
             ON (stock_relationship.subject_id = stock.stock_id) INNER JOIN cvterm ON (stock.type_id = cvterm.cvterm_id)
             WHERE stock_relationship.object_id = ? and stock_relationship.type_id = ?

             ";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($stock_id, $tissue_sample_of_type_id, $stock_id, $tissue_sample_of_type_id);

    my @tissue_stocks =();
        while(my($stock_id, $stock_name, $cvterm_name) = $h->fetchrow_array()){
        push @tissue_stocks, [$stock_id, $stock_name, $cvterm_name]
        }

        return\@tissue_stocks;

}



1;

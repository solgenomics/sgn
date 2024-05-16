
package CXGN::Population;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

extends 'CXGN::Stock';

has 'population_stock_id' => (isa => "Maybe[Int]",
    is => 'rw',
);

has 'population_name' => (isa => 'Maybe[Str]',
    is => 'rw',
);

has 'accession_members' => (isa => 'ArrayRef',
    is => 'rw',
);


sub BUILD {
    my $self = shift;
    my $args = shift;

    my $schema = $args->{schema};
    my $population_id = $args->{population_stock_id};

    $self->stock_id($population_id);

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();

    my $row = $schema->resultset("Stock::Stock")->find( { stock_id => $population_id, type_id => $population_cvterm_id });

    if ($row) {
        my $name = $row->uniquename();
        $self->population_name($name);
        $self->population_stock_id($population_id);

    }

    my $accession_members = $self->get_accession_members();
    print STDERR Dumper($accession_members);

    if ($accession_members) {
        $self->accession_members($accession_members);
    }
}


sub get_accession_members {
    my $self = shift;
    my $schema = $self->schema;
    my $population_id = $self->population_stock_id;

    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

    my $q = "SELECT member.stock_id, member.uniquename
        FROM stock
        JOIN stock_relationship ON (stock_relationship.object_id = stock.stock_id) AND stock_relationship.type_id = ?
        JOIN stock AS member ON (stock_relationship.subject_id = member.stock_id) AND member.type_id = ?
        WHERE stock.stock_id = ?";

     my $h = $schema->storage->dbh()->prepare($q);
     $h->execute($member_of_type_id, $accession_type_id, $population_id);
     my @accession_members = ();
     while (my ($stock_id, $stock_name) = $h->fetchrow_array()){
         push @membership_info, [$stock_id, $stock_name]
     }

     return \@accession_members;
}



1;

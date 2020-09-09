=head1 NAME

CXGN::FamilyName - an object representing a family name in the database

=head1 DESCRIPTION

    my $family_name = CXGN::FamilyName->new( { schema => $schema, family_id => xxxxx });


=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::FamilyName;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

extends 'CXGN::Stock';

has 'family_stock_id' => (isa => "Maybe[Int]",
    is => 'rw',
    required => 0,
);

has 'family_name' => (isa => 'Maybe[Str]',
    is => 'rw',
);


sub BUILD {

    my $self = shift;
    my $args = shift;

    my $schema = $args->{schema};
    my $family_id = $args->{family_stock_id};

    $self->stock_id($family_id);

    my $family_rs = $schema->resultset("Stock::Stock")->find( { stock_id => $family_id });

    if ($family_rs) {
        my $family_uniquename = $family_rs->uniquename();
     	 $self->family_name($family_uniquename);
     	 $self->family_stock_id($family_id);
    }

}


sub get_family_parents {
    my $self = shift;
    my $schema = $self->schema();
    my $family_stock_id = $self->family_stock_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();
    my $family_female_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_female_parent_of", "stock_relationship")->cvterm_id();
    my $family_male_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_male_parent_of", "stock_relationship")->cvterm_id();

    my $family_female;
    my $family_male;

    my $q = "SELECT female_parent.stock_id, female_parent.uniquename, cvterm1.name, male_parent.stock_id, male_parent.uniquename, cvterm2.name
        FROM stock AS female_parent
        JOIN cvterm AS cvterm1 ON (female_parent.type_id = cvterm1.cvterm_id)
        JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id = stock_relationship1.subject_id) and stock_relationship1.type_id = ?
        LEFT JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id = stock_relationship2.object_id) and stock_relationship2.type_id = ?
        LEFT JOIN stock as male_parent ON (male_parent.stock_id = stock_relationship2.subject_id)
        LEFT JOIN cvterm AS cvterm2 ON (male_parent.type_id = cvterm2.cvterm_id)
        WHERE stock_relationship1.object_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($family_female_type_id, $family_male_type_id, $family_stock_id);

    my @family_parents = ();
    while (my ($female_parent_id,  $female_parent_name, $female_stock_type, $male_parent_id, $male_parent_name, $male_stock_type) = $h->fetchrow_array()){
        push @family_parents, [$female_parent_id,  $female_parent_name, $female_stock_type, $male_parent_id, $male_parent_name, $male_stock_type]
    }
    print STDERR Dumper(\@family_parents);
    return \@family_parents;

}


1;

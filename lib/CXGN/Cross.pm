
package CXGN::Cross;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'cross_stock_id' => (isa => "Int",
	is => 'rw',
	required => 0,
);

has 'female_parent' => (isa => 'Str',
  is => 'rw',
	required => 0,
);

has 'male_parent' => (isa => 'Str',
  is => 'rw',
	required => 0,
);



sub get_cross_relationships {
	my $self = shift;
	my $crs = $self->bcs_schema->resultset("Stock::StockRelationship")->search( { object_id => $self->cross_stock_id } );

	my $maternal_parent = "";
	my $paternal_parent = "";
	my @progeny = ();

	foreach my $child ($crs->all()) {
		if ($child->type->name() eq "female_parent") {
			$maternal_parent = [ $child->subject->name, $child->subject->stock_id() ];
		}
		if ($child->type->name() eq "male_parent") {
			$paternal_parent = [ $child->subject->name, $child->subject->stock_id() ];
		}
		if ($child->type->name() eq "member_of") {
			push @progeny, [ $child->subject->name, $child->subject->stock_id() ];
		}
	}
	return ($maternal_parent, $paternal_parent, \@progeny);
}


sub get_cross_info {
    my $self = shift;
		my $female_parent = $self->female_parent;
		my $male_parent = $self->male_parent;
		my $schema = $self->bcs_schema();
    my $male_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

		my $where = "";
		if ($male_parent){
			$where = " AND male_parent.uniquename = '$male_parent'";
		}

    my $q = "SELECT female_parent.stock_id, male_parent.stock_id, cross_entry.stock_id, female_parent.uniquename, male_parent.uniquename, cross_entry.uniquename, stock_relationship1.value
    FROM stock as female_parent INNER JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id=stock_relationship1.subject_id)
    AND stock_relationship1.type_id= ? INNER JOIN stock_relationship AS stock_relationship2
    ON (stock_relationship1.object_id=stock_relationship2.object_id) INNER JOIN stock AS male_parent
    ON (male_parent.stock_id=stock_relationship2.subject_id) AND stock_relationship2.type_id= ?
    INNER JOIN stock AS cross_entry ON (cross_entry.stock_id=stock_relationship2.object_id) AND cross_entry.type_id= ?
    WHERE female_parent.uniquename = ? $where ORDER BY stock_relationship1.value, male_parent.uniquename ASC";

		my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($female_parent_typeid, $male_parent_typeid, $cross_typeid, $female_parent);

		my @cross_info = ();
    while (my ($female_parent_id, $male_parent_id, $cross_entry_id, $female_parent_name, $male_parent_name, $cross_name, $cross_type) = $h->fetchrow_array()){
			push @cross_info, [$female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_entry_id, $cross_name, $cross_type]
		}

		return \@cross_info;

}


1;

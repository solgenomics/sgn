
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
	required => 1,
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

1;

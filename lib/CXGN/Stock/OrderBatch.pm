
package CXGN::Stock::OrderBatch;

use Moose;

extends 'CXGN::JSONProp';

has 'clone_list' => (is => 'rw', isa => 'ArrayRef[HashRef]' );

has 'type' => ( is => 'rw', isa => 'Str' );

has 'requested_delivery_date' => (is => 'rw', isa => 'Str');

has 'delivery_date' => ( is => 'rw', isa => 'Str');

has 'history' => ( is => 'rw', isa => 'ArrayRef[HashRef]' );



sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('sp_orderprop');
    $self->prop_namespace('CXGN::People::Schema::Result::SpOrderprop');
    $self->prop_primary_key('orderprop_id');
    $self->prop_type('order_batch_json');
    $self->cv_name('stock_property');
#    $self->allowed_fields( [ qw | order_from_person_id order_to_person_id order_status comments | ] );
    $self->allowed_fields( [ qw | clone_list | ] );
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}


# class functions
#

# sub get_orders_by_person_id {
#     my $class = shift;
#     my $bcs_schema = shift;
#     my $person_id = shift;

#     my $dbh = $bcs_schema->storage->dbh();

#     my $q = "SELECT stockprop_id FROM stockprop where value similar to 'order_by_person_id => ?,'";
#     my $h = $dbh ->prepare($q);

#     $h->execute($person_id);

#     my %persons;

#     my @orders;
#     while (my ($stockprop_id) = $h->fetchrow_array()) {
# 	my $order = CXGN::Stock::StockOrder->new( { $bcs_schema => $bcs_schema, prop_id => $stockprop_id });

# 	if (!$persons{$order->order_from_person_id()}) {
# 	    my $p = CXGN::People::Person->new( $dbh, $order->order_from_person_id() );
# 	    $persons{$order->order_from_person_id()} = $p->first_name." ".$p->last_name();
# 	}

# 	if (!$persons{$order->order_to_person_id()}) {
# 	    my $p = CXGN::People::Person->new( $dbh, $order->order_to_person_id() );
# 	    $persons{$order->order_to_person_id()} = $p->first_name." ".$p->last_name();
# 	}

# 	my $stock = CXGN::Stock->new( { schema => $bcs_schema, stock_id => $order->parent_id() });

# 	push @orders, [ $persons{$order->order_from_person_id()}, $persons{$order->order_to_person_id()}, $stock->uniquename(), $stock->order_status(), $stock->comments() ];
#     }


#     return \@orders;
# }

1;

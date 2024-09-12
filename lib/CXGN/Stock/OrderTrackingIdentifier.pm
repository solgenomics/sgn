
package CXGN::Stock::OrderTrackingIdentifier;

use Moose;

extends 'CXGN::JSONProp';

has 'tracking_identifiers' => ( is => 'rw', isa => 'ArrayRef' );


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('sp_orderprop');
    $self->prop_namespace('SpOrderprop');
    $self->prop_primary_key('sp_orderprop_id');
    $self->prop_type('order_tracking_identifiers');
    $self->cv_name('sp_order_property');
    $self->allowed_fields( [ qw | tracking_identifiers| ] );
    $self->parent_table('sp_order');
    $self->parent_primary_key('sp_order_id');

    $self->load();
}


1;

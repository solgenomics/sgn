package CXGN::Stock::OrderStatusDetails;

use Moose;

extends 'CXGN::JSONProp';

has 'order_status_details' => (is => 'rw', isa => 'HashRef');

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('sp_orderprop');
    $self->prop_namespace('SpOrderprop');
    $self->prop_primary_key('sp_orderprop_id');
    $self->prop_type('order_progress_json');
    $self->cv_name('sp_order_property');
    $self->allowed_fields( [ qw | order_status_details | ] );
    $self->parent_table('sp_order');
    $self->parent_primary_key('sp_order_id');

    $self->load();
}


1;

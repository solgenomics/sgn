
package CXGN::Stock::OrderBatch;

use Moose;

extends 'CXGN::JSONProp';

has 'clone_list' => (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'requested_delivery_date' => (is => 'rw', isa => 'Str');

has 'delivery_date' => ( is => 'rw', isa => 'Str');

has 'history' => ( is => 'rw', isa => 'ArrayRef[HashRef]' );

has 'tracking_identifier_list' => ( is => 'rw', isa => 'ArrayRef' );


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('sp_orderprop');
#    $self->prop_namespace('CXGN::People::Schema::Result::SpOrderprop');
    $self->prop_namespace('SpOrderprop');
    $self->prop_primary_key('sp_orderprop_id');
    $self->prop_type('order_batch_json');
    $self->cv_name('sp_order_property');
    $self->allowed_fields( [ qw | clone_list history tracking_identifier_list| ] );
    $self->parent_table('sp_order');
    $self->parent_primary_key('sp_order_id');

    $self->load();
}


1;

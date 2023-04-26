
package CXGN::List::ListProp;

use Moose;

extends 'CXGN::JSONProp';

has 'clone_list' => (is => 'rw', isa => 'ArrayRef[HashRef]');

has 'type' => ( is => 'rw', isa => 'Str' );

has 'requested_delivery_date' => (is => 'rw', isa => 'Str');

has 'delivery_date' => ( is => 'rw', isa => 'Str');

has 'history' => ( is => 'rw', isa => 'ArrayRef[HashRef]' );


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('listprop');
#    $self->prop_namespace('CXGN::People::Schema::Result::SpOrderprop');
    $self->prop_namespace('ListProp');
    $self->prop_primary_key('listprop_id');
    $self->prop_type('order_batch_json');
    $self->cv_name('sp_order_property');
    $self->allowed_fields( [ qw | clone_list history | ] );
    $self->parent_table('sp_order');
    $self->parent_primary_key('sp_order_id');

    $self->load();
}


1;

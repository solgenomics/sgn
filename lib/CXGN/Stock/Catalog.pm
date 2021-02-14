
package CXGN::Stock::Catalog;

use Moose;

extends 'CXGN::JSONProp';

has 'description' => ( isa => 'Str', is => 'rw' );

has 'images' => ( isa => 'Maybe[ArrayRef]', is => 'rw' );

has 'availability' => ( isa => 'Str', is => 'rw' );

has 'comments' => ( isa => 'Str', is => 'rw') ;


sub BUILD {
    my $self = shift;
    my $args = shift;
    
    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('stock_order_json');
    $self->cv_name('stock_property');
    $self->allowed_fields( [ qw | description images availability comments | ] );
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');
    
    $self->load();
}

1;

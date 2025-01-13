package CXGN::TrackingActivity::IdentifierMetadata;

use Moose;
use Data::Dumper;

extends 'CXGN::JSONProp';

has 'data_type' => ( isa => 'Str', is => 'rw' );

has 'data_level' => ( isa => 'Str', is => 'rw' );

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('identifier_metadata');
    $self->cv_name('stock_property');
    $self->allowed_fields( [ qw | data_type data_level | ] );
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}


1;

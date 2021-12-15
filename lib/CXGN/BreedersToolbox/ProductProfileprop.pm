package CXGN::BreedersToolbox::ProductProfileprop;

use Moose;

extends 'CXGN::JSONProp';

has 'product_profile_details' => (isa => 'Str', is => 'rw');

has 'history' => ( is => 'rw', isa => 'ArrayRef[HashRef]' );


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('sp_product_profileprop');
    $self->prop_namespace('SpProductProfileprop');
    $self->prop_primary_key('sp_product_profileprop_id');
    $self->prop_type('product_profile_json');
    $self->cv_name('sp_product_profile_property');
    $self->allowed_fields( [ qw | product_profile_details history | ] );
    $self->parent_table('sp_product_profile');
    $self->parent_primary_key('sp_product_profile_id');

    $self->load();
}


1;

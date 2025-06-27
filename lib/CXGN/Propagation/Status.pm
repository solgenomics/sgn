package CXGN::Propagation::Status;


=head1 NAME

CXGN::Propagation::Status - a class to manage propagation status

=head1 DESCRIPTION

The stock_property of type "propagation_status" is stored as JSON.

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;


has 'propagation_stock_id' => (isa => 'Int', is => 'rw');

has 'status_type' => (isa => 'Str', is => 'rw');

has 'update_person' => (isa => 'Str', is => 'rw');

has 'update_date' => (isa => 'Str', is => 'rw');

has 'update_notes' => (isa => 'Str', is => 'rw');

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('propagation_status');
    $self->cv_name('stock_property');
    $self->allowed_fields( [ qw | status_type update_person update_date update_notes | ] );
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}





1;

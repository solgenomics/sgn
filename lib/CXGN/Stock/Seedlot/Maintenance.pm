package CXGN::Stock::Seedlot::Maintenance;

=head1 NAME

CXGN::Stock::Seedlot::Maintenance - a class to manage Seedlot Maintenance Events

=head1 DESCRIPTION

This class is used to store and retrieve maintenance actions and/or observations performed 
for the proper maintenance of a particular Seedlot.

Seedlot maintenance events are stored as JSON stock props, where each maintanence event 
has an associated cvterm_id of a cvterm from a 'seedlot maintenance' ontology.  This 
ontology defines that types of maintenance events that can be associated with a Seedlot.

=head1 USAGE

Seedlot Maintenance Events are associated directly with existing Seedlots and are linked to 
cvterms (by cvterm_id) of terms in a loaded seedlot maintenance event ontology.  The root of 
this ontology must be specified in the sgn_local.conf using the `seedlot_maintenance_event_ontology_root`
term.

The CXGN::Stock::Seedlot Class has helper functions for storing and retrieving Seedlot Maintenance Events.

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

has 'cvterm_id' => (isa => 'Int', is => 'rw');
has 'cvterm_name' => (isa => 'Str', is => 'rw');
has 'value' => (isa => 'Str|Num', is => 'rw');
has 'notes' => (isa => 'Maybe[Str]', is => 'rw');
has 'operator' => (isa => 'Str', is => 'rw');
has 'timestamp' => (isa => 'Str', is => 'rw');

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('propjectprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('seedlot_maintenance_json');
    $self->cv_name('stock_property');
    $self->allowed_fields([ qw | cvterm_id cvterm_name value notes operator timestamp | ]);
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}

1;

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

To add a maintenance event:
my %event = (
    cvterm_id => $cvterm_id, 
    value => $value,
    notes => $notes,
    operator => $operator   || $c->user()->get_object()->get_username(),
    timestamp => $timestamp || DateTime->now(time_zone => 'local')
);
my $event_obj = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema, parent_id => $seedlot_id });
my $processed_event = $event_obj->add(\$event);

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


use Moose;
use DateTime;

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


#
# Add a Seedlot Maintenance Event
# PARAMS:
#   - event: a hash of the event properties, with the following keys:
#       - cvterm_id: id of seedlot maintenance event ontology term
#       - value: value of the seedlot maintenance event
#       - notes: (optional) additional notes/comments about the event
#       - operator: username of the person creating the event
#       - timestamp: DateTime object of when the event was created
# RETURNS: a hash of the processed event (as stored in the database), with the following keys:
#   - stockprop_id: seedlot maintenance event id
#   - cvterm_id: id of seedlot maintenance event ontology term
#   - cvterm_name: name of seedlot maintenance event ontology term
#   - value: value of the seedlot maintenance event
#   - notes: additional notes/comments about the event
#   - operator: username of the person creating the event
#   - timestamp: parsed timestamp of when the event was created (YYYY-MM-DD HH:MM:SS z format)
#
sub add {
    my $self = shift;
    my $event = shift;
    my $schema = $self->bcs_schema();

    # Get event parameters
    my $cvterm_id = $event->{cvterm_id};
    my $value = $event->{value};
    my $notes = $event->{notes};
    my $operator = $event->{operator};
    my $timestamp = $event->{timestamp};

    # Check for required parameters
    if ( !defined $cvterm_id || $cvterm_id eq '' ) {
        die "cvterm_id is required!";
    }
    if ( !defined $value || $value eq '' ) {
        die "value is required!";
    }
    if ( !defined $operator || $operator eq '' ) {
        die "operator is required!";
    }
    if ( !defined $timestamp || $timestamp eq '' ) {
        die "timestamp is required!";
    }

    # Parse DateTime into string
    my $timestamp_str = $timestamp->strftime("%Y-%m-%d %H:%M:%S %z");

    # Find matching cvterm by id
    my $cvterm_rs = $schema->resultset("Cv::Cvterm")->search({ cvterm_id => $cvterm_id })->first();
    if ( !defined $cvterm_rs ) {
        die "cvterm_id [$cvterm_id] not found!";
    }
    my $cvterm_name = $cvterm_rs->name();

    # Set the event properties
    $self->cvterm_id($cvterm_id);
    $self->cvterm_name($cvterm_name);
    $self->value($value);
    $self->notes($notes);
    $self->operator($operator);
    $self->timestamp($timestamp_str);

    # Store the event
    my $stockprop_id = $self->store_by_rank();

    # Return the processed event
    my %e = (
        stockprop_id => $stockprop_id, 
        cvterm_id => $cvterm_id,
        cvterm_name => $cvterm_name,
        value => $value,
        notes => $notes,
        operator => $operator,
        timetamp => $timestamp
    );
    
    return(\%e);
}

1;

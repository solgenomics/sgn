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

    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('seedlot_maintenance_json');
    $self->cv_name('stock_property');
    $self->allowed_fields([ qw | cvterm_id cvterm_name value notes operator timestamp | ]);
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}



=head2 Class method: filter_events()

 Usage:         my $event_obj = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema });
                my @events = $event_obj->filter_events($filters);
 Desc:          get all of the (optionally filtered) seedlot maintenance events associated with any of the matching seedlots
 Args:          - filters (optional): a hash of different filter types to apply, with the following keys:
                    - events: an arrayref of event ids
                    - names: an arrayref of hashes containing name filter options:
                        - value: a string or array (for IN comp) of seedlot name query params 
                        - comp: the SQL comparison type (IN, LIKE)
                    - dates: an arrayref of hashes containing date filter options:
                        - date: date in YYYY-MM-DD format
                        - comp: comparison type (LIKE, <=, <, >, >=)
                    - types: an arrayref of hashes containing type/value filter options:
                        - cvterm_id: cvterm_id of maintenance event type
                        - values: (optional, default=any value) array of allowed values
                        - ignore: (optional, default=none) array of not allowed values
                    - operators: arrayref of operator names
                - page (optional): the page number of results to return
                - pageSize (optional): the number of results per page to return
 Ret:           a hashref with the results metadata and the matching seedlot events:
                    - page: current page number
                    - maxPage: the number of the last page
                    - pageSize: (max) number of results per page
                    - total: total number of results
                    - results: an arrayref of hashes of the seedlot's stored events, with the following keys:
                        - stock_id: the unique id of the seedlot
                        - uniquename: the unique name of the seedlot
                        - stockprop_id: the unique id of the maintenance event
                        - cvterm_id: id of seedlot maintenance event ontology term
                        - cvterm_name: name of seedlot maintenance event ontology term
                        - value: value of the seedlot maintenance event
                        - notes: additional notes/comments about the event
                        - operator: username of the person creating the event
                        - timestamp: timestamp string of when the event was created ('YYYY-MM-DD HH:MM:SS' format) 

=cut

sub filter_events {
    my $class = shift;
    my $filters = shift;
    my $page = shift;
    my $pageSize = shift;
    my $schema = $class->bcs_schema();

    # Parse filters into search conditions
    my @and;
    my @or;
    if ( defined $filters && defined $filters->{'events'} && scalar(@{$filters->{'events'}}) > 0 ) {
        push(@and, { 'me.stockprop_id' => $filters->{'events'} });
    }
    if ( defined $filters && defined $filters->{'names'} && scalar(@{$filters->{'names'}}) > 0 ) {
        foreach my $f (@{$filters->{'names'}}) {
            if ( $f->{value} && $f->{comp} ) {
                push(@and, { 'stock.uniquename' => { $f->{'comp'} => $f->{'value'} } });
            }
        }
    }
    if ( defined $filters && defined $filters->{'dates'} && scalar(@{$filters->{'dates'}}) > 0 ) {
        foreach my $f (@{$filters->{'dates'}}) {
            push(@and, { "value::json->>'timestamp'" => { $f->{'comp'} => $f->{'date'} } });
        }
    }
    if ( defined $filters && defined $filters->{'types'} && scalar(@{$filters->{'types'}}) > 0 ) {
        foreach my $f (@{$filters->{'types'}}) {
            if ( $f->{values} ) {
                my @c = (
                    { "value::json->>'cvterm_id'" => $f->{cvterm_id} },
                    { "value::json->>'value'" => $f->{values} }
                );
                push(@or, { "-and" => \@c });
            }
            elsif ( $f->{ignore} ) {
                my @c = (
                    { "value::json->>'cvterm_id'" => $f->{cvterm_id} },
                    { "value::json->>'value'" => { "!=" => $f->{ignore} } }
                );
                push(@or, { "-and" => \@c });
            }
            else {
                push(@or, { "value::json->>'cvterm_id'" => $f->{cvterm_id} });
            }
        }
    }
    if ( defined $filters && defined $filters->{'operators'} && scalar(@{$filters->{'operators'}}) > 0 ) {
        push(@and, { "value::json->>'operator'" => $filters->{'operators'} });
    }

    # Build conditions
    my %conditions = ();
    if ( scalar(@and) > 0 ) {
        $conditions{"-and"} = \@and;
    }
    if ( scalar(@or) > 0 ) {
        $conditions{"-or"} = \@or;
    }

    # Perform the filtering
    my $filtered_props = $class->filter_props({ 
        schema => $schema, 
        conditions => \%conditions, 
        parent_fields => ["uniquename"],
        order_by => { "-desc" => "value::json->>'timestamp'" },
        page => $page,
        pageSize => $pageSize
    });

    return $filtered_props;

}


=head2 Class method: overdue_events()

 Usage:         my $event_obj = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema });
                my @seedlots = $event_obj->overdue_events($seedlots, $event, $date);
 Desc:          return the seedlots (from the specified list) that have not had the specified event performed
                on or after the selected date
 Args:          - seedlots: an arrayref of seedlot names to check
                - event: cvterm_id of event that should have been performed
                - date: find seedlots that have not had the specified event performed after this date (YYYY-MM-DD format)
 Ret:           an arrayref with the status of each of the requested seedlots
                - seedlot: seedlot name
                - overdue: 1 if overdue, 0 if not
                - timestamp: the timestamp of the last time the event was performed, if not overdue

=cut

sub overdue_events {
    my $class = shift;
    my $seedlots = shift;
    my $event = shift;
    my $date = shift;
    my $schema = $class->bcs_schema();

    # Find Seedlots that are not overdue
    my %filters = (
        names => $seedlots,
        types => [ { cvterm_id => $event, ignore => 'Unsuccessful' } ],
        dates => [ { date => $date . "00:00:00", comp => '>=' } ] 
    );
    my $results = $class->filter_events(\%filters);

    # Get the timestamps of the not overdue seedlots
    my %not_overdue_seedlots;
    foreach my $s (@{$results->{'results'}}) {
        my $n = $s->{'uniquename'};
        my $t = $s->{'timestamp'};
        my $e = $not_overdue_seedlots{$n};
        if ( !$e || $t > $e ) {
            $not_overdue_seedlots{$n} = $t;
        }
    }

    # Get the status of each of the requested seedlots
    my @results = ();
    foreach my $n (@$seedlots) {
        my $t = $not_overdue_seedlots{$n};
        my $o = $t ? 0 : 1;
        push(@results, { seedlot => $n, overdue => $o, timestamp => $t });
    }

    # Sort so overdue seedlots are displayed first
    my @sorted = sort { $b->{overdue} <=> $a->{overdue} } @results;
    return \@sorted;
}

1;

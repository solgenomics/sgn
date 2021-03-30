
package CXGN::Stock::Order;

use Moose;

use CXGN::Stock::OrderBatch;

has 'people_schema' => ( isa => 'Ref', is => 'rw', required => 1 );

has 'sp_order_id' => (isa => 'Int', is => 'rw' );

has 'order_from_id' => ( isa => 'Int', is => 'rw' );

has 'order_to_id' => ( isa => 'Int', is => 'rw' );

has 'order_status' => ( isa => 'Str', is => 'rw' );

has 'comments' => ( isa => 'Str', is => 'rw');

has 'create_date' => ( isa => 'Str', is => 'rw');

has 'batches' => ( isa => 'Ref', is => 'rw', default => sub { return []; } );


sub BUILD {
    my $self = shift;
    my $args = shift;

    if (! $args->{sp_order_id}) {
	print STDERR "Creating empty object...\n";
	return $self;
    }

    my $row = $args->people_schema->resultset('SpOrder')->find( { sp_order_id => $args->{sp_order_id} } );

    if (!$row) {
	die "The database has no order entry with id $args->{sp_order_id}";
    }

    $self->order_from_id($row->order_from_id);
    $self->order_to_id($row->order_to_id);
    $self->order_status($row->order_status);
    $self->comments($row->comments);

    my $rs = $args->people_schema->resultset('SpOrderprop')->search( { sp_order_id => $args->{sp_order_id} });

    my @batches = ();
    while (my $r = $rs->next()) {
	my $batch = CXGN::Stock::OrderBatch->new( { people_schema => $args->{people_schema}, sp_orderprop_id => $row->sp_orderprop_id() });

	push @batches, $batch;
    }

    $self->batches(\@batches);
}


# class functions
#
sub get_orders_by_person_id {
    my $class = shift;
    my $people_schema = shift;
    my $person_id = shift;

    my $rs = $people_schema->resultset('SpOrder')->search( { order_by_person_id => $person_id } );

    my @orders;

    while (my $row = $rs->next()) {

	my $o = CXGN::Stock::Order->new( { sp_order_id => $row->sp_order_id() } );
	push @orders, $o;
    }

    return @orders;
}

sub get_orders_from_person_id {
    my $class = shift;
    my $people_schema = shift;
    my $person_id = shift;

    my $rs = $people_schema->resultset('SpOrder')->search( { order_to_person_id => $person_id } );

    my @orders;

    while (my $row = $rs->next()) {

	my $o = CXGN::Stock::Order->new( { sp_order_id => $row->sp_order_id() } );
	push @orders, $o;
    }

    return @orders;
}

# member functions
#
sub store {
    my $self = shift;

    my %data = (
	order_status => $self->order_status(),
	order_from_id => $self->order_from_id(),
	order_to_id => $self->order_to_id(),
	comments => $self->comments(),
	);

    if ($self->sp_order_id()) { $data{sp_order_id} = $self->sp_order_id(); }

    my $rs = $self->people_schema()->resultset('SpOrder');

    my $row = $rs->update_or_create( \%data );
    print STDERR "sp_order_id = ".$row->sp_order_id()."\n";
    foreach my $b (@{$self->batches}) {
	$b->store();
    }
    return $row->sp_order_id();
}

1;

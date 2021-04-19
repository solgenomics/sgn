
package CXGN::Stock::Order;

use Moose;
use Data::Dumper;
use CXGN::Stock::OrderBatch;
use CXGN::People::Person;
use JSON;

has 'people_schema' => ( isa => 'Ref', is => 'rw', required => 1 );

has 'dbh' => (is  => 'rw', required => 1,);

has 'sp_order_id' => (isa => 'Int', is => 'rw' );

has 'order_from_id' => ( isa => 'Int', is => 'rw' );

has 'order_to_id' => ( isa => 'Int', is => 'rw' );

has 'order_status' => ( isa => 'Str', is => 'rw' );

has 'comments' => ( isa => 'Str', is => 'rw');

has 'create_date' => ( isa => 'Str', is => 'rw');

has 'completion_date' => ( isa => 'Str', is => 'rw');

has 'batches' => ( isa => 'Ref', is => 'rw', default => sub { return []; } );


sub BUILD {
    my $self = shift;
    my $args = shift;
    my $people_schema = $self->people_schema();

    if (! $args->{sp_order_id}) {
	print STDERR "Creating empty object...\n";
	return $self;
    }

    my $row = $people_schema->resultset('SpOrder')->find( { sp_order_id => $args->{sp_order_id} } );

    if (!$row) {
	die "The database has no order entry with id $args->{sp_order_id}";
    }

    $self->order_from_id($row->order_from_id);
    $self->order_to_id($row->order_to_id);
    $self->create_date($row->create_date);

#    $self->order_status($row->order_status);
#    $self->comments($row->comments);

#    my $rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $args->{sp_order_id} });

#    my @batches = ();
#    while (my $r = $rs->next()) {
#	my $batch = CXGN::Stock::OrderBatch->new( { people_schema => $people_schema, sp_orderprop_id => $row->sp_orderprop_id() });

#	push @batches, $batch;
#    }

#    $self->batches(\@batches);
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

#sub get_orders_from_person_id {
#    my $class = shift;
#    my $people_schema = shift;
#    my $person_id = shift;

#    my $rs = $people_schema->resultset('SpOrder')->search( { order_to_person_id => $person_id } );

#    my @orders;

#    while (my $row = $rs->next()) {

#	my $o = CXGN::Stock::Order->new( { sp_order_id => $row->sp_order_id() } );
#	push @orders, $o;
#    }

#    return @orders;
#}

# member functions
#
sub store {
    my $self = shift;
    my %data = (
	order_status => $self->order_status(),
	order_from_id => $self->order_from_id(),
	order_to_id => $self->order_to_id(),
	comments => $self->comments(),
    create_date => $self->create_date(),
    completion_date => $self->completion_date(),
	);
    print STDERR "NEW ORDER STATUS =".Dumper($self->order_status())."\n";
    print STDERR "COMPLETION DATE =".Dumper($self->completion_date())."\n";

    if ($self->sp_order_id()) { $data{sp_order_id} = $self->sp_order_id(); }

    my $rs = $self->people_schema()->resultset('SpOrder');

    my $row = $rs->update_or_create( \%data );
#    print STDERR "sp_order_id = ".$row->sp_order_id()."\n";
#    foreach my $b (@{$self->batches}) {
#	$b->store();
#    }
    return $row->sp_order_id();
}


sub get_orders_from_person_id {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $person_id = $self->order_from_id();
    my $dbh = $self->dbh();

    my $order_rs = $people_schema->resultset('SpOrder')->search( { order_from_id => $person_id } );
    my @orders;
    while (my $result = $order_rs->next()){
        my $item_list;
        my $order_id = $result->sp_order_id();
        my $order_to_id = $result->order_to_id();
        my $order_status = $result->order_status();
        my $create_date = $result->create_date();
        my $completion_date = $result->completion_date();
        my $comments = $result->comments();
        my $person= CXGN::People::Person->new($dbh, $order_to_id);
        my $order_to_name=$person->get_first_name()." ".$person->get_last_name();

            my $orderprop_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id } );
            while (my $item_result = $orderprop_rs->next()){
                my $item_json = $item_result->value();
                my $item_hash = JSON::Any->jsonToObj($item_json);
                my $item_list_string = $item_hash->{'clone_list'};
                my $item_list_ref = decode_json $item_list_string;
                my %list_hash = %{$item_list_ref};
                my @list = keys %list_hash;
                my @sort_list = sort @list;
                $item_list = join("<br>", @sort_list);
#            print STDERR "ITEM =".Dumper($item)."\n";
            }

            push @orders, [$order_id, $create_date, $item_list, $order_status, $completion_date, $order_to_name, $comments ];
    }

    return \@orders;
}


sub get_orders_to_person_id {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $person_id = $self->order_to_id();
    my $dbh = $self->dbh();

    my $order_rs = $people_schema->resultset('SpOrder')->search( { order_to_id => $person_id } );
    my @orders;
    while (my $result = $order_rs->next()){
        my $item_list;
        my $order_id = $result->sp_order_id();
        my $order_from_id = $result->order_from_id();
#        my $order_to_id = $result->order_to_id();
        my $order_status = $result->order_status();
        my $create_date = $result->create_date();
        my $comments = $result->comments();
        my $person= CXGN::People::Person->new($dbh, $order_from_id);
        my $order_from_name=$person->get_first_name()." ".$person->get_last_name();

        my $orderprop_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id } );
        while (my $item_result = $orderprop_rs->next()){
            my $item_json = $item_result->value();
            my $item_hash = JSON::Any->jsonToObj($item_json);
            my $item_list_string = $item_hash->{'clone_list'};
            my $item_list_ref = decode_json $item_list_string;
            my %list_hash = %{$item_list_ref};
            my @list = keys %list_hash;
            my @sort_list = sort @list;
            $item_list = join("<br>", @sort_list);
#            print STDERR "ITEM =".Dumper($item)."\n";
        }

        push @orders, {
            order_id => $order_id,
            order_from_name => $order_from_name,
            create_date => $create_date,
            item_list => $item_list,
            order_status => $order_status,
            contact_person_comments => $comments
        }
    }
#    print STDERR "ORDERS =".Dumper(\@orders)."\n";
    return \@orders;
}


1;

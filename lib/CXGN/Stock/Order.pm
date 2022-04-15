
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

}


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

    if ($self->sp_order_id()) { $data{sp_order_id} = $self->sp_order_id(); }

    my $rs = $self->people_schema()->resultset('SpOrder');

    my $row = $rs->update_or_create( \%data );

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
            my @list;
            my $item_json = $item_result->value();
            my $item_hash = JSON::Any->jsonToObj($item_json);
            my $all_items = $item_hash->{'clone_list'};
            foreach my $each_item (@$all_items) {
                my $item_name = (keys %$each_item)[0];
                my $quantity = $each_item->{$item_name}->{'quantity'};
                my $comments = $each_item->{$item_name}->{'comments'};

                my $each_item_details;
                if ($comments) {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . "," . " " . "comments:" . $comments;
                } else {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity;
                }

                push @list, $each_item_details;

            }
            my @sort_list = sort @list;
            $item_list = join("<br>", @sort_list);
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
        my $completion_date = $result->completion_date();
        my $comments = $result->comments();
        my $person= CXGN::People::Person->new($dbh, $order_from_id);
        my $order_from_name=$person->get_first_name()." ".$person->get_last_name();

        my $orderprop_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id } );
        while (my $item_result = $orderprop_rs->next()){
            my @list;
            my $item_json = $item_result->value();
            my $item_hash = JSON::Any->jsonToObj($item_json);
            my $all_items = $item_hash->{'clone_list'};
            foreach my $each_item (@$all_items) {
                my $item_name = (keys %$each_item)[0];
                my $quantity = $each_item->{$item_name}->{'quantity'};
                my $comments = $each_item->{$item_name}->{'comments'};

                my $each_item_details;
                if ($comments) {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . "," . " " . "comments:" . $comments;
                } else {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity;
                }

                push @list, $each_item_details;

            }
            my @sort_list = sort @list;
            $item_list = join("<br>", @sort_list);
        }

        push @orders, {
            order_id => $order_id,
            order_from_name => $order_from_name,
            create_date => $create_date,
            item_list => $item_list,
            order_status => $order_status,
            completion_date => $completion_date,
            contact_person_comments => $comments
        }
    }
#    print STDERR "ORDERS =".Dumper(\@orders)."\n";
    return \@orders;
}


sub get_order_details {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $dbh = $self->dbh();
    my $order_id = $self->sp_order_id();
    my @order_details;

    my $order_rs = $people_schema->resultset('SpOrder')->find( { sp_order_id => $order_id } );

    my $order_from_id = $order_rs->order_from_id();
    my $from_person= CXGN::People::Person->new($dbh, $order_from_id);
    my $order_from_name=$from_person->get_first_name()." ".$from_person->get_last_name();

    my $order_to_id = $order_rs->order_to_id();
    my $to_person= CXGN::People::Person->new($dbh, $order_to_id);
    my $order_to_name=$to_person->get_first_name()." ".$to_person->get_last_name();

    my $order_status = $order_rs->order_status();
    my $create_date = $order_rs->create_date();
    my $completion_date = $order_rs->completion_date();
    my $comments = $order_rs->comments();

    my $orderprop_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id } );
    my $item_json = $orderprop_rs->value();
    my $item_hash = JSON::Any->jsonToObj($item_json);
    my $all_items = $item_hash->{'clone_list'};
    my @list;
    foreach my $each_item (@$all_items) {
        my $item_name = (keys %$each_item)[0];
        my $quantity = $each_item->{$item_name}->{'quantity'};
        my $comments = $each_item->{$item_name}->{'comments'};

        my $each_item_details;
        if ($comments) {
            $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . "," . " " . "comments:" . $comments;
        } else {
            $each_item_details = $item_name . "," . " " . "quantity:" . $quantity;
        }

        push @list, $each_item_details;

    }
    my @sort_list = sort @list;
    my $item_list = join("<br>", @sort_list);

    push @order_details, $order_id, $order_from_name, $create_date, $item_list, $order_to_name, $order_status, $comments;
#    print STDERR "DETAILS =".Dumper(\@order_details)."\n";

    return \@order_details;

}


1;


package CXGN::Stock::Order;

use Moose;
use Data::Dumper;
use CXGN::Stock::OrderBatch;
use CXGN::Stock::OrderStatusDetails;
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

has 'order_status_details' => (isa => 'HashRef', is => 'rw');

has 'bcs_schema' => ( isa => 'Ref', is => 'rw');


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
                my $additional_info = $each_item->{$item_name}->{'additional_info'};

                my $each_item_details;
                if ($additional_info && $comments) {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . ",". " "."additional info:". $additional_info. "," . " " . "comments:" . $comments;
                } elsif ($additional_info && (!$comments)){
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . ",". " "."additional info:". $additional_info;
                } elsif ((!$additional_info) && $comments) {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . "," . " "."comments:" . $comments;
                } else {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity;
                }
                push @list, $each_item_details;

            }
            my @sort_list = sort @list;
            $item_list = join("<br>", @sort_list);
        }
#        print STDERR "ITEM IDENTIFIERS =".Dumper(\@item_identifiers)."\n";
        push @orders, [$order_id, $create_date, $item_list, $order_status, $completion_date, $order_to_name, $comments];
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
                my $additional_info = $each_item->{$item_name}->{'additional_info'};

                my $each_item_details;
                if ($additional_info && $comments) {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . ",". " "."additional info:". $additional_info. "," . " " . "comments:" . $comments;
                } elsif ($additional_info && (!$comments)){
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . ",". " "."additional info:". $additional_info;
                } elsif ((!$additional_info) && $comments) {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . "," . " "."comments:" . $comments;
                } else {
                    $each_item_details = $item_name . "," . " " . "quantity:" . $quantity;
                }
                push @list, $each_item_details;
            }
            my @sort_list = sort @list;
            $item_list = join("<br>", @sort_list);
        }
#        print STDERR "ITEM IDENTIFIERS =".Dumper(\@item_identifiers)."\n";
        push @orders, {
            order_id => $order_id,
            order_from_name => $order_from_name,
            create_date => $create_date,
            item_list => $item_list,
            order_status => $order_status,
            completion_date => $completion_date,
            contact_person_comments => $comments,
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
        my $additional_info = $each_item->{$item_name}->{'additional_info'};

        my $each_item_details;
        if ($additional_info && $comments) {
            $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . ",". " "."additional info:". $additional_info. "," . " " . "comments:" . $comments;
        } elsif ($additional_info && (!$comments)){
            $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . ",". " "."additional info:". $additional_info;
        } elsif ((!$additional_info) && $comments) {
            $each_item_details = $item_name . "," . " " . "quantity:" . $quantity . "," . " "."comments:" . $comments;
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


sub get_tracking_identifiers_from_person_id {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $person_id = $self->order_from_id();
    my $dbh = $self->dbh();

    my $order_rs = $people_schema->resultset('SpOrder')->search( { order_from_id => $person_id } );
    my %tracking_identifiers;
    while (my $result = $order_rs->next()){
        my $item_list;
        my $order_id = $result->sp_order_id();
        my $order_status = $result->order_status();
        if ($order_status ne 'completed') {
            my $orderprop_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id } );
            while (my $item_result = $orderprop_rs->next()){
                my $item_json = $item_result->value();
                my $item_hash = JSON::Any->jsonToObj($item_json);
                my $all_items = $item_hash->{'clone_list'};
                foreach my $each_item (@$all_items) {
                    my $item_name = (keys %$each_item)[0];
                    my $each_item_identifier = $order_id."_".$item_name;
                    $tracking_identifiers{$order_id}{$each_item_identifier}++;
                }
            }
        }
    }

    return \%tracking_identifiers;
}


sub update_order_status_details {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $schema = $self->bcs_schema();
    my $dbh = $self->dbh();

    my $order_id = $self->sp_order_id();
    my $new_order_status_details = $self->order_status_details();
    print STDERR "ORDER ID =".Dumper($order_id)."\n";
    print STDERR "ORDER STATUS DETAILS =".Dumper($new_order_status_details)."\n";

    my $prop_id;
    my %current_status;
    my $order_progress_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'order_progress_json', 'sp_order_property')->cvterm_id();
    my $previous_orderprop_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id, type_id => $order_progress_cvterm_id } );
    print STDERR "PREVIOUS RS =".Dumper($previous_orderprop_rs)."\n";
    if ($previous_orderprop_rs) {
        $prop_id = $previous_orderprop_rs->sp_orderprop_id();
        my $value_json = $previous_orderprop_rs->value();
        my $value_hash = JSON::Any->jsonToObj($value_json);
        print STDERR "PREVIOUS PROGRESS HASH =".Dumper($value_hash)."\n";
        $value_hash->{'order_status_details'} = $new_order_status_details;
        my $all_status_details = $value_hash->{'order_status_details'};
        %current_status = %{$all_status_details};
    } else {
        %current_status = %{$new_order_status_details};
    }

    print STDERR "CURRENT PROGRESS =".Dumper(\%current_status)."\n";
    my $order_prop = CXGN::Stock::OrderStatusDetails->new({ bcs_schema => $schema, people_schema => $people_schema});
    $order_prop->parent_id($order_id);
    $order_prop->prop_id($prop_id);
    $order_prop->order_status_details(\%current_status);
    my $updated_orderprop = $order_prop->store_sp_orderprop();


}


sub get_order_status {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $schema = $self->bcs_schema();
    my $order_id = $self->sp_order_id();
    my $dbh = $self->dbh();
    my @all_item_status;

    my $order_progress_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'order_progress_json', 'sp_order_property')->cvterm_id();
    my $orderprop_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id, type_id => $order_progress_cvterm_id });
    if ($orderprop_rs) {
        my $orderprop_value = $orderprop_rs->value();
        my $orderprop_value_hash = JSON::Any->jsonToObj($orderprop_value);
        print STDERR "STATUS HASH =".Dumper($orderprop_value_hash)."\n";
        my $order_status = $orderprop_value_hash->{'order_status_details'};
        my %order_status_hash = %{$order_status};

        foreach my $item_name (keys %order_status_hash) {
            my @each_item_status = ();
            my $order_status_string;
            my $subculture_status = $order_status_hash{$item_name}{'subculture'};
            my %subculture_status_hash = %{$subculture_status};
            while (my ($key, $value) = each %subculture_status_hash) {
                my @subculture_info = ();
                my $subculture_date = 'subculture date:'.''.$key;
                push @subculture_info, $subculture_date;
                my $subculture_copies = 'number of copies:'.''.$value;
                push @subculture_info, $subculture_copies;
                $order_status_string = join("<br>", @subculture_info);
            }

            push @all_item_status, [$item_name, $order_status_string];
        }
    }

    return \@all_item_status;

}


1;

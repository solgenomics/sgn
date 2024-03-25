
package CXGN::Stock::Order;

use Moose;
use Data::Dumper;
use CXGN::Stock::OrderBatch;
use CXGN::People::Person;
use JSON;
use SGN::Model::Cvterm;


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

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema', is => 'rw');


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
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $person_id = $self->order_from_id();
    my $dbh = $self->dbh();

    my $order_batch_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'order_batch_json', 'sp_order_property')->cvterm_id();

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

        my $orderprop_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id, type_id => $order_batch_json_cvterm_id } );
        my $all_items = ();
        while (my $item_result = $orderprop_rs->next()){
            my @list;
            my $item_json = $item_result->value();
            my $item_hash = JSON::Any->jsonToObj($item_json);
            $all_items = $item_hash->{'clone_list'};
        }

        push @orders, {
            order_id => $order_id,
            create_date => $create_date,
            clone_list => $all_items,
            order_status => $order_status,
            completion_date => $completion_date,
            order_to_name => $order_to_name,
            comments => $comments
        }
    }

    return \@orders;
}


sub get_orders_to_person_id {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $person_id = $self->order_to_id();
    my $dbh = $self->dbh();
    my $order_batch_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'order_batch_json', 'sp_order_property')->cvterm_id();

    my $order_rs = $people_schema->resultset('SpOrder')->search( { order_to_id => $person_id } );
    my @orders;
    while (my $result = $order_rs->next()){
        my $item_list;
        my $order_id = $result->sp_order_id();
        my $order_from_id = $result->order_from_id();
        my $order_status = $result->order_status();
        my $create_date = $result->create_date();
        my $completion_date = $result->completion_date();
        my $comments = $result->comments();
        my $person= CXGN::People::Person->new($dbh, $order_from_id);
        my $order_from_name=$person->get_first_name()." ".$person->get_last_name();

        my $orderprop_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id, type_id => $order_batch_json_cvterm_id } );
        my $all_items = ();
        while (my $item_result = $orderprop_rs->next()){
            my @list;
            my $item_json = $item_result->value();
            my $item_hash = JSON::Any->jsonToObj($item_json);
            $all_items = $item_hash->{'clone_list'};
        }

        push @orders, {
            order_id => $order_id,
            order_from_name => $order_from_name,
            create_date => $create_date,
            clone_list => $all_items,
            order_status => $order_status,
            completion_date => $completion_date,
            contact_person_comments => $comments
        }
    }

    return \@orders;
}


sub get_order_details {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $dbh = $self->dbh();
    my $order_id = $self->sp_order_id();
    my @order_details;
    my $order_batch_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'order_batch_json', 'sp_order_property')->cvterm_id();

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

    my $orderprop_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id, type_id => $order_batch_json_cvterm_id } );
    my $item_json = $orderprop_rs->value();
    my $item_hash = JSON::Any->jsonToObj($item_json);
    my $all_items = $item_hash->{'clone_list'};

    push @order_details, $order_id, $order_from_name, $create_date, $all_items, $order_to_name, $order_status, $comments, $order_to_id;

    return \@order_details;

}


sub get_tracking_info {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $dbh = $self->dbh();
    my $order_id = $self->sp_order_id();
    my $order_batch_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'order_batch_json', 'sp_order_property')->cvterm_id();

    my $orderprop_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id, type_id => $order_batch_json_cvterm_id } );
    my $item_json = $orderprop_rs->value();
    my $item_hash = JSON::Any->jsonToObj($item_json);
    my $all_items = $item_hash->{'clone_list'};

    my @all_tracking_info;
    my $item_number = 0;
    foreach my $item (@$all_items) {
        my $item_number_string;
        my %item_details = %$item;
        my ($name, $value) = %item_details;
        my $item_rs = $schema->resultset("Stock::Stock")->find({uniquename => $name});
        my $item_stock_id = $item_rs->stock_id();
        my $required_quantity = $value->{'Required Quantity'};
        my $required_stage = $value->{'Required Stage'};
        $item_number++;
        $item_number_string = $order_id.'-'.$item_number;

        push @all_tracking_info, [ "order".$order_id.":".$name, "order".$order_id.":".$item_stock_id, $name, $order_id, $item_number_string, $required_quantity, $required_stage,]
    }

    return \@all_tracking_info;

}

sub get_active_item_tracking_info {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $person_id = $self->order_to_id();
    my $schema = $self->bcs_schema();
    my $dbh = $self->dbh();
    my @all_tracking_info;
    my $order_batch_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'order_batch_json', 'sp_order_property')->cvterm_id();

    my $order_rs = $people_schema->resultset('SpOrder')->search( { order_to_id => $person_id } );
    my @orders;
    while (my $result = $order_rs->next()){
        my $item_list;
        my $order_id = $result->sp_order_id();
        my $order_from_id = $result->order_from_id();
        my $order_status = $result->order_status();
        my $create_date = $result->create_date();
        my $completion_date = $result->completion_date();
        my $comments = $result->comments();
        my $person= CXGN::People::Person->new($dbh, $order_from_id);
        my $order_from_name=$person->get_first_name()." ".$person->get_last_name();

        my $orderprop_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id, type_id => $order_batch_json_cvterm_id } );
        my $all_items = ();
        while (my $item_result = $orderprop_rs->next()){
            my @list;
            my $item_json = $item_result->value();
            my $item_hash = JSON::Any->jsonToObj($item_json);
            $all_items = $item_hash->{'clone_list'};
            my $item_number = 0;
            foreach my $item (@$all_items) {
                my $item_number_string;
                my %item_details = %$item;
                my ($name, $value) = %item_details;
                my $item_rs = $schema->resultset("Stock::Stock")->find({uniquename => $name});
                my $item_stock_id = $item_rs->stock_id();
                my $required_quantity = $value->{'Required Quantity'};
                my $required_stage = $value->{'Required Stage'};
                $item_number++;
                $item_number_string = $order_id.'-'.$item_number;

                push @all_tracking_info, [ "order".$order_id.":".$name, "order".$order_id.":".$item_stock_id, $name, $order_id, $item_number_string, $required_quantity, $required_stage,]
            }
        }

    }

    return \@all_tracking_info;

}


sub get_orders_to_person_id_progress {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $person_id = $self->order_to_id();
    my $dbh = $self->dbh();

    my $tracking_identifier_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
    my $tracking_data_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id();
    my $material_of_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id();
    my $order_identifier_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'order_tracking_identifiers', 'sp_order_property')->cvterm_id();
    my $order_batch_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'order_batch_json', 'sp_order_property')->cvterm_id();

    my $order_rs = $people_schema->resultset('SpOrder')->search( { order_to_id => $person_id } );
    my @activity_info;
    while (my $result = $order_rs->next()){
        my %required_info = ();
        my $order_id = $result->sp_order_id();
        my $orderprop_item_info_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id, type_id => $order_batch_json_cvterm_id } );
        my $item_json = $orderprop_item_info_rs->value();
        my $item_hash = JSON::Any->jsonToObj($item_json);
        my $all_items_info = $item_hash->{'clone_list'};
        foreach my $item (@$all_items_info) {
            my %item_details = %$item;
            my ($name, $value) = %item_details;
            $required_info{$name} = $value;
        }

        my $orderprop_identifiers_rs = $people_schema->resultset('SpOrderprop')->search( { sp_order_id => $order_id, type_id => $order_identifier_cvterm_id } );
        while (my $order_details_result = $orderprop_identifiers_rs->next()){
            my @list = ();
            my $order_details_json = $order_details_result->value();
            my $order_details_hash = JSON::Any->jsonToObj($order_details_json);
            my $tracking_identifier = $order_details_hash->{'tracking_identifiers'};
            @list = @$tracking_identifier;

            foreach my $identifier_id (@list) {
                my $order_info = {};
                my $activity_hash = {};
                my $identifier_rs = $schema->resultset("Stock::Stock")->find( { stock_id => $identifier_id, type_id => $tracking_identifier_cvterm_id });
                my $identifier_name = $identifier_rs->uniquename();
                my $material_info = $schema->resultset("Stock::StockRelationship")->find( { object_id => $identifier_id, type_id => $material_of_cvterm_id} );
                my $material_id = $material_info->subject_id();
                my $material_rs = $schema->resultset("Stock::Stock")->find( { stock_id => $material_id });
                my $material_name = $material_rs->uniquename();
                my $material_type = $material_rs->type_id();
                $order_info =  $required_info{$material_name};
                my $activity_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $tracking_data_json_cvterm_id});
                if ($activity_info_rs) {
                    my $activity_json = $activity_info_rs->value();
                    $activity_hash = JSON::Any->jsonToObj($activity_json);
                }

                push @activity_info, [$order_id, $identifier_name, $identifier_id, $material_name, $material_id, $material_type, $activity_hash, $order_info];
            }
        }
    }

    return \@activity_info;
}



1;

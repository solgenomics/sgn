
package SGN::Controller::AJAX::Order;

use Moose;
use CXGN::Stock::Order;
use CXGN::Stock::OrderBatch;
use Data::Dumper;
use JSON;
use DateTime;
use CXGN::People::Person;
use CXGN::Contact;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub submit_order : Path('/ajax/order/submit') : ActionClass('REST'){ }

sub submit_order_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh();
    my $list_id = $c->req->param('list_id');
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
#    print STDERR "LIST ID =".Dumper($list_id)."\n";

    if (!$c->user()) {
        print STDERR "User not logged in... not adding a catalog item.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add a catalog item." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $user_role = $c->user->get_object->get_user_type();

    my $list = CXGN::List->new( { dbh=>$dbh, list_id=>$list_id });
    my $items = $list->elements();
#    print STDERR "ITEMS =".Dumper($items)."\n";
    my $catalog_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_catalog_json', 'stock_property')->cvterm_id();
    my $contact_person_id;
    my %group_by_contact_id;
    my @all_items = @$items;
    foreach my $ordered_item (@all_items) {
        my @ordered_item_split = split / /, $ordered_item;
        my $item_name = $ordered_item_split[0];
        print STDERR "ITEM NAME =".Dumper($item_name)."\n";
        my $item_rs = $schema->resultset("Stock::Stock")->find( { uniquename => $item_name });
        my $item_id = $item_rs->stock_id();
#        print STDERR "ITEM ID =".Dumper($item_id)."\n";
        my $item_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $item_id, type_id => $catalog_cvterm_id});
        my $item_info_string = $item_info_rs->value();
        my $item_info_hash = decode_json $item_info_string;
        $contact_person_id = $item_info_hash->{'contact_person_id'};
        my $item_type = $item_info_hash->{'item_type'};
        $group_by_contact_id{$contact_person_id}{$ordered_item} = $item_type;
    }

    my @contact_email_list;
    foreach my $contact_id (keys %group_by_contact_id) {
        my @history = ();
        my $history_info = {};
        my $item_ref = $group_by_contact_id{$contact_id};
        my $order_list = encode_json $item_ref;
#        print STDERR "ORDER LIST =".Dumper($order_list)."\n";
        my $new_order = CXGN::Stock::Order->new( { people_schema => $people_schema, dbh => $dbh});
        $new_order->order_from_id($user_id);
        $new_order->order_to_id($contact_id);
        $new_order->order_status("submitted");
        $new_order->create_date($timestamp);
        my $order_id = $new_order->store();
#        print STDERR "ORDER ID =".($order_id)."\n";
        if (!$order_id){
            $c->stash->{rest} = {error_string => "Error saving your order",};
            return;
        }

        $history_info ->{'submitted'} = $timestamp;
        push @history, $history_info;

        my $order_prop = CXGN::Stock::OrderBatch->new({ bcs_schema => $schema, people_schema => $people_schema});
        $order_prop->clone_list($order_list);
        $order_prop->parent_id($order_id);
        $order_prop->history(\@history);
    	my $order_prop_id = $order_prop->store_sp_orderprop();
#        print STDERR "ORDER PROP ID =".($order_prop_id)."\n";

        if (!$order_prop_id){
            $c->stash->{rest} = {error_string => "Error saving your order",};
            return;
        }

        my $contact_person = CXGN::People::Person -> new($dbh, $contact_person_id);
        my $contact_email = $contact_person->get_contact_email();
        push @contact_email_list, $contact_email;
    }
#    print STDERR "EMAIL LIST =".Dumper(\@contact_email_list)."\n";

    my $host = $c->config->{main_production_site_url};
    my $project_name = $c->config->{project_name};
    my $subject="Ordering Notification from $project_name";
    my $body=<<END_HEREDOC;

You have an order submitted to $project_name ($host/order/stocks/view).
Please do *NOT* reply to this message.

Thank you,
$project_name Team

END_HEREDOC

    foreach my $each_email (@contact_email_list) {
        CXGN::Contact::send_email($subject,$body,$each_email);
    }

    $c->stash->{rest} = {success => "1",};

}


sub get_user_current_orders :Path('/ajax/order/current') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your current orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $orders = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, order_from_id => $user_id});
    my $all_orders_ref = $orders->get_orders_from_person_id();
    my @current_orders;
    my @all_orders = @$all_orders_ref;
    foreach my $order (@all_orders) {
        if (($order->[3]) ne 'completed') {
            push @current_orders, [qq{<a href="/order/details/view/$order->[0]">$order->[0]</a>}, $order->[1], $order->[2], $order->[3], $order->[5], $order->[6]]
        }
    }
    $c->stash->{rest} = {data => \@current_orders};
}

sub get_user_completed_orders :Path('/ajax/order/completed') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your completed orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $orders = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, order_from_id => $user_id});
    my $all_orders_ref = $orders->get_orders_from_person_id();
    my @completed_orders;
    my @all_orders = @$all_orders_ref;
    foreach my $order (@all_orders) {
        if (($order->[3]) eq 'completed') {
            push @completed_orders, [qq{<a href="/order/details/view/$order->[0]">$order->[0]</a>}, $order->[1], $order->[2], $order->[3], $order->[4], $order->[5], $order->[6]]
        }
    }

    $c->stash->{rest} = {data => \@completed_orders};

}


sub get_vendor_current_orders :Path('/ajax/order/vendor_current_orders') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your orders!'};
        $c->detach();
    }

    if ($c->user){
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $orders = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, order_to_id => $user_id});
    my $vendor_orders_ref = $orders->get_orders_to_person_id();

    my @vendor_current_orders;
    my @all_vendor_orders = @$vendor_orders_ref;
        foreach my $vendor_order (@all_vendor_orders) {
            if (($vendor_order->{'order_status'}) ne 'completed') {
                push @vendor_current_orders, $vendor_order
            }
        }

    $c->stash->{rest} = {data => \@vendor_current_orders};

}


sub get_vendor_completed_orders :Path('/ajax/order/vendor_completed_orders') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to view your orders!'};
        $c->detach();
    }

    if ($c->user) {
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $orders = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, order_to_id => $user_id});
    my $vendor_orders_ref = $orders->get_orders_to_person_id();

    my @vendor_completed_orders;
    my @all_vendor_orders = @$vendor_orders_ref;
    foreach my $vendor_order (@all_vendor_orders) {
        if (($vendor_order->{'order_status'}) eq 'completed') {
            push @vendor_completed_orders, $vendor_order
        }
    }

    $c->stash->{rest} = {data => \@vendor_completed_orders};

}


sub update_order :Path('/ajax/order/update') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    my $order_id = $c->req->param('order_id');
    my $new_status = $c->req->param('new_status');
    my $contact_person_comments = $c->req->param('contact_person_comments');
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to update the orders!'};
        $c->detach();
    }

    if ($c->user) {
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $order_obj;
    if ($new_status eq 'completed') {
        $order_obj = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, sp_order_id => $order_id, order_to_id => $user_id, order_status => $new_status, completion_date => $timestamp, comments => $contact_person_comments});
    } else {
        $order_obj = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, sp_order_id => $order_id, order_to_id => $user_id, order_status => $new_status, comments => $contact_person_comments});
    }

    my $updated_order = $order_obj->store();
#    print STDERR "UPDATED ORDER ID =".Dumper($updated_order)."\n";
    if (!$updated_order){
        $c->stash->{rest} = {error_string => "Error updating the order",};
        return;
    }

    my $orderprop_rs = $people_schema->resultset('SpOrderprop')->find( { sp_order_id => $order_id } );
    my $orderprop_id = $orderprop_rs->sp_orderprop_id();
    my $details_json = $orderprop_rs->value();
    print STDERR "ORDER PROP ID =".Dumper($orderprop_id)."\n";
    my $detail_hash = JSON::Any->jsonToObj($details_json);

    my $order_history_ref = $detail_hash->{'history'};
    my @order_history = @$order_history_ref;
    my $new_status_record = {};
    $new_status_record->{$new_status} = $timestamp;
    push @order_history, $new_status_record;
    $detail_hash->{'history'} = \@order_history;

    my $order_prop = CXGN::Stock::OrderBatch->new({ bcs_schema => $schema, people_schema => $people_schema, sp_order_id => $order_id, prop_id => $orderprop_id});
    $order_prop->history(\@order_history);
    my $updated_orderprop = $order_prop->store_sp_orderprop();

    if (!$updated_orderprop){
        $c->stash->{rest} = {error_string => "Error updating the order",};
        return;
    }

    $c->stash->{rest} = {success => "1",};


}


1;

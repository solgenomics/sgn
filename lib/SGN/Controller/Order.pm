
package SGN::Controller::Order;

use Moose;
use URI::FromHash 'uri';
use CXGN::Stock::Order;
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }


sub order_stocks :Path('/order/stocks/view') :Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
        my $user_id = $c->user()->get_object()->get_sp_person_id();
        $c->stash->{user_id} = $user_id;
    }

    my $tracking_order_activity = $c->config->{tracking_order_activity};
    $c->stash->{tracking_order_activity} = $tracking_order_activity;

    $c->stash->{template} = '/order/stocks.mas';

}


sub order_details :Path('/order/details/view') : Args(1) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;
    my $order_properties = $c->config->{order_properties};
    my @properties = split ',',$order_properties;
    my $ordering_type = $c->config->{ordering_type};

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }

    my $order_number = shift;
    my $order_obj = CXGN::Stock::Order->new({ dbh => $dbh, bcs_schema => $schema, people_schema => $people_schema, sp_order_id => $order_number});
    my $order_result = $order_obj->get_order_details();

    my $all_items = $order_result->[3];
    my $item_name;
    my $value_string;
    my $empty_string = '';
    my @all_item_details = ();
    my $all_details_string;

    foreach my $each_item (@$all_items) {
        my @item_details = ();
        my @all_values = ();
        $item_name = (keys %$each_item)[0];
        push @all_values, $item_name;
        push @item_details, "<b>"."Item Name"."<b>". ":"."".$item_name;
        foreach my $field (@properties) {
            my $each_detail = $each_item->{$item_name}->{$field};
            push @all_values, $each_detail;
            my $detail_string = $field. ":"."".$each_detail;
            push @item_details, $detail_string;
        }

        push @item_details, $empty_string;
        my $details_string = join("<br>", @item_details);
        $value_string = join(",", @all_values);
        push @all_item_details, $details_string;
    }
    $all_details_string = join("<br>", @all_item_details);

    $c->stash->{order_id} = $order_result->[0];
    $c->stash->{order_from} = $order_result->[1];
    $c->stash->{create_date} = $order_result->[2];
    $c->stash->{item_list} = $all_details_string;
    $c->stash->{order_to} = $order_result->[4];
    $c->stash->{order_status} = $order_result->[5];
    $c->stash->{comments} = $order_result->[6];
    $c->stash->{order_properties} = $order_properties;
    $c->stash->{order_values} = $value_string;
    $c->stash->{ordering_type} = $ordering_type;
    $c->stash->{template} = '/order/order_details.mas';


}


1;

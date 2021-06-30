
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
    }

    $c->stash->{template} = '/order/stocks.mas';

}


sub order_details :Path('/order/details/view') : Args(1) {
    my $self = shift;
    my $c = shift;
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }

    my $order_number = shift;
    my $order_rs = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, sp_order_id => $order_number});
    my $order_result = $order_rs->get_order_details();

    $c->stash->{order_id} = $order_result->[0];
    $c->stash->{order_from} = $order_result->[1];
    $c->stash->{create_date} = $order_result->[2];
    $c->stash->{item_list} = $order_result->[3];
    $c->stash->{order_to} = $order_result->[4];
    $c->stash->{order_status} = $order_result->[5];
    $c->stash->{comments} = $order_result->[6];

    $c->stash->{template} = '/order/order_details.mas';


}


1;

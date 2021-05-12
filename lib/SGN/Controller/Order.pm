
package SGN::Controller::Order;

use Moose;
use URI::FromHash 'uri';


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


1;

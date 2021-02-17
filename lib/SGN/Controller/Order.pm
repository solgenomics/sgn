
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

    $c->stash->{template} = '/order/stocks.mas';

}


# sub view_orders :Path('/order/stocks/view') Args(0) {
#     my $self = shift;
#     my $c = shift;

#     if (! $c->user()) {
# 	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
#         return;
#     }

#     if ($c->user()->get_object()->has_role("stock_provider")) {
# 	$c->stash->{role} = "stock_provider";
#     }
#     else {
# 	$c->stash->{role} = "stock_orderer";
#     }

#     $c->stash->{template} = '/order/view.mas';

# }

1;

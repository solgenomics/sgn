
package SGN::Controller::AJAX::Order;

use Moose;
use CXGN::Stock::StockOrder;
use Data::Dumper;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub order :Chained('/') PathPart('ajax/orders/') Args(1) {
    my $self = shift;
    my $c = shift;

    my $person_id = shift;

    my $orders = CXGN::Stock::StockOrder::get_orders_by_person_id( $c->dbic_schema(), $person_id);

    $c->stash->{order_from_person_id} = $person_id;
    $c->stash->{orders} = { data => $orders };
}

sub new_orders :Chained('order') PathPart('view') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{rest} = { data => $c->stash->{orders} };
}


#sub new_order: Chained('order') PathPart('new') Args(0) {
#    my $self = shift;
#    my $c = shift;

#    my $order_from_person_id =  $c->stash->{order_from_person_id};
#    my $order_to_person_id = $c->req->param('order_to_person_id');
    #my $order_status = $c->req->param('order_status');
#    my $comment = $c->req->param('comments');

#    my $so = CXGN::Stock::StockOrder->new( { bcs_schema => $c->dbic_schema() });

    #$so->order_from_person_id($order_from_person_id);
#    $so->order_to_person_id($order_to_person_id);
#    $so->order_status("submitted");
#    $so->comment($comment);

#    $so->store();
#}

sub submit_order : Path('/ajax/order/submit') : ActionClass('REST'){ }

sub submit_order_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    my $list_id = $c->req->param('list_id');
    print STDERR "LIST ID =".Dumper($list_id)."\n";

    if (!$c->user()) {
        print STDERR "User not logged in... not adding a catalog item.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add a catalog item." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $user_role = $c->user->get_object->get_user_type();
}

1;

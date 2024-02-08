
package SGN::Controller::ActivityInfo;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }

sub activity_details :Path('/activity/details') : Args(1) {
    my $self = shift;
    my $c = shift;
    my $identifier_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $dbh = $c->dbc->dbh;
#    my $order_properties = $c->config->{order_properties};
#    my @properties = split ',',$order_properties;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $identifier_name = $schema->resultset("Stock::Stock")->find({stock_id => $identifier_id})->uniquename();


    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{identifier_name} = $identifier_name;

    $c->stash->{template} = '/order/activity_info_details.mas';


}


1;

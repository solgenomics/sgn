
package SGN::Controller::GPCP;

use Moose;
use Catalyst::Controller;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub gpcp_input :Path('/tools/gcpc') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user) { 
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }
    $c->stash->{template} = '/tools/gcpc/index.mas';
}

1;

package SGN::Controller::InteractiveBarcoder;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub interactive_barcoder_main :Path('/tools/InteractiveBarcoder') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {  # redirect to login page
    	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
    	return;
    }

    $c->stash->{template} = '/tools/InteractiveBarcoder.mas';
}

return 1;

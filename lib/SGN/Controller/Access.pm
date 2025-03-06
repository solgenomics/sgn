
package SGN::Controller::Access;

use Moose;
use List::Util 'any';
use CXGN::Access;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }


sub access_table_page :Path('/access/table') {
    my $self = shift;
    my $c = shift;

    if (! (my $user = $c->user())) {
	$c->stash->{rest} = { error => "You must be logged in to use this resource" };
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    if (! $c->user()) {
	$c->stash->{rest} = { error => "NOT LOGGED IN!\n" };
	return;
    }
    
    if (! $c->stash->{access}->grant( $c->stash->{user_id}, "read", "privileges")) { 
    	$c->response->status(401);
	my $error =  "You do not have the necessary privileges to access this resource";
	$c->stash->{data_type} = 'privilege';
	$c->stash->{message} = $error;
	$c->stash->{template} = '/access/access_denied.mas';
	return;
    }

    # data will be fetched using ajax on mason component
    $c->stash->{template} = '/access/table.mas';
}

sub access :Path('/access') Args(0) {
    my $self = shift;
    my $c = shift;

    my $message;
    my $sp_person_id = $c->user() ? $c->user()->get_object->get_sp_person_id() : undef;
    if (!$c->stash->{access}->check_user($sp_person_id, "accesstest")) {
	$message = "You don't have sufficient privileges to access this page.";
	
    }

    else {
	$message = "YOU HAVE ALL THE RIGHTS IN THE WORLD!\n";
    }

    $c->stash->{message} = $message;

    $c->stash->{template} = '/site/access/manage.mas';

}




1;

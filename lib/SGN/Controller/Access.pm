
package SGN::Controller::Access;

use Moose;
use List::Util 'any';
use CXGN::Access;


BEGIN { extends 'Catalyst::Controller'; }


sub access_table_page :Path('/access/table') {
    my $self = shift;
    my $c = shift;

    if (! (my $user = $c->user())) {
	$c->stash->{rest} = { error => "You must be logged in to use this resource" };
	return;
    }
    
    my @privileges = $c->stash->{access}->check_user("access_table_page", $c->user()->get_object()->get_sp_person_id());
    
    if (! any { /read/ } @privileges) {
	$c->response->status(401);
	my $error =  "You do not have the necessary privileges to access this resource";
	$c->stash->{rest} = { error => $error};
	$c->stash->{message} = $error;
	$c->stash->{template} = '/generic_message.mas';
	return;
    }

    $c->stash->{template} = '/access/table.mas';
}

sub access :Path('/access') Args(0) {
    my $self = shift;
    my $c = shift;

    my $message;
    my $sp_person_id = $c->user() ? $c->user()->get_object->get_sp_person_id() : undef;
    if (!$c->stash->{access}->check_user("accesstest", $sp_person_id)) {
	$message = "You don't have sufficient privileges to access this page.";
	
    }

    else {
	$message = "YOU HAVE ALL THE RIGHTS IN THE WORLD!\n";
    }

    $c->stash->{message} = $message;

    $c->stash->{template} = '/site/access/manage.mas';

}




1;

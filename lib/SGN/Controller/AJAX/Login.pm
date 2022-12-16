
package SGN::Controller::AJAX::Login;

use Moose;
use CXGN::Login;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub is_logged_in :Path('/user/logged_in') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    if (my $user = $c->user()) { 
	my $user_id = $user->get_object->get_sp_person_id();
	$c->stash->{rest} = {
	    user_id => $user_id,
	    username => $user->get_object->get_username(),
	    first_name => $user->get_object->get_first_name(),
	    last_name => $user->get_object->get_last_name(),
	};
	return;
    }
    $c->stash->{rest} = { user_id => 0 };
}

sub get_roles :Path('/user/get_roles') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    if (my $user = $c->user()) { 
	my @roles = $user->get_object->get_roles();
	$c->stash->{rest} = { roles => @roles };
	return;
    }
    $c->stash->{rest} = { roles => 0 };
}

sub log_in :Path('/user/login') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $login = CXGN::Login->new();
    
    # implement

}
    
sub log_out :Path('/user/logout') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    # implement

}

1;


package SGN::Controller::AJAX::Login;

use Moose;
use CXGN::People::Login;
use CXGN::People::Person;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub is_logged_in :Path('/user/logged_in') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    my $dbh = $c->dbic_schema("CXGN::People::Schema")->storage->dbh;
    my $login = CXGN::Login->new($dbh);
    if (my ($person_id, $user_type) = $login->has_session()) {
        my $user_id = CXGN::People::Person->new($dbh,$person_id);
    	$c->stash->{rest} = $login -> get_login_info;
    	    # user_id => $user_id,
    	    # username => $user->get_object->get_username(),
    	    # first_name => $user->get_object->get_first_name(),
    	    # last_name => $user->get_object->get_last_name(),
    	# };
    	return;
    $c->stash->{rest} = { user_id => 0 };
    }
}

sub login_with_cookie :Path('/user/cookie_login') Args(1) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    my $cookie = shift;
    if (my $user = $c->user()) {
        my $dbh = $c->dbic_schema("CXGN::People::Schema")->storage->dbh;
        my $sp_person_id = CXGN::People::Login->get_login_by_token($dbh, $cookie);
        my $user_id = CXGN::People::Person->new($dbh, $sp_person_id);
        $c->stash->{rest} = {first_name => $user->get_object->get_first_name(),
                            last_name => $user->get_object->get_last_name(),
                            username => $user->get_object->get_username(),
                            user_id => $sp_person_id,
        };
        return;
    }
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

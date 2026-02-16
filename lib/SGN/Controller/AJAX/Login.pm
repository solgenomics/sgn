
package SGN::Controller::AJAX::Login;

use Moose;
use CXGN::People::Login;
use CXGN::People::Person;
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
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $dbh = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id)->storage->dbh();

    my $login = CXGN::Login->new($dbh);

    if (my ($person_id, $user_type) = $login->has_session()) {
        my $user_id = CXGN::People::Person->new($dbh,$person_id);
        my $login_info = $login->get_login_info();
        my $user = $c->user();
        my $domain = $c->config->{main_production_site_url};
        $c->stash->{rest} = $login -> get_login_info;
        $c->stash->{rest} = {
            first_name => $user->get_object->get_first_name(),
            last_name => $user->get_object->get_last_name(),
    	    username => $user->get_object->get_username(),
            user_id => $person_id,
            domain => $domain,
    	};
    	return;
    };
    $c->stash->{rest} = { user_id => 0 };
}

sub login_with_cookie :Path('/user/cookie_login') Args(1) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    my $cookie = shift;
    my $dbh = $c->dbc->dbh;
    my @user_info = CXGN::Login->new($dbh)->query_from_cookie($cookie);
    my $user_id = $user_info[0];
    my $p = CXGN::People::Person->new($dbh, $user_id);
    $c->stash->{rest} = {first_name => $p->get_first_name,
	    last_name => $p->get_last_name,
        username => $p->get_username,
        user_id => $user_id,
        email_address => $p->get_contact_email,
    };
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
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    my $login = CXGN::Login->new();

    # implement

}

sub log_out :Path('/user/logout') Args(0) {
    my $self = shift;
    my $c = shift;

    # implement

}

1;

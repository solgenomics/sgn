
package SGN::Controller::User;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub login :Path('/user/login') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    $c->stash->{goto_url} = $c->req->param("goto_url");

    print STDERR "GOTOURL=".$c->stash->{goto_url}."\n";
    $c->stash->{template} = '/user/login.mas';
}

sub new_user :Path('/user/new') Args(0) {
    my $self = shift;
    my $c = shift;

    # Redirect to the login page and display the new user form
    $c->res->redirect('/user/login?goto_url=/&new_user=1');
    $c->detach();
}

sub update_account :Path('/user/update') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->res->redirect('/user/login');
	return;
    }

    $c->stash->{logged_in_username} = $c->user()->get_username();
    $c->stash->{private_email} = $c->user()->get_private_email();

    $c->stash->{template} = '/user/change_account.mas';
}

sub confirm_user :Path('/user/confirm') Args(0) {
    my $self = shift;
    my $c = shift;

    my $confirm_code = $c->req->param('confirm_code');
    my $username = $c->req->param('username');

    if ($c->config->{disable_account_confirm}) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'Account confirmation is disabled on this site. Please contact nm529@cornell.edu to confirm your account.';
        return;
    }

    my $sp = CXGN::People::Login->get_login( $c->dbc()->dbh(), $username );

    if ( !$sp ) {
	confirm_failure($c, "Username \"$username\" was not found.");
	return;
    }

    if ( !$sp->get_confirm_code() ) {
	confirm_failure($c, "No confirmation is required for user <b>$username</b>. This account has already been confirmed. <p><a href='/user/login'>[Login Page]</a></p>");
	return;
    }

    if ( $sp->get_confirm_code() ne $confirm_code ) {
	confirm_failure($c, "Confirmation code is not valid!\n");
	return;
    }

    $sp->set_disabled(undef);
    $sp->set_confirm_code(undef);
    $sp->set_private_email( $sp->get_pending_email() );

    $sp->store();

    # Send confirmation to user, if manual confirmation is enabled
    if ( $c->config->{user_registration_admin_confirmation} && $c->config->{user_registration_admin_confirmation_email} ) {
        my $host = $c->config->{main_production_site_url};
        my $project_name = $c->config->{project_name};
        my $subject="[$project_name] New Account Confirmed";
        my $body=<<END_HEREDOC;

Your new account on $project_name with the username \"$username\" has been confirmed.

You can now login using your account credentials:
$host

Thank you,
$project_name Team

Please do *NOT* reply to this message. If you have any trouble logging into your 
account or have any other questions, please use the contact form instead:
$host/contact/form

END_HEREDOC
        CXGN::Contact::send_email($subject,$body,$sp->get_pending_email());
    }

    $c->stash->{template} = '/generic_message.mas';
    $c->stash->{message} = "Confirmation successful for username <b>$username</b>";
}

sub confirm_failure {
    my $c = shift;
    my $reason = shift;

    $c->stash->{template} = '/generic_message.mas';
    $c->stash->{message} = "Sorry, this confirmation code is invalid. Please check that your complete confirmation URL has been pasted correctly into your browser. ($reason)";

}

sub reset_password_form :Path('/user/reset_password_form') Args(0) {
    my $self = shift;
    my $c = shift;

    my $token = $c->req->param('reset_password_token');

    my $person_id;
    if ($token) {
	my $person_id = CXGN::People::Login->get_login_by_token($c->dbc->dbh(), $token);
	if (!$person_id) {
	    $c->stash->{message} = "The provided password reset link is invalid. Please try again with another link.";
	    $c->stash->{template} = '/generic_message.mas';
	    return;
	}

	my $person = CXGN::People::Person->new($c->dbc->dbh(), $person_id);
	$c->stash->{token} = $token;
	$c->stash->{person_id} = $person_id;
	$c->stash->{username} = $person->get_username();
	$c->stash->{template} = '/user/reset_password_form.mas';
    }
    else {
	$c->stash->{message} = "No token provided. Please try again.";
	$c->stash->{template} = '/generic_message.mas';
    }

}

sub quick_create_account :Path('/user/admin/quick_create_account') {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	$c->forward('/user/login');
	return;
    }

    $c->stash->{template} = '/user/quick_create_account.mas';
}



1;

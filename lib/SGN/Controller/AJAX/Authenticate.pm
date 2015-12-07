=head1 NAME

SGN::Controller::AJAX::Authenticate - a REST controller class to provide the
backend for authenticating users across websites.

=head1 DESCRIPTION

This module is used to log users into an sgn database from other websites. Currently used by Matthias for ETH Cassbase project.

=head1 AUTHOR
Nicolas Morales <nm529@cornell.edu>
Created: 09/24/15

=cut


package SGN::Controller::AJAX::Authenticate;

use strict;
use Moose;
use JSON;
use Data::Dumper;
use CXGN::Login;
use CXGN::People::Login;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub authenticate_cookie  : Path('/authenticate/check/token') : ActionClass('REST') { }

#
sub authenticate_cookie_GET { 
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh;
    my $login_controller = CXGN::Login->new($dbh);
    
    my $grant_type = $c->req->param("grant_type");
    my $username = $c->req->param("username");
    my $password = $c->req->param("password");

    my @status;
    my $cookie = '';
    my %userinfo;

    if ( $login_controller->login_allowed() ) {
	if ($grant_type eq 'password') {
	    my $login_info = $login_controller->login_user( $username, $password );
	    if ($login_info->{account_disabled}) {
		push(@status, 'Account Disabled');
	    }
	    if ($login_info->{incorrect_password}) {
		push(@status, 'Incorrect Password or Username');
	    }
	    if ($login_info->{duplicate_cookie_string}) {
		push(@status, 'Duplicate Cookie String');
	    }
	    if ($login_info->{logins_disabled}) {
		push(@status, 'Logins Disabled');
	    }
	    if ($login_info->{person_id}) {
		$cookie = $login_info->{cookie_string};
		push(@status, 'Login Successfull');

		my $person_id = $login_info->{person_id};
		my $p = CXGN::People::Login->new($dbh, $person_id);
		my @roles = $p->get_roles();
		%userinfo = (person_id=>$p->get_sp_person_id(), username=>$p->get_username(), first_name=>$p->get_first_name(), last_name=>$p->get_last_name(), roles=>\@roles);

	    }
	} else {
	    push(@status, 'Grant Type Not Supported. Allowed grant type: password');
	}
    } else {
	push(@status, 'Login Not Allowed');
    }
    
    my %result = (status=>\@status, result=>\%userinfo);

    $c->stash->{rest} = \%result;
}

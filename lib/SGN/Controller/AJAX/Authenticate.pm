=head1 NAME

SGN::Controller::AJAX::Authenticate - a REST controller class to provide the
backend for authenticating users across websites.

=head1 DESCRIPTION

If a user has logged into an sgn database, they will have an active session cookie stored inthe sgn database. If a user is on an external website, that website could use this module to check if that user is logged into the sgn website, and can then have access to the user's information.
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
    my $sgn_session_id = $c->req->param("cookie");

    my $dbh = $c->dbc->dbh;
    my $cookie_info = CXGN::Login->new($dbh)->query_from_cookie($sgn_session_id);
    my $status;
    my @user_info = ();
    my @user_info_list;

    #my $person_id = CXGN::Login->new($dbh)->has_session();
    #my $p = CXGN::People::Login->new($dbh, $person_id);
    #my @user_info = ({person_id=>$p->get_sp_person_id(), username=>$p->get_username(), role=>$p->get_roles()}); 

    if ($cookie_info) {
	my $q = "SELECT sp_person_id, username, first_name, last_name FROM sgn_people.sp_person WHERE cookie_string=?";
	my $sth = $dbh->prepare($q);
	if ($sth->execute($sgn_session_id)) {
	    while (my ($person_id, $username, $first_name, $last_name) = $sth->fetchrow_array ) {
		push(@user_info_list, ($person_id, $username, $first_name, $last_name));
	    }

	    my @user_roles_list;
	    my $q = "SELECT name FROM sgn_people.sp_person_roles JOIN sgn_people.sp_person as p using(sp_person_id) JOIN sgn_people.sp_roles using(sp_role_id) WHERE p.cookie_string=?";
	    my $sth = $dbh->prepare($q);
	    if ($sth->execute($sgn_session_id)) {
		while (my ($user_type) = $sth->fetchrow_array ) {
		    push(@user_roles_list, ($user_type));
		}
		@user_info = {person_id=>$user_info_list[0], username=>$user_info_list[1], first_name=>$user_info_list[2], last_name=>$user_info_list[3], roles=>\@user_roles_list};
		$status = 'OK';
		
	    } else {
		$status = 'Roles Not Found For User';
	    }
	} else {
	    $status = 'Could Not Get User Info';
	}
    } else {
	$status = 'No Valid Cookie';
    }

    my %result = (status=>$status, result=>\@user_info);

    $c->stash->{rest} = \%result;
}

package CXGN::BrAPI::v1::Authentication;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'status' => (
	isa => 'ArrayRef[Maybe[HashRef]]',
	is => 'rw',
	required => 1,
);

sub login {
	my $self = shift;
	my $grant_type = shift;
	my $password = shift;
	my $username = shift;
	my $client_id = shift;
	my $status = $self->status;

	if ($client_id){
		push @$status, { 'warning' => 'Parameter client_id not supported. Please use a username and password.' };
	}

	my $login_controller = CXGN::Login->new($self->bcs_schema->storage->dbh);

	my $message = '';
	my $cookie = '';
	my $first_name = '';
	my $last_name = '';

	if ( $login_controller->login_allowed() ) {
		if ($grant_type eq 'password' || !$grant_type) {
			my $login_info = $login_controller->login_user( $username, $password );
			if ($login_info->{account_disabled}) {
				push @$status, { 'error' => 'Account Disabled' };
			}
			if ($login_info->{incorrect_password}) {
				push @$status, { 'error' => 'Incorrect Password' };
			}
			if ($login_info->{duplicate_cookie_string}) {
				push @$status, { 'error' => 'Duplicate Cookie String' };
			}
			if ($login_info->{logins_disabled}) {
				push @$status, { 'error' => 'Logins Disabled' };
			}
			if ($login_info->{person_id}) {
				push @$status, { 'success' => 'Login Successfull' };
				$cookie = $login_info->{cookie_string};
				$first_name = $login_info->{first_name};
				$last_name = $login_info->{last_name};
			}
		} else {
			push @$status, { 'error' => 'Grant Type Not Supported. Valid grant type: password' };
		}
	} else {
		push @$status, { 'error' => 'Login Not Allowed At This Time.' };
	}
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,1,0);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => { 'first_name' => $first_name, 'last_name' => $last_name, 'cookie' =>$cookie },
		'datafiles' => []
	};
	return $response;
}

sub logout {
	my $self = shift;
	my $login_controller = CXGN::Login->new($self->bcs_schema->storage->dbh);
	my $status = $self->status;
	$login_controller->logout_user();
	push @$status, { 'success' => 'User Logged Out'};
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,1,0);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => {},
		'datafiles' => []
	};
	return $response;
}

1;

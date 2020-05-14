package CXGN::BrAPI::v2::Authentication;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

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
				return CXGN::BrAPI::JSONResponse->return_error($status, 'Account Disabled');
			}
			if ($login_info->{incorrect_password}) {
				return CXGN::BrAPI::JSONResponse->return_error($status, 'Incorrect Password');
			}
			if ($login_info->{duplicate_cookie_string}) {
				return CXGN::BrAPI::JSONResponse->return_error($status, 'Duplicate Cookie String');
			}
			if ($login_info->{logins_disabled}) {
				return CXGN::BrAPI::JSONResponse->return_error($status, 'Logins Disabled');
			}
			if ($login_info->{person_id}) {
				my %result = ( 'userDisplayName' => $login_info->{first_name}." ".$login_info->{last_name}, 'access_token' =>$login_info->{cookie_string} );
				my @data_files;
				my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,1,0);
				return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Login Successfull');
			}
		} else {
			return CXGN::BrAPI::JSONResponse->return_error($status, 'Grant Type Not Supported. Valid grant type: password');
		}
	} else {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'Login Not Allowed At This Time.');
	}
}

sub logout {
	my $self = shift;
	my $login_controller = CXGN::Login->new($self->bcs_schema->storage->dbh);
	my $status = $self->status;
	$login_controller->logout_user();
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,1,0);
	my %result;
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'User Logged Out');
}

1;

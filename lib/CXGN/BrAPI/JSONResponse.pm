package CXGN::BrAPI::JSONResponse;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;

sub return_error {
	my $self = shift;
	my $status = shift;
	my $message = shift;
	push @$status, { 'error' => $message };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,1,0);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => undef,
		'datafiles' => []
	};
	return $response;
}

sub return_success {
	my $self = shift;
	my $result = shift;
	my $pagination = shift;
	my $data_files = shift;
	my $status = shift;
	my $message = shift;
	push @$status, { 'success' => $message };
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => $result,
		'datafiles' => $data_files
	};
	return $response;
}

1;

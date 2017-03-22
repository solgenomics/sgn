package CXGN::BrAPI::ErrorResponse;

use Moose;
use Data::Dumper;

sub return_error {
	my $self = shift;
	my $status = shift;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,1,0);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => undef,
		'datafiles' => []
	};
	return $response;
}

1;

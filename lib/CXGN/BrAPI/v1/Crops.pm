package CXGN::BrAPI::v1::Crops;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;

has 'page_size' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'page' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'status' => (
	isa => 'ArrayRef[Maybe[HashRef]]',
	is => 'rw',
	required => 1,
);

sub crops {
	my $self = shift;
	my $supported_crop = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;

	my $status = $self->status;
	my @available = (
		$supported_crop
	);

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@available, $page_size, $page);
	my %result = (data=>$data_window);
	push @$status, { 'success' => 'Crops result constructed' };
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

1;

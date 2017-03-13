package CXGN::BrAPI::v1::Crops;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;

has 'status' => ( isa => 'ArrayRef[Maybe[HashRef]]',
	is => 'rw',
	required => 1,
);

sub crops {
	my $self = shift;
	my $supported_crop = shift;
	my $page_size = shift;
	my $page = shift;

	my $status = $self->status;
	my @available = (
		$supported_crop
	);

	my @data;
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($available[$i]) {
			push @data, $available[$i];
		}
	}

	my $total_count = scalar(@available);
	my %result = (data=>\@data);
	push @$status, { 'success' => 'Crops result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

1;

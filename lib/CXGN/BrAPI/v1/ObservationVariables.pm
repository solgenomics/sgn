package CXGN::BrAPI::v1::ObservationVariables;

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

sub observation_levels {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;

	my $status = $self->status;
	my @available = (
		'plant','plot','all'
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
	push @$status, { 'success' => 'Observation Levels result constructed' };
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

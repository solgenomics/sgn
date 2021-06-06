package CXGN::BrAPI::Pagination;

use Moose;
use Data::Dumper;

sub pagination_response {
	my $self = shift;
	my $data_count = shift;
	my $page_size = shift;
	my $page = shift;

	$page_size += 0; # convert from string to int
	$page += 0; # convert from string to int?

	my $total_pages_decimal = $data_count/$page_size;
	my $total_pages = ($total_pages_decimal == int $total_pages_decimal) ? $total_pages_decimal : int($total_pages_decimal + 1);
	my %pagination = (pageSize=>$page_size, currentPage=>$page, totalCount=>$data_count, totalPages=>$total_pages);
	return \%pagination;
}

sub paginate_array {
	my $self = shift;
	my $data = shift;
	my $page_size = shift;
	my $page = shift;
	my $total_count = $data ? scalar(@$data) : 0;
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	my @data_window;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($data->[$i]) {
			push @data_window, $data->[$i];
		}
	}
	my $pagination = $self->pagination_response($total_count, $page_size, $page);
	return (\@data_window, $pagination);
}

1;

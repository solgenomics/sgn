package CXGN::BrAPI::v1::Locations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v1::Common';

sub search {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $locations = CXGN::Trial::get_all_locations($self->bcs_schema);
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($locations,$page_size,$page);
	my @data;
	foreach (@$data_window){
		push @data, {
			locationDbId => qq|$_->[0]|,
			locationType=> $_->[8],
			locationName=> $_->[1],
			name=> $_->[1],
			abbreviation=>$_->[9],
			countryCode=> $_->[6],
			countryName=> $_->[5],
			latitude=>$_->[2],
			longitude=>$_->[3],
			altitude=>$_->[4],
            instituteName=>'',
            instituteAddress=>$_->[10],
			additionalInfo=> $_->[7],
			documentationURL=> undef
		};
	}

	my %result = (data=>\@data);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Locations list result constructed');
}


1;

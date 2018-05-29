package CXGN::BrAPI::v1::Locations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

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

sub locations_list {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $locations = CXGN::Trial::get_all_locations($self->bcs_schema);
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($locations,$page_size,$page);
	my @data;
	foreach (@$data_window){
		push @data, {
			locationDbId => $_->[0],
			locationType=> $_->[8],
			name=> $_->[1],
			abbreviation=>$_->[9],
			countryCode=> $_->[6],
			countryName=> $_->[5],
			latitude=>$_->[2],
			longitude=>$_->[3],
			altitude=>$_->[4],
            instituteName=>'',
            instituteAddress=>$_->[10],
			additionalInfo=> $_->[7]
		};
	}

	my %result = (data=>\@data);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Locations list result constructed');
}


1;

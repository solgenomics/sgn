package CXGN::BrAPI::v1::Locations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'metadata_schema' => (
	isa => 'CXGN::Metadata::Schema',
	is => 'rw',
	required => 1,
);

has 'phenome_schema' => (
	isa => 'CXGN::Phenome::Schema',
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
	my @data;
    my $total_count = scalar(@$locations);
    my $start = $page_size*$page;
    my $end = $page_size*($page+1)-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$locations[$i]) {
            push @data, {
                locationDbId => @$locations[$i]->[0],
                locationType=> @$locations[$i]->[8],
                name=> @$locations[$i]->[1],
                abbreviation=>@$locations[$i]->[9],
                countryCode=> @$locations[$i]->[6],
                countryName=> @$locations[$i]->[5],
                latitude=>@$locations[$i]->[2],
                longitude=>@$locations[$i]->[3],
                altitude=>@$locations[$i]->[4],
                additionalInfo=> @$locations[$i]->[7]
            };
        }
    }

    my %result = (data=>\@data);
	push @$status, { 'success' => 'Locations list result constructed' };
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

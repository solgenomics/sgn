package CXGN::BrAPI::v1::Calls;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

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

sub calls {
	my $self = shift;
	my $datatype_param = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;

	my $status = $self->status;
	my @available = (
		['token', ['json'], ['POST','DELETE'] ],
		['calls', ['json'], ['GET'] ],
		['observationLevels', ['json'], ['GET'] ],
		['germplasm-search', ['json'], ['GET','POST'] ],
		['germplasm/id', ['json'], ['GET'] ],
		['germplasm/id/pedigree', ['json'], ['GET'] ],
		['germplasm/id/progeny', ['json'], ['GET'] ],
		['germplasm/id/markerprofiles', ['json'], ['GET'] ],
		['germplasm/id/attributes', ['json'], ['GET'] ],
		['attributes', ['json'], ['GET'] ],
		['attributes/categories', ['json'], ['GET'] ],
		['markerprofiles', ['json'], ['GET'] ],
		['markerprofiles/id', ['json'], ['GET'] ],
		['markerprofiles/methods', ['json'], ['GET'] ],
		['allelematrix-search', ['json','tsv','csv','xls'], ['GET','POST'] ],
		['programs', ['json'], ['GET'] ],
		['crops', ['json'], ['GET'] ],
		['seasons', ['json'], ['GET','POST'] ],
		['studyTypes', ['json'], ['GET','POST'] ],
		['trials', ['json'], ['GET','POST'] ],
		['trials/id', ['json'], ['GET'] ],
		['studies-search', ['json'], ['GET','POST'] ],
		['studies/id', ['json'], ['GET'] ],
		['studies/id/germplasm', ['json'], ['GET'] ],
		['studies/id/observationVariables', ['json'], ['GET'] ],
		['studies/id/observationunits', ['json'], ['GET'] ],
		['studies/id/table', ['json','csv','xls','tsv'], ['GET'] ],
		['studies/id/layout', ['json'], ['GET'] ],
		['studies/id/observations', ['json'], ['GET'] ],
		['phenotypes-search', ['json'], ['GET','POST'] ],
		['traits', ['json'], ['GET'] ],
		['traits/id', ['json'], ['GET'] ],
		['maps', ['json'], ['GET'] ],
		['maps/id', ['json'], ['GET'] ],
		['maps/id/positions', ['json'], ['GET'] ],
		['maps/id/positions/id', ['json'], ['GET'] ],
		['locations', ['json'], ['GET'] ],
		['variables/datatypes', ['json'], ['GET'] ],
		['ontologies', ['json'], ['GET'] ],
		['variables', ['json'], ['GET'] ],
		['variables/id', ['json'], ['GET'] ],
		['variables-search', ['json'], ['GET','POST'] ],
		['samples/id', ['json'], ['GET'] ],
	);

	my @call_search;
	if ($datatype_param){
		foreach my $a (@available){
			foreach (@{$a->[1]}){
				if ($_ eq $datatype_param){
					push @call_search, $a;
				}
			}
		}
	} else {
		@call_search = @available;
	}

	my @data;
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@call_search, $page_size, $page);
	foreach (@$data_window){
		push @data, {
			call=>$_->[0],
			datatypes=>$_->[1],
			methods=>$_->[2]
		};
	}
	my %result = (data=>\@data);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Calls result constructed');
}

1;

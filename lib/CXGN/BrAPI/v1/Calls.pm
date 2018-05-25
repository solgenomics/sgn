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

    $page_size = 1000;

	my $status = $self->status;
	my @available = (
		['token', ['json'], ['POST','DELETE'], ['1.0'] ],
		['calls', ['json'], ['GET'], ['1.0'] ],
		['observationlevels', ['json'], ['GET'], ['1.0'] ],
		['germplasm-search', ['json'], ['GET','POST'], ['1.0'] ],
		['germplasm/id', ['json'], ['GET'], ['1.0'] ],
		['germplasm/id/pedigree', ['json'], ['GET'], ['1.0','1.2'] ],
		['germplasm/id/progeny', ['json'], ['GET'], ['1.0','1.2'] ],
		['germplasm/id/markerprofiles', ['json'], ['GET'], ['1.0'] ],
		['germplasm/id/attributes', ['json'], ['GET'], ['1.0'] ],
		['attributes', ['json'], ['GET'], ['1.0'] ],
		['attributes/categories', ['json'], ['GET'], ['1.0'] ],
		['markerprofiles', ['json'], ['GET'], ['1.0'] ],
		['markerprofiles/id', ['json'], ['GET'], ['1.0'] ],
		['markerprofiles/methods', ['json'], ['GET'], ['1.0'] ],
		['allelematrix-search', ['json','tsv','csv','xls'], ['GET','POST'], ['1.0'] ],
		['programs', ['json'], ['GET','POST'], ['1.0'] ],
		['crops', ['json'], ['GET'], ['1.0'] ],
		['seasons', ['json'], ['GET','POST'], ['1.0'] ],
		['studytypes', ['json'], ['GET','POST'], ['1.0'] ],
		['trials', ['json'], ['GET','POST'], ['1.0'] ],
		['trials/id', ['json'], ['GET'], ['1.0'] ],
		['studies-search', ['json'], ['GET','POST'], ['1.0'] ],
		['studies/id', ['json'], ['GET'], ['1.0'] ],
		['studies/id/germplasm', ['json'], ['GET'], ['1.0'] ],
		['studies/id/observationvariables', ['json'], ['GET'], ['1.0'] ],
		['studies/id/observationunits', ['json'], ['GET'], ['1.0'] ],
		['studies/id/table', ['json','csv','xls','tsv'], ['GET'], ['1.0'] ],
		['studies/id/layout', ['json'], ['GET'], ['1.0'] ],
		['studies/id/observations', ['json'], ['GET'], ['1.0'] ],
		['phenotypes-search', ['json'], ['GET','POST'], ['1.0'] ],
		['traits', ['json'], ['GET'], ['1.0'] ],
		['traits/id', ['json'], ['GET'], ['1.0'] ],
		['maps', ['json'], ['GET'], ['1.0'] ],
		['maps/id', ['json'], ['GET'], ['1.0'] ],
		['maps/id/positions', ['json'], ['GET'], ['1.0'] ],
		['maps/id/positions/id', ['json'], ['GET'], ['1.0'] ],
		['locations', ['json'], ['GET'], ['1.0'] ],
		['variables/datatypes', ['json'], ['GET'], ['1.0'] ],
		['ontologies', ['json'], ['GET'], ['1.0'] ],
		['variables', ['json'], ['GET'], ['1.0'] ],
		['variables/id', ['json'], ['GET'], ['1.0'] ],
		['variables-search', ['json'], ['GET','POST'], ['1.0'] ],
		['samples-search', ['json'], ['GET','POST'], ['1.0'] ],
		['samples/id', ['json'], ['GET'], ['1.0'] ],
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
			methods=>$_->[2],
            versions=>$_->[3]
		};
	}
	my %result = (data=>\@data);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Calls result constructed');
}

1;

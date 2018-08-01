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
		['token', ['json'], ['POST','DELETE'], ['1.0','1.2'] ],
		['calls', ['json'], ['GET'], ['1.0','1.2'] ],
		['observationlevels', ['json'], ['GET'], ['1.0','1.2'] ],
		['germplasm-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['germplasm/{germplasmDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['germplasm/{germplasmDbId}/pedigree', ['json'], ['GET'], ['1.0','1.2'] ],
		['germplasm/{germplasmDbId}/progeny', ['json'], ['GET'], ['1.0','1.2'] ],
		['germplasm/{germplasmDbId}/markerprofiles', ['json'], ['GET'], ['1.0','1.2'] ],
		['germplasm/{germplasmDbId}/attributes', ['json'], ['GET'], ['1.0','1.2'] ],
		['attributes', ['json'], ['GET'], ['1.0','1.2'] ],
		['attributes/categories', ['json'], ['GET'], ['1.0','1.2'] ],
		['markerprofiles', ['json'], ['GET'], ['1.0','1.2'] ],
		['markerprofiles/{markerprofileDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['markerprofiles/methods', ['json'], ['GET'], ['1.0','1.2'] ],
		['allelematrix-search', ['json','tsv','csv','xls'], ['GET','POST'], ['1.0','1.2'] ],
		['allelematrices-search', ['json','tsv','csv','xls'], ['GET','POST'], ['1.0','1.2'] ],
		['programs', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['crops', ['json'], ['GET'], ['1.0','1.2'] ],
		['seasons', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['studytypes', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['trials', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['trials/{trialDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['studies-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['studies/{studyDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['studies/{studyDbId}/germplasm', ['json'], ['GET'], ['1.0','1.2'] ],
		['studies/{studyDbId}/observationvariables', ['json'], ['GET'], ['1.0','1.2'] ],
		['studies/{studyDbId}/observationunits', ['json'], ['GET'], ['1.0','1.2'] ],
		['studies/{studyDbId}/table', ['json','csv','xls','tsv'], ['GET'], ['1.0','1.2'] ],
		['studies/{studyDbId}/layout', ['json'], ['GET'], ['1.0','1.2'] ],
		['studies/{studyDbId}/observations', ['json'], ['GET'], ['1.0','1.2'] ],
		['phenotypes-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['phenotypes-search/table', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['phenotypes-search/tsv', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['phenotypes-search/csv', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['traits', ['json'], ['GET'], ['1.0','1.2'] ],
		['traits/{traitDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['maps', ['json'], ['GET'], ['1.0','1.2'] ],
		['maps/{mapDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['maps/{mapDbId}/positions', ['json'], ['GET'], ['1.0','1.2'] ],
		['maps/{mapDbId}/positions/id', ['json'], ['GET'], ['1.0','1.2'] ],
		['locations', ['json'], ['GET'], ['1.0','1.2'] ],
		['variables/datatypes', ['json'], ['GET'], ['1.0','1.2'] ],
		['ontologies', ['json'], ['GET'], ['1.0','1.2'] ],
		['variables', ['json'], ['GET'], ['1.0','1.2'] ],
		['variables/{observationVariableDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['variables-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['samples-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['samples/{sampleDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
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

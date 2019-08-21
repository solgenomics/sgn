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
		['token', ['json'], ['POST','DELETE'], ['1.0','1.2','1.3'] ],
		['calls', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['observationlevels', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['germplasm-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/germplasm', ['json'], ['GET','POST'], ['1.3'] ],
		['germplasm', ['json'], ['GET'], ['1.3'] ],
		['germplasm/{germplasmDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['germplasm/{germplasmDbId}/pedigree', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['germplasm/{germplasmDbId}/progeny', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['germplasm/{germplasmDbId}/markerprofiles', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['germplasm/{germplasmDbId}/attributes', ['json'], ['GET'], ['1.0','1.2'] ],
		['attributes', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['attributes/categories', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['markerprofiles', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['markerprofiles/{markerprofileDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['markerprofiles/methods', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['allelematrix-search', ['json','tsv','csv','xls'], ['GET','POST'], ['1.0','1.2'] ],
		['search/allelematrix', ['json'], ['GET','POST'], ['1.3'] ],
		['allelematrix', ['json'], ['GET'], ['1.3'] ],
		['allelematrices-search', ['json','tsv','csv','xls'], ['GET','POST'], ['1.0','1.2'] ],
		['search/allelematrices', ['json'], ['GET','POST'], ['1.3'] ],
		['allelematrices', ['json'], ['GET'], ['1.3'] ],
		['programs', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['crops', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['seasons', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['studytypes', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['trials', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['trials/{trialDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['search/studies', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/germplasm', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/observationvariables', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/observationunits', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/table', ['json','csv','xls','tsv'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/layout', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/observations', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['phenotypes-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/phenotypes', ['json'], ['GET','POST'], ['1.3'] ],
		['phenotypes', ['json'], ['GET'], ['1.3'] ],
		['phenotypes-search/table', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/phenotypes/table', ['json'], ['GET','POST'], ['1.3'] ],
		['phenotypes/table', ['json'], ['GET'], ['1.3'] ],
		['phenotypes-search/tsv', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/phenotypes/tsv', ['json'], ['GET','POST'], ['1.3'] ],
		['phenotypes/tsv', ['json'], ['GET'], ['1.3'] ],
		['phenotypes-search/csv', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/phenotypes/csv', ['json'], ['GET','POST'], ['1.3'] ],
		['phenotypes/csv', ['json'], ['GET'], ['1.3'] ],
		['traits', ['json'], ['GET'], ['1.0','1.2'] ],
		['traits/{traitDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['maps', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['maps/{mapDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['maps/{mapDbId}/positions', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['maps/{mapDbId}/positions/id', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['locations', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['variables/datatypes', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['ontologies', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['variables', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['variables/{observationVariableDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['variables-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/variables', ['json'], ['GET','POST'], ['1.3'] ],
		['variables', ['json'], ['GET'], ['1.3'] ],
		['samples-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/samples', ['json'], ['GET','POST'], ['1.3'] ],
		['samples', ['json'], ['GET'], ['1.3'] ],
		['samples/{sampleDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
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

package CXGN::BrAPI::v1::Calls;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v1::Common';

sub search {
	my $self = shift;
	my $inputs = shift;
	my $datatype_param = $inputs->{datatype}->[0];
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
		['allelematrices-search', ['json','tsv','csv','xls'], ['GET','POST'], ['1.0','1.2'] ],
		['search/allelematrices', ['json'], ['GET','POST'], ['1.3'] ],
		['allelematrices', ['json'], ['GET'], ['1.3'] ],
		['programs', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['crops', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['seasons', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['studytypes', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['trials', ['json'], ['GET','POST'], ['1.0','1.2','1.3'] ],
		['trials/{trialDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/studies', ['json'], ['GET','POST'], ['1.3'] ],
		['studies', ['json'], ['GET'], ['1.3'] ],
		['studies/{studyDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/germplasm', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/observationvariables', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/observationunits', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/table', ['json','csv','xls','tsv'], ['GET'], ['1.0','1.2','1.3'] ],
		['studies/{studyDbId}/layout', ['json'], ['GET'], ['1.0','1.2'] ],
		['studies/{studyDbId}/layouts', ['json'], ['GET'], ['1.3'] ],
		['studies/{studyDbId}/observations', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['phenotypes-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/phenotypes', ['json'], ['GET','POST'], ['1.3'] ],
		['phenotypes', ['json'], ['GET','POST'], ['1.3'] ],
		['phenotypes-search/table', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['phenotypes-search/tsv', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['phenotypes-search/csv', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['observationunits', ['json'], ['GET'], ['1.3'] ],
		['search/observationunits', ['json'], ['GET','POST'], ['1.3'] ],
		['observationtables', ['json'], ['GET'], ['1.3'] ],
		['search/observationtables', ['json'], ['GET','POST'], ['1.3'] ],
		['traits', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['traits', ['json'], ['POST'], ['1.3'] ],
		['traits/{traitDbId}', ['json'], ['GET'], ['1.0','1.2'] ],
		['traits/{traitDbId}', ['json'], ['PUT'], ['1.3'] ],
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
		['samples-search', ['json'], ['GET','POST'], ['1.0','1.2'] ],
		['search/samples', ['json'], ['GET','POST'], ['1.3'] ],
		['samples', ['json'], ['GET'], ['1.3'] ],
		['samples/{sampleDbId}', ['json'], ['GET'], ['1.0','1.2','1.3'] ],
		['images', ['json'],['GET','POST'], ['1.3']],
		['images/{imageDbId}', ['json'], ['GET','PUT'], ['1.3']],
		['images/{imageDbId}/imagecontent', ['json'], ['PUT'], ['1.3']],
		['lists', ['json'], ['GET','POST'],['1.3']],
		['lists/{listDbId}',['json'], ['GET','PUT'], ['1.3']],
		['lists/{listDbId}/items',['json'], ['POST'], ['1.3']],
		['markers',['json'], ['GET'], ['1.0', '1.3']],
		['markers/{markerDbId}',['json'], ['GET'],[ '1.0', '1.1', '1.2', '1.3']],
		['methods',['json'], ['GET','POST'], ['1.3']],
		['methods/{methodDbId}',['json'], ['GET','PUT'], ['1.3']],
		['people',['json'], ['GET', 'POST'],['1.3']],
		['people/{personDbId}', ['json'], ['GET','PUT'], ['1.3']],
		['scales', ['json'], ['GET','POST'], ['1.3']],
		['scales/{scaleDbId}', ['json'], ['GET','PUT'],['1.3']],
		['search/germplasm/{searchResultsDbId}', ['json'], ['GET'], ['1.3']],
		['search/images', ['json'], ['POST'], ['1.3']],
		['search/images/{searchResultsDbId}', ['json'], ['GET'], ['1.3']],
		['search/markers', ['json'], ['POST'], ['1.3']],
		['search/markers/{searchResultsDbId}', ['json'], ['GET'], ['1.3']],
		['search/observationtables/{searchResultsDbId}', ['json'], ['GET'], ['1.3']],
		['search/observationunits/searchResultsDbId', ['json'], ['GET'], ['1.3']],
		['search/programs', ['json'], ['POST'], ['1.3']],
		['search/programs/{searchResultsDbId}', ['json'], ['GET'], ['1.3']],
		['search/samples/{searchResultsDbId}', ['json'], ['GET'], ['1.3']],
		['search/studies/{searchResultsDbId}', ['json'], ['GET'], ['1.3']],
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

package CXGN::BrAPI::v1::Calls;

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
		['germplasm/id/markerprofiles', ['json'], ['GET'] ],
		['germplasm/id/attributes', ['json'], ['GET'] ],
		['attributes', ['json'], ['GET'] ],
		['attributes/categories', ['json'], ['GET'] ],
		['markerprofiles', ['json'], ['GET'] ],
		['markerprofiles/id', ['json'], ['GET'] ],
		['allelematrix-search', ['json','tsv','csv'], ['GET','POST'] ],
		['programs', ['json'], ['GET'] ],
		['crops', ['json'], ['GET'] ],
		['seasons', ['json'], ['GET','POST'] ],
		['studyTypes', ['json'], ['GET','POST'] ],
		['trials', ['json'], ['GET','POST'] ],
		['trials/id', ['json'], ['GET'] ],
		['studies-search', ['json'], ['GET','POST'] ],
		['studies/id', ['json'], ['GET'] ],
		['studies/id/germplasm', ['json'], ['GET'] ],
		['studies/id/table', ['json','csv','xls'], ['GET'] ],
		['studies/id/layout', ['json'], ['GET'] ],
		['studies/id/observations', ['json'], ['GET'] ],
		['phenotypes-search', ['json'], ['GET','POST'] ],
		['traits', ['json'], ['GET'] ],
		['traits/id', ['json'], ['GET'] ],
		['maps', ['json'], ['GET'] ],
		['maps/id', ['json'], ['GET'] ],
		['maps/id/positions', ['json'], ['GET'] ],
		['locations', ['json'], ['GET'] ],
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
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($call_search[$i]) {
			push @data, {call=>$call_search[$i]->[0], datatypes=>$call_search[$i]->[1], methods=>$call_search[$i]->[2]};
		}
	}

	my $total_count = scalar(@call_search);
	my %result = (data=>\@data);
	push @$status, { 'success' => 'Calls result constructed' };
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

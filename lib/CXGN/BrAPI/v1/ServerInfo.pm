package CXGN::BrAPI::v1::ServerInfo;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v1::Common';

sub search {
	my $self = shift;
	my $c = shift;
	my $inputs = shift;
	my $datatype_param = $inputs->{datatype}->[0];
	my $page_size = $self->page_size;
	my $page = $self->page;

    $page_size = 1000;

	my $status = $self->status;
	my @available = (
		#core
		[['application/json'],['GET'],'serverinfo',['1.0']],
		[['application/json'],['GET'],'commoncropnames',['1.0']],
		[['application/json'],['GET'],'lists',['1.0']],
		[['application/json'],['GET'],'lists/{listDbId}',['1.0']],
		[['application/json'],['POST'],'search/lists',['1.0']],
		[['application/json'],['GET'],'search/lists/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'],'locations',['1.0']],
		[['application/json'],['GET'],'locations/{locationDbId}',['1.0']],
		[['application/json'],['POST'],'search/locations',['1.0']],
		[['application/json'],['GET'],'search/locations/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'],'people',['1.0']],
		[['application/json'],['GET'],'people/{peopleDbId}',['1.0']],
		[['application/json'],['POST'],'search/people',['1.0']],
		[['application/json'],['GET'],'search/people/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'],'programs',['1.0']],
		[['application/json'],['GET'],'programs/{programDbId}',['1.0']],
		[['application/json'],['POST'],'search/programs',['1.0']],
		[['application/json'],['GET'],'search/programs/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'],'seasons',['1.0']],
		[['application/json'],['GET'],'seasons/{seasonDbId}',['1.0']],
		[['application/json'],['POST'],'search/seasons',['1.0']],
		[['application/json'],['GET'],'search/seasons/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'],'studies',['1.0']],
		[['application/json'],['GET'],'studies/{studyDbId}',['1.0']],
		[['application/json'],['POST'],'search/studies',['1.0']],
		[['application/json'],['GET'],'search/studies/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'],'studytypes',['1.0']],
		[['application/json'],['GET'],'trials',['1.0']],
		[['application/json'],['GET'],'trials/{trialDbId}',['1.0']],
		[['application/json'],['POST'],'search/trials',['1.0']],
		[['application/json'],['GET'],'search/trials/{searchResultsDbId}',['1.0']],
		#phenotyping
		[['application/json'],['GET'], 'images',['1.0']],
		[['application/json'],['GET'], 'images/{imageDbId}',['1.0']],
		[['application/json'],['POST'],'search/images',['1.0']],
		[['application/json'],['GET'], 'search/images/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET','POST','PUT'], 'observations',['1.0']],
		[['application/json'],['GET','PUT'], 'observations/{observationDbId}',['1.0']],
		[['application/json'],['POST'],'search/observations',['1.0']],
		[['application/json'],['GET'], 'search/observations/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'observationlevels',['1.0']],
		[['application/json'],['GET'], 'observationunits',['1.0']],
		[['application/json'],['GET','PUT'], 'observationunits/{observationUnitDbId}',['1.0']],
		[['application/json'],['POST'],'search/observationunits',['1.0']],
		[['application/json'],['GET'], 'search/observationunits/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'ontologies',['1.0']],
		[['application/json'],['GET'], 'traits',['1.0']],
		[['application/json'],['GET'], 'traits/{traitDbId}',['1.0']],
		[['application/json'],['GET'], 'variables',['1.0']],
		[['application/json'],['GET'], 'variables/{observationVariableDbId}',['1.0']],
		[['application/json'],['POST'],'search/variables',['1.0']],
		[['application/json'],['GET'], 'search/variables/{searchResultsDbId}',['1.0']],
		#genotyping
		[['application/json'],['GET'], 'calls',['1.0']],
		[['application/json'],['POST'],'search/calls',['1.0']],
		[['application/json'],['GET'], 'search/calls/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'callsets',['1.0']],
		[['application/json'],['GET'], 'callsets/{callSetDbId}',['1.0']],
		[['application/json'],['GET'], 'callsets/{callSetDbId}/calls',['1.0']],
		[['application/json'],['POST'],'search/callsets',['1.0']],
		[['application/json'],['GET'], 'search/callsets/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'maps',['1.0']],
		[['application/json'],['GET'], 'maps/{mapDbId}',['1.0']],
		[['application/json'],['GET'], 'maps/{mapDbId}/linkagegroups',['1.0']],
		[['application/json'],['GET'], 'markerpositions',['1.0']],
		[['application/json'],['POST'],'search/markerpositions',['1.0']],
		[['application/json'],['GET'], 'search/markerpositions/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'references',['1.0']],
		[['application/json'],['GET'], 'references/{referenceDbId}',['1.0']],
		[['application/json'],['POST'],'search/references',['1.0']],
		[['application/json'],['GET'], 'search/references/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'referencesets',['1.0']],
		[['application/json'],['GET'], 'referencesets/{referenceSetDbId}',['1.0']],
		[['application/json'],['POST'],'search/referencesets',['1.0']],
		[['application/json'],['GET'], 'search/referencesets/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'samples',['1.0']],
		[['application/json'],['GET'], 'samples/{sampleDbId}',['1.0']],
		[['application/json'],['POST'],'search/samples',['1.0']],
		[['application/json'],['GET'], 'search/samples/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'variants',['1.0']],
		[['application/json'],['GET'], 'variants/{variantDbId}',['1.0']],
		[['application/json'],['GET'], 'variants/{variantDbId}/calls',['1.0']],
		[['application/json'],['POST'],'search/variants',['1.0']],
		[['application/json'],['GET'], 'search/variants/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET'], 'variantsets',['1.0']],
		[['application/json'],['GET'], 'variantsets/extract',['1.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}',['1.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}/calls',['1.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}/callsets',['1.0']],
		[['application/json'],['GET'], 'variantsets/{variantSetDbId}/variants',['1.0']],
		[['application/json'],['POST'],'search/variantsets',['1.0']],
		[['application/json'],['GET'], 'search/variantsets/{searchResultsDbId}',['1.0']],
		#Germplasm
		[['application/json'],['GET'], 'germplasm',['1.0']],
		[['application/json'],['GET'], 'germplasm/{germplasmDbId}',['1.0']],
		[['application/json'],['GET'], 'germplasm/{germplasmDbId}/pedigree',['1.0']],
		[['application/json'],['GET'], 'germplasm/{germplasmDbId}/progeny',['1.0']],
		[['application/json'],['POST'],'search/germplasm',['1.0']],
		[['application/json'],['GET'], 'search/germplasm/{searchResultsDbId}',['1.0']],
		[['application/json'],['GET','POST'], 'crossingprojects',['1.0']],
		[['application/json'],['GET','PUT'], 'crossingprojects/{crossingProjectDbId}',['1.0']],
		[['application/json'],['GET','POST'], 'crosses',['1.0']],
		[['application/json'],['GET','POST'], 'seedlots',['1.0']],
		[['application/json'],['GET','POST'], 'seedlots/transactions',['1.0']],
		[['application/json'],['GET','PUT'], 'seedlots/{seedLotDbId}',['1.0']],
		[['application/json'],['GET'], 'seedlots/{seedLotDbId}/transactions',['1.0']],
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
			datatypes=>$_->[0],
			methods=>$_->[1],
			service=>$_->[2],
            versions=>$_->[3]
		};
		
	}
	my $permissions = info();
	my %result = (
		calls=>\@data,
		contactEmail=>"lam87\@cornell.edu",
		documentationURL=>"https://solgenomics.github.io/sgn/",
		location=>"USA",
		organizationName=>"Boyce Thompson Institute",
		organizationURL=>$c->request->{"base"},
		serverDescription=>"BrAPI v1.0 compliant server",
		serverName=>$c->config->{project_name},
		permissions=>$permissions,
	);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Calls result constructed');
}

sub info {
	my $permissions  = {
				'GET' => 'any',
				'POST' => 'any',
				'PUT' => 'any'
			};

	return $permissions;
}

1;

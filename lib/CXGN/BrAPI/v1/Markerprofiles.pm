package CXGN::BrAPI::v1::Markerprofiles;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Genotype::Search;
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

sub markerprofiles_search {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @germplasm_ids = $inputs->{stock_ids} ? @{$inputs->{stock_ids}} : ();
	my @study_ids = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
	my @extract_ids = $inputs->{extract_ids} ? @{$inputs->{extract_ids}} : ();
	my @sample_ids = $inputs->{sample_ids} ? @{$inputs->{sample_ids}} : ();
	my $method = $inputs->{protocol_id};
	
	if (scalar(@extract_ids)>0){
		push @$status, { 'error' => 'Search parameter extractDbId not supported' };
	}
	if (scalar(@sample_ids)>0){
		push @$status, { 'error' => 'Search parameter sampleDbId not supported' };
	}

	my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$self->bcs_schema,
        accession_list=>\@germplasm_ids,
        trial_list=>\@study_ids,
        protocol_id=>$method,
        offset=>$page_size*$page,
        limit=>$page_size*($page+1)-1
    });
    my ($total_count, $genotypes) = $genotypes_search->get_genotype_info();

	my @data;
    foreach (@$genotypes){
        push @data, {
            markerProfileDbId => $_->{markerProfileDbId},
            germplasmDbId => $_->{germplasmDbId},
            uniqueDisplayName => $_->{genotypeUniquename},
            extractDbId => $_->{genotypeUniquename},
            sampleDbId => $_->{genotypeUniquename},
            analysisMethod => $_->{analysisMethod},
            resultCount => $_->{resultCount}
        };
    }

    my %result = (data => \@data);
	push @$status, { 'success' => 'Markerprofiles-search result constructed' };
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

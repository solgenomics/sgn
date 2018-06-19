package CXGN::BrAPI::v1::Observations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::Chado::Organism;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

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

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
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

sub observations_store {
    my $self = shift;
    my @observations = $search_params->{observations} ? @{$search_params->{observations}} : ();

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    # Implement observation store here using CXGN::Phenotypes::StorePhenotypes
    
    my @data;
    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations result constructed');
}

sub observations_search {
    my $self = shift;
    my $search_params = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my @collectors = $search_params->{collectors} ? @{$search_params->{collectors}} : ();
    my @observation_db_ids = $search_params->{observationDbIds} ? @{$search_params->{observationDbIds}} : ();
    my @observation_unit_db_ids = $search_params->{observationUnitDbIds} ? @{$search_params->{observationUnitDbIds}} : ();
    my @observation_variable_db_ids = $search_params->{observationVariableDbIds} ? @{$search_params->{observationVariableDbIds}} : ();

    #implement observation search here using stock search

    my @data;
    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations-search result constructed');
}

1;

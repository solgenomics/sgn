package CXGN::BrAPI::v1::Observations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::Chado::Organism;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileRequest;
use utf8;
use JSON;

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
    my $search_params = shift;
    my $observations = $search_params->{observations} ? $search_params->{observations} : ();

    print STDERR "Observations are ". Dumper($observations) . "\n";

    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $user_id = $search_params->{user_id};
    my $username = $search_params->{username};
    my $user_type = $search_params->{user_type};
    my $archive_path = $search_params->{archive_path};
    my @error_status = [];
    my @success_status = [];

    print STDERR "OBSERVATIONS_MODULE: User id is $user_id and type is $user_type\n";

    if ($user_type ne 'submitter' && $user_type ne 'sequencer' && $user_type ne 'curator') {
        push @error_status, 'Must have submitter privileges to upload phenotypes! Please contact us!';
        return (\@success_status, \@error_status);
    }

    #validate request structure and parse data
    my $timestamp_included = 1;
    my $data_level = 'stocks';

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_request = $parser->validate('brapi observations', $observations, $timestamp_included, $data_level, $schema);
    if (!$validate_request) {
        print STDERR "Error parsing request structure.";
        push @error_status, "Error parsing request structure.";
        return (\@success_status, \@error_status);
    }
    if ($validate_request == 1){
        push @success_status, "Request structure is valid.";
    } else {
        if ($validate_request->{'error'}) {
            print STDERR $validate_request->{'error'};
            push @error_status, $validate_request->{'error'};
        }
        return (\@success_status, \@error_status);
    }

    my $parsed_request = $parser->parse('brapi observations', $observations, $timestamp_included, $data_level, $schema);
    #
    if (!$parsed_request) {
        print STDERR "Error parsing request data.";
        push @error_status, "Error parsing request data.";
        return (\@success_status, \@error_status);
    }
    if ($parsed_request == 1){
        push @success_status, "Request data is valid.";
    } else {
        if ($parsed_request->{'error'}) {
            print STDERR $parsed_request->{'error'};
            push @error_status, $parsed_request->{'error'};
            return (\@success_status, \@error_status);
        }
    }

    my %parsed_data;
    my @units;
    my @variables;

    print STDERR "Defining stocks (observationUnits) and traits (observationVariables) from parsed request";
    if ($parsed_request && !$parsed_request->{'error'}) {
        %parsed_data = %{$parsed_request->{'data'}};
        @units = @{$parsed_request->{'units'}};
        @variables = @{$parsed_request->{'variables'}};
        push @success_status, "Request data is valid.";
    }

    #archive in file

    my $archived_request = CXGN::BrAPI::FileRequest->new({
        schema=>$schema,
        user_id => $user_id,
        user_type => $user_type,
        archive_path => $archive_path,
        format => 'observations',
        data => $observations
    });

    my $file = $archived_request->get_path();

    print STDERR "Archived Request is in $file\n";

    ## Store observations and return details for response

    ## Set metadata
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    $phenotype_metadata{'archived_file'} = $file;
    $phenotype_metadata{'archived_file_type'} = 'brapi observations';
    # $phenotype_metadata{'operator'} = $username;
    $phenotype_metadata{'date'} = $timestamp;

    my $store_observations = CXGN::Phenotypes::StoreObservations->new(
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        unit_list=>\@units,
        variable_list=>\@variables,
        data=>\%parsed_data,
        # has_timestamps=>$timestamp_included,
        # overwrite_values=>0,
        metadata_hash=>\%phenotype_metadata
    );

    # my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    #
    # if ($verified_error) {
    #     print STDERR "Error: $verified_error\n";
    # }
    # if ($verified_warning) {
    #     print STDERR "Warning: $verified_warning\n";
    # }

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_observations->store();

    if ($stored_phenotype_error) {
        print STDERR "Error: $stored_phenotype_error\n";
    }
    if ($stored_phenotype_success) {
        print STDERR "Success: $stored_phenotype_success\n";
    }

    # will need to initiate refresh matviews in controller instead
    # my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    # my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    my $total_count = 1;
    my @data;
    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations-search result constructed');

}

=comment
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
=cut

1;

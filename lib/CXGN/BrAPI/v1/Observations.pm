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

    print STDERR "OBSERVATIONS_MODULE: User id is $user_id and type is $user_type\n";

    my $archived_file = CXGN::BrAPI::FileRequest->new({
        schema=>$schema,
        user_id => $user_id,
        user_type => $user_type,
        archive_path => $archive_path,
        format => 'Fieldbook',  # use fieldbook database.csv format for observations data
        data => $observations
    });

    my $file = $archived_file->get_path();

    print STDERR "Archived File is in $file\n";

    # Parse file using CXGN::Phenotypes::ParseUpload
    my @error_status = [];
    my @success_status = [];
    my $validate_type = "field book";
    my $metadata_file_type = "brapi phenotype file";
    my $timestamp_included = 1;
    my $data_level = 'plots';

    if ($user_type ne 'submitter' && $user_type ne 'curator') {
        push @error_status, 'Must have submitter privileges to upload phenotypes! Please contact us!';
        return (\@success_status, \@error_status);
    }

    my $overwrite_values = 0;
    if ($overwrite_values) {
        if ($user_type ne 'curator') {
            push @error_status, 'Must be a curator to overwrite values! Please contact us!';
            return (\@success_status, \@error_status);
        }
    }

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_file = $parser->validate($validate_type, $file, $timestamp_included, $data_level, $schema);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $file.";
        return (\@success_status, \@error_status);
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $file.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        return (\@success_status, \@error_status);
    }

    ## Set metadata
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    $phenotype_metadata{'archived_file'} = $file;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    $phenotype_metadata{'operator'} = $username;
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $file, $timestamp_included, $data_level, $schema);
    if (!$parsed_file) {
        print STDERR "Error parsing file $file.";
        push @error_status, "Error parsing file $file.";
        return (\@success_status, \@error_status);
    }
    if ($parsed_file->{'error'}) {
        print STDERR $parsed_file->{'error'};
        push @error_status, $parsed_file->{'error'};
    }
    my %parsed_data;
    my @plots;
    my @traits;

        print STDERR "Defining plots and traits from parsed data";
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'plots'}};
            @traits = @{$parsed_file->{'traits'}};
            push @success_status, "File data successfully parsed.";
        }

    #print STDERR "Stock List: @plots\n Trait List: @traits\n Values Hash: ".Dumper(%parsed_data)."\n";

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots,
        trait_list=>\@traits,
        values_hash=>\%parsed_data,
        has_timestamps=>$timestamp_included,
        overwrite_values=>0,
        metadata_hash=>\%phenotype_metadata
    );

    my ($verified_warning, $verified_error) = $store_phenotypes->verify();

    if ($verified_error) {
        print STDERR "Error: $verified_error\n";
    }
    if ($verified_warning) {
        print STDERR "Warning: $verified_warning\n";
    }

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

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

package CXGN::BrAPI::v1::Observations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::Chado::Organism;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileRequest;
use CXGN::Phenotypes::StorePhenotypes;
use utf8;
use JSON;

extends 'CXGN::BrAPI::v1::Common';

sub observations_store {
    #print STDERR "OBSERVATIONS STORE.\n";
    my $self = shift;
    my $params = shift;
    my $c = shift;

    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;
    my $observations = $params->{observations};
    my $version = $params->{version};
    my $user_id = $params->{user_id};
    my $username = $params->{username};
    my $user_type = $params->{user_type};
    my $archive_path = $params->{archive_path};
    my $tempfiles_subdir = $params->{tempfiles_subdir};

    #print STDERR "Observations are ". Dumper($observations) . "\n";

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $total_count = scalar @{$observations};
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    my $status = $self->status;
    my @data = [];
    my @data_files = ();
    my %result;

    my @success_status = [];

    #print STDERR "OBSERVATIONS_MODULE: User id is $user_id and type is $user_type\n";

    #if ($user_type ne 'submitter' && $user_type ne 'sequencer' && $user_type ne 'curator') {
    if ($c->stash->{access}->denied( $user_id, "write", "phenotypes")) { 
        print STDERR 'You do not have the privileges to store phenotypes on this server.';
        return CXGN::BrAPI::JSONResponse->return_error($status, 'You must have submitter privileges to upload phenotypes! Please contact us!', 403);
    }

    ## Validate request structure and parse data
    my $timestamp_included = 1;
    my $data_level = 'stocks';

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validated_request = $parser->validate('brapi observations', $observations, $timestamp_included, $data_level, $schema, undef, undef);

    if (!$validated_request || $validated_request->{'error'}) {
        my $parse_error = $validated_request ? $validated_request->{'error'} : "Error parsing request structure";
        #print STDERR $parse_error;
        return CXGN::BrAPI::JSONResponse->return_error($status, $parse_error);
    } elsif ($validated_request->{'success'}) {
        push @$status, {'info' => $validated_request->{'success'} };
    }


    my $parsed_request = $parser->parse('brapi observations', $observations, $timestamp_included, $data_level, $schema, undef, $user_id, undef, undef);
    my %parsed_data;
    my @units;
    my @variables;

    if (!$parsed_request || $parsed_request->{'error'}) {
        my $parse_error = $parsed_request ? $parsed_request->{'error'} : "Error parsing request data";
        #print STDERR $parse_error;
        return CXGN::BrAPI::JSONResponse->return_error($status, $parse_error);
    } elsif ($parsed_request->{'success'}) {
        push @$status, {'info' => $parsed_request->{'success'} };
        #define units (observationUnits) and variables (observationVariables) from parsed request
        @units = @{$parsed_request->{'units'}};
        @variables = @{$parsed_request->{'variables'}};
        %parsed_data = %{$parsed_request->{'data'}};
        #print STDERR "Parsed data is: ".Dumper(%parsed_data)."\n";
    }

    ## Archive in file
    my $archived_request = CXGN::BrAPI::FileRequest->new({
        schema=>$schema,
        user_id => $user_id,
        user_type => $user_type,
        tempfiles_subdir => $tempfiles_subdir,
        archive_path => $archive_path,
        format => 'observations',
        data => $observations
    });

    my $response = $archived_request->get_path();
    my $file = $response->{archived_filename_with_path};
    my $archive_error_message = $response->{error_message};
    my $archive_success_message = $response->{success_message};
    if ($archive_error_message){
        return CXGN::BrAPI::JSONResponse->return_error($status, $archive_error_message);
    }
    if ($archive_success_message){
        push @$status, {'info' => $archive_success_message };
    }

    #print STDERR "Archived Request is in $file\n";

    ## Set metadata
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    $phenotype_metadata{'archived_file'} = $file;
    $phenotype_metadata{'archived_file_type'} = 'brapi observations';
    $phenotype_metadata{'date'} = $timestamp;

    ## Store observations and return details for response
    my $store_observations = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$params->{basepath},
        dbhost=>$params->{dbhost},
        dbname=>$params->{dbname},
        dbuser=>$params->{dbuser},
        dbpass=>$params->{dbpass},
        temp_file_nd_experiment_id=>$params->{temp_file_nd_experiment_id},
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@units,
        trait_list=>\@variables,
        values_hash=>\%parsed_data,
        has_timestamps=>1,
        metadata_hash=>\%phenotype_metadata,
        #image_zipfile_path=>$image_zip,
        composable_validation_check_name=>$params->{composable_validation_check_name},
        allow_repeat_measures=>$c->config->{allow_repeat_measures}
    );

    my ($stored_observation_error, $stored_observation_success, $stored_observation_details) = $store_observations->store();

    if ($stored_observation_error) {
        #print STDERR "Error: $stored_observation_error\n";
        return CXGN::BrAPI::JSONResponse->return_error($status, $stored_observation_error);
    }
    if ($stored_observation_success) {
        #print STDERR "Success: $stored_observation_success\n";
        $result{observations} = $stored_observation_details;
    }

    ## Will need to initiate refresh matviews in controller instead
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'phenotypes', 'concurrent', $c->config->{basepath});

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, $stored_observation_success);

}

# sub observations_search {
#     my $self = shift;
#     my $search_params = shift;
#
#     my $page_size = $self->page_size;
#     my $page = $self->page;
#     my $status = $self->status;
#
#     my @collectors = $search_params->{collectors} ? @{$search_params->{collectors}} : ();
#     my @observation_db_ids = $search_params->{observationDbIds} ? @{$search_params->{observationDbIds}} : ();
#     my @observation_unit_db_ids = $search_params->{observationUnitDbIds} ? @{$search_params->{observationUnitDbIds}} : ();
#     my @observation_variable_db_ids = $search_params->{observationVariableDbIds} ? @{$search_params->{observationVariableDbIds}} : ();
#
#     #implement observation search here using stock search
#
#     my @data;
#     my %result = (data => \@data);
#     my @data_files;
#     my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
#     return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations-search result constructed');
# }

1;

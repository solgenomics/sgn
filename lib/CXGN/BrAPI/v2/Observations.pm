package CXGN::BrAPI::v2::Observations;

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

extends 'CXGN::BrAPI::v2::Common';

sub observations_store {
    my $self = shift;
    my $params = shift;

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

    if ($user_type ne 'submitter' && $user_type ne 'sequencer' && $user_type ne 'curator') {
        print STDERR 'Must have submitter privileges to upload phenotypes! Please contact us!';
        push @$status, {'403' => 'Permission Denied. Must have correct privilege.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, 'Must have submitter privileges to upload phenotypes! Please contact us!');
    }

    ## Validate request structure and parse data
    my $timestamp_included = 1;
    my $data_level = 'stocks';

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validated_request = $parser->validate('brapi observations', $observations, $timestamp_included, $data_level, $schema);

    if (!$validated_request || $validated_request->{'error'}) {
        my $parse_error = $validated_request ? $validated_request->{'error'} : "Error parsing request structure";
        print STDERR $parse_error;
        return CXGN::BrAPI::JSONResponse->return_error($status, $parse_error);
    } elsif ($validated_request->{'success'}) {
        push @$status, {'info' => $validated_request->{'success'} };
    }


    my $parsed_request = $parser->parse('brapi observations', $observations, $timestamp_included, $data_level, $schema);
    my %parsed_data;
    my @units;
    my @variables;

    if (!$parsed_request || $parsed_request->{'error'}) {
        my $parse_error = $parsed_request ? $parsed_request->{'error'} : "Error parsing request data";
        print STDERR $parse_error;
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

    print STDERR "Archived Request is in $file\n";

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
    );

    my ($stored_observation_error, $stored_observation_success, $stored_observation_details) = $store_observations->store();

    if ($stored_observation_error) {
        print STDERR "Error: $stored_observation_error\n";
        return CXGN::BrAPI::JSONResponse->return_error($status, $stored_observation_error);
    }
    if ($stored_observation_success) {
        print STDERR "Success: $stored_observation_success\n";
        if ($version eq 'v1') {
            $result{observations} = $stored_observation_details;
        } elsif ($version eq 'v2') {
            $result{data} = $stored_observation_details;
        }
    }

    ## Will need to initiate refresh matviews in controller instead
    #my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    #my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, $stored_observation_success);

}

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page1 = shift;
    my $page = $page1 ? $page1 : $self->page;
    my $status = $self->status;

    my $observation_db_id = $params->{observationDbId} || ($params->{observationDbIds} || ()); 
    my @observation_variable_db_ids = $params->{observationVariableDbIds} ? @{$params->{observationVariableDbIds}} : ();
    # externalReferenceID
    # externalReferenceSource
    my $observation_level = $params->{observationLevel}->[0] || 'all'; # need to be changed in v2
    my $season_arrayref = $params->{seasonDbId} || ($params->{seasonDbIds} || ());
    my $location_ids_arrayref = $params->{locationDbId} || ($params->{locationDbIds} || ());
    my $study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $trial_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $accession_ids_arrayref = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $start_time = $params->{observationTimeStampRangeStart}->[0] || undef;
    my $end_time = $params->{observationTimeStampRangeEnd}->[0] || undef;
    my $observation_unit_db_id = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
    # observationUnitLevelName
    # observationUnitLevelOrder
    # observationUnitLevelCode
    my $trial_ids;
    if ($study_ids_arrayref || $trial_ids_arrayref){
        $trial_ids = ($study_ids_arrayref, $trial_ids_arrayref); 
    }

    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$observation_level,
            trial_list=>$trial_ids,
            include_timestamp=>1,
            year_list=>$season_arrayref,
            location_list=>$location_ids_arrayref,
            accession_list=>$accession_ids_arrayref,
            program_list=>$program_ids_arrayref,
            observation_variable_list=>\@observation_variable_db_ids,
            plot_list=>$observation_unit_db_id,
            limit=>$limit,
            offset=>$offset,
        }
    );

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my ($data, $unique_traits) = $phenotypes_search->search();

    my @data_window;
    my $counter = 0;

    foreach my $obs_unit (@$data){
        my @brapi_observations; #print Dumper $obs_unit;
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            my $observation_id = "$_->{phenotype_id}";
            if ( ! $observation_db_id || grep{/^$observation_id$/} @{$observation_db_id} ){
                my @season = {
                    year => $obs_unit->{year},
                    season => undef,
                    seasonDbId => undef
                };

                my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};
                if ( $start_time && $obs_timestamp < $start_time ) { next; } #skip observations before date range
                if ( $end_time && $obs_timestamp > $end_time ) { next; } #skip observations after date range

                if ($counter >= $start_index && $counter <= $end_index) {
                    push @data_window, {
                        additionalInfo=>undef,
                        externalReferences=>undef,
                        germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
                        germplasmName => $obs_unit->{germplasm_uniquename},
                        observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
                        observationUnitName => $obs_unit->{observationunit_uniquename},
                        observationDbId => $observation_id,
                        observationVariableDbId => qq|$_->{trait_id}|,
                        observationVariableName => $_->{trait_name},
                        observationTimeStamp => $obs_timestamp,
                        season => \@season,
                        collector => $_->{operator},
                        studyDbId => qq|$obs_unit->{trial_id}|,
                        uploadedBy=>undef,
                        value => qq|$_->{value}|,
                    };
                }
                $counter++;
            }
        }
    }

    my %result = (data=>\@data_window);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations result constructed');
}

sub detail {
    my $self = shift;
    my $params = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $observation_db_id = $params->{observationDbId};

    my @observation_variable_db_ids = $params->{observationVariableDbIds} ? @{$params->{observationVariableDbIds}} : ();
# externalReferenceID
# externalReferenceSource
    my $observation_level = $params->{observationLevel}->[0] || 'all';
    my $season_arrayref = $params->{seasonDbId} || ($params->{seasonDbIds} || ());
    my $location_ids_arrayref = $params->{locationDbId} || ($params->{locationDbIds} || ());
    my $study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $trial_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $accession_ids_arrayref = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $start_time = $params->{observationTimeStampRangeStart}->[0] || undef;
    my $end_time = $params->{observationTimeStampRangeEnd}->[0] || undef;
    my $observation_unit_db_id = $params->{observationUnitDbId} || "";

    my $trial_ids;
    if ($study_ids_arrayref || $trial_ids_arrayref){
        $trial_ids = ($study_ids_arrayref, $trial_ids_arrayref); 
    }

    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$observation_level,
            trial_list=>$trial_ids,
            include_timestamp=>1,
            year_list=>$season_arrayref,
            location_list=>$location_ids_arrayref,
            accession_list=>$accession_ids_arrayref,
            program_list=>$program_ids_arrayref,
            observation_variable_list=>\@observation_variable_db_ids,
            # limit=>$limit,
            #offset=>$offset,
        }
    );

    my ($data, $unique_traits) = $phenotypes_search->search();
    my @data_window;

    foreach my $obs_unit (@$data){
        my @brapi_observations;
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            if ($_->{phenotype_id} eq $observation_db_id ){
                my @season = {
                    year => $obs_unit->{year},       
                    season => undef,
                    seasonDbId => undef
                };

                my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};
                if ( $start_time && $obs_timestamp < $start_time ) { next; } #skip observations before date range
                if ( $end_time && $obs_timestamp > $end_time ) { next; } #skip observations after date range

                push @data_window, {
                    additionalInfo=>undef,
                    externalReferences=>undef,
                    germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
                    germplasmName => $obs_unit->{germplasm_uniquename},
                    observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
                    observationUnitName => $obs_unit->{observationunit_uniquename},
                    observationDbId => qq|$_->{phenotype_id}|,
                    observationVariableDbId => qq|$_->{trait_id}|,
                    observationVariableName => $_->{trait_name},
                    observationTimeStamp => $obs_timestamp,
                    season => \@season,
                    collector => $_->{operator},
                    studyDbId => qq|$obs_unit->{trial_id}|,
                    uploadedBy=>undef,
                    value => qq|$_->{value}|,
                };
                last; 
            }
        }
    }

    my %result = (data=>\@data_window);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations result constructed');
}

1;

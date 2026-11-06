package CXGN::BrAPI::v2::Observations;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::DataAuthorization;
use CXGN::BreederSearch;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::Chado::Organism;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use CXGN::BrAPI::FileRequest;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::SearchFactory;
use JSON;
use CXGN::TimeUtils;
use DateTime;
use utf8;
use JSON;
use CXGN::JSONUtils qw(decode_stored_json);

extends 'CXGN::BrAPI::v2::Common';

# Validate request boundaries here; Native owns filtering and pagination.
sub _read_params {
    my ($params)=@_;
    return (undef,'Observation search parameters must be an object.') if ref($params) ne 'HASH';
    my %copy=%$params;
    my @id_fields=qw(observationDbId observationDbIds observationVariableDbId observationVariableDbIds observationUnitDbId observationUnitDbIds studyDbId studyDbIds trialDbId trialDbIds germplasmDbId germplasmDbIds programDbId programDbIds locationDbId locationDbIds);
    for my $key (@id_fields,qw(seasonDbId seasonDbIds observationVariableName observationVariableNames collectors observationLevel)) {
        next unless defined($copy{$key});
        return (undef,"$key must be a value or an array of values.") if ref($copy{$key}) && ref($copy{$key}) ne 'ARRAY';
        my $values=ref($copy{$key}) eq 'ARRAY' ? $copy{$key} : [$copy{$key}];
        return (undef,"$key must contain scalar values.") if grep {!defined($_) || ref($_)} @$values;
        if (grep {$_ eq $key} @id_fields) {
            return (undef,"$key must contain positive integer identifiers.") if grep {!/^[1-9]\d*$/} @$values;
        }
        return (undef,"$key must contain integer years.") if $key =~ /^seasonDbIds?$/ && grep {!/^-?\d+$/} @$values;
        $copy{$key}=[@$values];
    }
    my %levels=map {$_=>1} qw(all accession plot plant subplot tissue_sample analysis_instance);
    return (undef,'Unsupported observation level.') if grep {$_ ne '' && !$levels{$_}} @{$copy{observationLevel} || []};
    for my $key (qw(observationTimeStampRangeStart observationTimeStampRangeEnd)) {
        next unless defined($copy{$key});
        my $values=ref($copy{$key}) eq 'ARRAY' ? $copy{$key} : [$copy{$key}];
        return (undef,"$key accepts one timestamp.") if @$values>1;
        my $ok=eval {CXGN::TimeUtils::normalize_db_timestamp($values->[0]);1};
        return (undef,"$key must be a valid ISO8601 date or timestamp with microsecond precision or less.") if !$ok;
        $copy{$key}=[@$values];
    }
    return (\%copy,undef);
}

# Called after a committed observation write by both API versions. Native reads
# are live; materialized datasets and saved analysis caches must follow too.
sub refresh_after_store {
    my ($schema,$c,$unit_ids,$status,$result)=@_;
    my $ok=eval {
        my $projects=$schema->storage->dbh->selectcol_arrayref(
            'SELECT DISTINCT nep.project_id FROM nd_experiment_stock nes JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nes.stock_id=ANY(?)',
            undef,$unit_ids);
        my $refresh=CXGN::BreederSearch->new({dbh=>$c->dbc->dbh,dbname=>$c->config->{dbname}})->refresh_matviews_after_change(
            $c->config->{dbhost},$c->config->{dbname},$c->config->{dbuser},$c->config->{dbpass},'phenotypes','concurrent',$c->config->{basepath});
        my $cleared=$c->controller('solGS::clearCache')->clear_cached_analyses_result($c,{trials=>$projects});
        die "Analytical refresh pending.\n" if $refresh->{refresh_pending} || $refresh->{error} || !$cleared;
        1;
    };
    if (!$ok) {
        push @$status,{WARNING=>'Observations saved; analytical refresh needs retry before using analytical results.'};
        $result->{changesSaved}=JSON::true;
        $result->{refreshPending}=JSON::true;
    }
}

sub search {
    my $self = shift;
    my $params = shift;
    my ($checked,$error)=_read_params($params);
    return CXGN::BrAPI::JSONResponse->return_error($self->status,$error,400) if $error;
    $params=$checked;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $data;
	my $counter=0;
    my $limit;
    my $brapi_study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());
    if (!$brapi_study_ids_arrayref || scalar (@$brapi_study_ids_arrayref) < 1) { $limit=1000000; } # if no ids, limit should be set to max and retrieve whole database. If ids no limit to retrieves all
    #TODO: figure out why this has no brapi study Id arrayref
    ($data,$counter) = _search($self,$params,$limit);

    my %result = (data=>$data);
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

    my $id=$params->{observationDbId};
    return CXGN::BrAPI::JSONResponse->return_error($status,'Observation identifier must be a positive integer.',400)
        if !defined($id) || ref($id) || $id !~ /^[1-9]\d*$/;
    $params={%$params,observationDbId=>[$id]};

    my $data;
	my $counter=0;
    ($data,$counter) = _search($self,$params);

    if (ref($data) eq 'ARRAY' && @$data){
		my $result = @$data[0];
		my @data_files;
		my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
		return CXGN::BrAPI::JSONResponse->return_success($result, $pagination, \@data_files, $status, 'Observations result constructed');
	} else {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'ObservationDbId not found', 404);
	}
}

sub observations_store {
    my $self = shift;
    my $params = shift;
    my $c = shift;

    my $schema = $self->bcs_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();

    my $observations = $params->{observations};
    my $overwrite_values = $params->{overwrite} ? $params->{overwrite} : 0;
    my $user_id = $params->{user_id};
    my $user_type = $params->{user_type};
    my $archive_path = $c->config->{archive_path};
    my $tempfiles_subdir = $c->config->{basepath}."/".$c->config->{tempfiles_subdir};
    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my %result;

    #print STDERR "OBSERVATIONS_MODULE: User id is $user_id and type is $user_type\n";
    if (!$user_id) {
        print STDERR 'Must provide user_id to upload phenotypes! Please contact us!';
        push @$status, {'403' => 'Permission Denied. Must provide user_id.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, 'Must provide user_id to upload phenotypes! Please contact us!', 403);
    }

    if ($user_type ne 'submitter' && $user_type ne 'sequencer' && $user_type ne 'curator') {
        print STDERR 'Must have submitter privileges to upload phenotypes! Please contact us!';
        push @$status, {'403' => 'Permission Denied. Must have correct privilege.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, 'Must have submitter privileges to upload phenotypes! Please contact us!', 403);
    }

    my $p = $c->dbic_schema("CXGN::People::Schema", undef, $user_id)->resultset("SpPerson")->find({sp_person_id=>$user_id});
    my $user_name = $p->username;

    ## Validate request structure and parse data
    my $timestamp_included = 1;
    my $data_level = 'stocks';

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validated_request = $parser->validate('brapi observations', $observations, $timestamp_included, $data_level, $schema, undef, undef);

    if (!$validated_request || $validated_request->{'error'}) {
        my $parse_error = $validated_request ? $validated_request->{'error'} : "Error parsing request structure";
        print STDERR $parse_error;
        push @$status, {'400' => 'Invalid request.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, $parse_error, 400);
    } elsif ($validated_request->{'success'}) {
        push @$status, {'info' => $validated_request->{'success'} };
    }


    my $parsed_request = $parser->parse('brapi observations', $observations, $timestamp_included, $data_level, $schema, undef, $user_name, undef, undef);
    my %parsed_data;
    my @units;
    my @variables;

    if (!$parsed_request || $parsed_request->{'error'}) {
        my $parse_error = $parsed_request ? $parsed_request->{'error'} : "Error parsing request data";
        print STDERR $parse_error;
        push @$status, {'400' => 'Invalid request.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, $parse_error, 400);
    } elsif ($parsed_request->{'success'}) {
        push @$status, {'info' => $parsed_request->{'success'} };
        #define units (observationUnits) and variables (observationVariables) from parsed request
        @units = @{$parsed_request->{'units'}};
        @variables = @{$parsed_request->{'variables'}};
        %parsed_data = %{$parsed_request->{'data'}};
    }

    my @authorization_unit_ids = map { $_->{observationUnitDbId} } @$observations;
    my $authorization = CXGN::BrAPI::DataAuthorization::observation_units_error($schema, $user_id, \@authorization_unit_ids);
    return CXGN::BrAPI::JSONResponse->return_error($status, $authorization->{error}, $authorization->{code}) if $authorization;

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
        push @$status, {'500' => 'Internal error.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, $archive_error_message, 500);
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
    $phenotype_metadata{'operator'} = $user_name;
    $phenotype_metadata{'date'} = $timestamp;

    ## Store observations and return details for response
    my $store_observations = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@units,
        trait_list=>\@variables,
        values_hash=>\%parsed_data,
        has_timestamps=>1,
        metadata_hash=>\%phenotype_metadata,
        overwrite_values=>$overwrite_values,
        #image_zipfile_path=>$image_zip,
        composable_validation_check_name=>$c->config->{composable_validation_check_name},
        allow_repeat_measures=>$c->config->{allow_repeat_measures}
    );

    my ($verified_warning, $verified_error) = $store_observations->verify();

    if ($verified_error) {
        print STDERR "Error: $verified_error\n";
        push @$status, {'500' => 'Internal error.'};
        # the reason, without the HTML of the web page (which units, which values)
        (my $reason = $verified_error) =~ s/<[^>]*>/ /g;
        $reason =~ s/\s+/ /g;
        $reason =~ s/^\s+|\s+$//g;
        $reason = substr($reason, 0, 1000)."..." if length($reason) > 1000;
        return CXGN::BrAPI::JSONResponse->return_error($status, "Error: Your request did not pass the checks. $reason", 400);
    }
    if ($verified_warning) {
        print STDERR "\nWarning: $verified_warning\n";
    }

    my ($stored_observation_error, $stored_observation_success, $stored_observation_details) = $store_observations->store();

    if ($stored_observation_error) {
        print STDERR "Error: $stored_observation_error\n";
        push @$status, {($store_observations->error_code || 500) => 'The observations were not changed.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, "The observations could not be stored; no values were changed.", $store_observations->error_code || 500);
    }
    if ($stored_observation_success) {
        #if no error refresh matviews 
        # my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        # my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'phenotypes', 'concurrent', $c->config->{basepath});

        print STDERR "Success: $stored_observation_success\n";
        $result{data} = $stored_observation_details;
    }

    refresh_after_store($schema,$c,\@authorization_unit_ids,$status,\%result);
    my @data_files = ();
    my $total_count = scalar @{$stored_observation_details || []};
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, $stored_observation_success);

}

sub _search {
    my $self = shift;
    my $params = shift;
    my $limit = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    # my $observation_db_ids = $params->{observationDbId};
    my $observation_db_ids = $params->{observationDbId} || ($params->{observationDbIds} || ());

    my @observation_variable_db_ids = $params->{observationVariableDbId} ? @{$params->{observationVariableDbId}} :
        ($params->{observationVariableDbIds} ? @{$params->{observationVariableDbIds}}: ());
    my @observation_variable_names = $params->{observationVariableName} ? @{$params->{observationVariableName}} :
        ($params->{observationVariableNames} ? @{$params->{observationVariableNames}}: ());
    # externalReferenceID
    # externalReferenceSource
    my $observation_level = $params->{observationLevel}->[0] || 'all'; # need to be changed in v2
    my $season_arrayref = $params->{seasonDbId} || ($params->{seasonDbIds} || ());
    my $location_ids_arrayref = $params->{locationDbId} || ($params->{locationDbIds} || ());
    my $brapi_study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $brapi_trial_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $accession_ids_arrayref = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $start_date = $params->{observationTimeStampRangeStart}->[0] || undef;
    my $end_date = $params->{observationTimeStampRangeEnd}->[0] || undef;
    my $repetitive_measurements_type = $params->{repetitiveMeasurementsType} || 'average'; #use default to average 
    my $observation_unit_db_id = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
    # observationUnitLevelName
    # observationUnitLevelOrder
    # observationUnitLevelCode

    my $offset; # = $page_size*$page;

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'Native',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$observation_level,
            trial_list=>$brapi_study_ids_arrayref,
            folder_list=>$brapi_trial_ids_arrayref,
            include_timestamp=>1,
            year_list=>$season_arrayref,
            location_list=>$location_ids_arrayref,
            accession_list=>$accession_ids_arrayref,
            program_list=>$program_ids_arrayref,
            trait_list=>\@observation_variable_db_ids,
            trait_contains=>\@observation_variable_names,
            plot_list=>$observation_unit_db_id,
            observation_id_list=>$observation_db_ids,
            limit=>$limit,
            offset=>$offset,
            order_by=>"plot_number",
            #include_timestamp=>1,
            date_range_mode => 'timestamp',
            start_date => $start_date,
	        end_date => $end_date,
            repetitive_measurements => $repetitive_measurements_type,
            include_dateless_items => ($start_date || $end_date) ? 0 : 1,
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    my %collectors = map {$_=>1} @{$params->{collectors} || []};
    my @data_window;
    my $counter = 0;

    foreach (@$data){
        if (defined($_->{phenotype_value}) && $_->{phenotype_value} ne '') {
            next if %collectors && !$collectors{$_->{operator} // ''};
            my $observation_id = "$_->{phenotype_id}";
            my $additional_info;
            my $external_references;

            my %season = (
                year => $_->{year},
                season => $_->{year},
                seasonDbId => $_->{year}
            );
            my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};
            # Native owns exact normalized timestamp filtering before pagination.
            if ($counter >= $start_index && $counter <= $end_index) {
                push @data_window, {
                    additionalInfo => $_->{phenotype_additional_info} ? decode_stored_json($_->{phenotype_additional_info}) : undef,
                    externalReferences => $_->{phenotype_external_references} ? decode_stored_json($_->{phenotype_external_references}) : undef,
                    germplasmDbId => qq|$_->{accession_stock_id}|,
                    germplasmName => $_->{accession_uniquename},
                    observationUnitDbId => qq|$_->{obsunit_stock_id}|,
                    observationUnitName => $_->{obsunit_uniquename},
                    observationDbId => $observation_id,
                    observationVariableDbId => qq|$_->{trait_id}|,
                    observationVariableName => $_->{trait_name},
                    observationTimeStamp => CXGN::TimeUtils::db_time_to_iso($obs_timestamp),
                    season => \%season,
                    collector => $_->{operator},
                    studyDbId => qq|$_->{trial_id}|,
                    trialDbId => $_-> {folder_id} ? qq|$_->{folder_id}| : undef,
                    uploadedBy=> $_->{operator},
                    value => qq|$_->{phenotype_value}|,
                    # geoCoordinates => undef #needs to be implemented for v2.1
                };
            }
            $counter++;
        }
    }

    # print STDERR "Values of all the params: " . Dumper(\@data_window) . "\n";
    return (\@data_window,$counter);
}


1;


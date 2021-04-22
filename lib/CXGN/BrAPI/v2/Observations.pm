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

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $observation_db_id = $params->{observationDbId} || ($params->{observationDbIds} || ());
    my @observation_variable_db_ids = $params->{observationVariableDbIds} ? @{$params->{observationVariableDbIds}} : ();
    my @observation_variable_names = $params->{observationVariableNames} ? @{$params->{observationVariableNames}} : ();
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

    my $limit = undef; #$page_size*($page+1)-1;
    my $offset = undef; #$page_size*$page;

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$observation_level,
            trial_list=>$trial_ids,
            folder_list=>$trial_ids_arrayref,
            include_timestamp=>1,
            year_list=>$season_arrayref,
            location_list=>$location_ids_arrayref,
            accession_list=>$accession_ids_arrayref,
            program_list=>$program_ids_arrayref,
            trait_list=>\@observation_variable_db_ids,
            trait_contains=>\@observation_variable_names,
            plot_list=>$observation_unit_db_id,
            limit=>$limit,
            offset=>$offset,
            order_by=>"plot_number"
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    my @data_window;
    my $counter = 0;

    foreach my $obs_unit (@$data){
        #print Dumper($obs_unit);
        my @brapi_observations;
        my $observations = $obs_unit->{observations};
        #print Dumper($observations);
        foreach (@$observations){
            my $observation_id = "$_->{phenotype_id}";
            # if ( ! $observation_db_id || grep{/^$observation_id$/} @{$observation_db_id} ){
                my $season = {
                    year => $obs_unit->{year},
                    seasonName => $obs_unit->{year},
                    seasonDbId => $obs_unit->{year}
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
                        season => $season,
                        collector => $_->{operator},
                        studyDbId => qq|$obs_unit->{trial_id}|,
                        uploadedBy=>undef,
                        value => qq|$_->{value}|,
                    };
                }
                $counter++;
            # }
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

    my ($data, $unique_traits)  = _search_observation_id(
            $self->bcs_schema,
            $observation_level,
            $trial_ids,
            $trial_ids_arrayref,
            1,
            $season_arrayref,
            $location_ids_arrayref,
            $accession_ids_arrayref,
            $program_ids_arrayref,
            \@observation_variable_db_ids,
            [$observation_db_id],
            $observation_unit_db_id, # plot_list
            $limit,
            $offset,
    );


    my @data_window;

    print Dumper(\@$data);

    foreach my $obs_unit (@$data){
        my @brapi_observations;
        my $observations = $obs_unit->{observations};
        print Dumper($observations);
        foreach (@$observations){
            my @season = {
                year => $obs_unit->{year},       
                season => $obs_unit->{year},
                seasonDbId => $obs_unit->{year}
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
        }
    }

    my %result = (data=>\@data_window);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations result constructed');
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
    if ($user_type ne 'submitter' && $user_type ne 'sequencer' && $user_type ne 'curator') {
        print STDERR 'Must have submitter privileges to upload phenotypes! Please contact us!';
        push @$status, {'403' => 'Permission Denied. Must have correct privilege.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, 'Must have submitter privileges to upload phenotypes! Please contact us!');
    }

    ## Validate request structure and parse data
    my $timestamp_included = 1;
    my $data_level = 'stocks';

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validated_request = $parser->validate('brapi observations', $observations, $timestamp_included, $data_level, $schema, undef, undef);

    if (!$validated_request || $validated_request->{'error'}) {
        my $parse_error = $validated_request ? $validated_request->{'error'} : "Error parsing request structure";
        print STDERR $parse_error;
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
        print STDERR $parse_error;
        return CXGN::BrAPI::JSONResponse->return_error($status, $parse_error);
    } elsif ($parsed_request->{'success'}) {
        push @$status, {'info' => $parsed_request->{'success'} };
        #define units (observationUnits) and variables (observationVariables) from parsed request
        @units = @{$parsed_request->{'units'}};
        @variables = @{$parsed_request->{'variables'}};
        %parsed_data = %{$parsed_request->{'data'}};
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
        #image_zipfile_path=>$image_zip,
    );

    my ($stored_observation_error, $stored_observation_success, $stored_observation_details) = $store_observations->store();

    if ($stored_observation_error) {
        print STDERR "Error: $stored_observation_error\n";
        return CXGN::BrAPI::JSONResponse->return_error($status, $stored_observation_error);
    }
    if ($stored_observation_success) {
        #if no error refresh matviews 
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

        print STDERR "Success: $stored_observation_success\n";
        # result need to be updated with v2 format
        $result{data} = $stored_observation_details;

    }
    # result need to be updated with v2 format, StorePhenotypes needs to be modified as v2
    my @data_files = ();
    my $total_count = scalar @{$observations};
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, $stored_observation_success);

}

sub _search_observation_id {
    my $schema = shift;
    my $data_level = shift;
    my $trial_list = shift;
    my $folder_list = shift;
    my $include_timestamp = shift;
    my $year_list = shift;
    my $location_list = shift;
    my $accession_list = shift;
    my $program_list = shift;
    my $observation_variable_list = shift;
    my $observations_list = shift;
    my $plot_list = shift;
    my $limit = shift;
    my $offset = shift;
    my ($plant_list, $subplot_list);
    my $trait_contains;
    my $trait_list;
   

    my $include_timestamp = $include_timestamp;
    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my %synonym_hash_lookup = %{$stock_lookup->get_synonym_hash_lookup()};

    my $select_clause = "SELECT observationunit_stock_id, observationunit_uniquename, observationunit_type_name, germplasm_uniquename, germplasm_stock_id, rep, block, plot_number, row_number, col_number, plant_number, is_a_control, notes, trial_id, trial_name, trial_description, plot_width, plot_length, field_size, field_trial_is_planned_to_be_genotyped, field_trial_is_planned_to_cross, breeding_program_id, breeding_program_name, breeding_program_description, year, design, location_id, planting_date, harvest_date, folder_id, folder_name, folder_description, seedlot_transaction, seedlot_stock_id, seedlot_uniquename, seedlot_current_weight_gram, seedlot_current_count, seedlot_box_name, available_germplasm_seedlots, treatments, observations, count(observationunit_stock_id) OVER() AS full_count FROM materialized_phenotype_jsonb_table ";
    # $select_clause = $select_clause . " cross join lateral jsonb_array_elements(materialized_phenotype_jsonb_table.observations) as obs "
    my $order_clause = " ORDER BY trial_name, observationunit_uniquename";

    my @where_clause;

    if (($plot_list && scalar(@{$plot_list})>0) && ($plant_list && scalar(@{$plant_list})>0) && ($subplot_list && scalar(@{$subplot_list})>0)) {
        my $plot_and_plant_and_subplot_sql = _sql_from_arrayref($plot_list) .",". _sql_from_arrayref($plant_list) .",". _sql_from_arrayref($subplot_list);
        push @where_clause, "observationunit_stock_id in ($plot_and_plant_and_subplot_sql)";
    } elsif (($plot_list && scalar(@{$plot_list})>0) && ($plant_list && scalar(@{$plant_list})>0)) {
        my $plot_and_plant_sql = _sql_from_arrayref($plot_list) .",". _sql_from_arrayref($plant_list);
        push @where_clause, "observationunit_stock_id in ($plot_and_plant_sql)";
    } elsif (($plot_list && scalar(@{$plot_list})>0) && ($subplot_list && scalar(@{$subplot_list})>0)) {
        my $plot_and_subplot_sql = _sql_from_arrayref($plot_list) .",". _sql_from_arrayref($subplot_list);
        push @where_clause, "observationunit_stock_id in ($plot_and_subplot_sql)";
    } elsif (($plant_list && scalar(@{$plant_list})>0) && ($subplot_list && scalar(@{$subplot_list})>0)) {
        my $plant_and_subplot_sql = _sql_from_arrayref($plant_list) .",". _sql_from_arrayref($subplot_list);
        push @where_clause, "observationunit_stock_id in ($plant_and_subplot_sql)";
    } elsif ($plot_list && scalar(@{$plot_list})>0) {
        my $plot_sql = _sql_from_arrayref($plot_list);
        push @where_clause, "observationunit_stock_id in ($plot_sql)";
    } elsif ($plant_list && scalar(@{$plant_list})>0) {
        my $plant_sql = _sql_from_arrayref($plant_list);
        push @where_clause, "observationunit_stock_id in ($plant_sql)";
    } elsif ($subplot_list && scalar(@{$subplot_list})>0) {
        my $subplot_sql = _sql_from_arrayref($subplot_list);
        push @where_clause, "observationunit_stock_id in ($subplot_sql)";
    }

    if ($trial_list && scalar(@{$trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($trial_list);
        push @where_clause, "trial_id in ($trial_sql)";
    }
    if ($program_list && scalar(@{$program_list})>0) {
        my $program_sql = _sql_from_arrayref($program_list);
        push @where_clause, "breeding_program_id in ($program_sql)";
    }
    if ($folder_list && scalar(@{$folder_list})>0) {
        my $folder_sql = _sql_from_arrayref($folder_list);
        push @where_clause, "folder_id in ($folder_sql)";
    }
    if ($accession_list && scalar(@{$accession_list})>0) {
        my $arrayref = $accession_list;
        my $sql = join ("','" , @$arrayref);
        my $accession_sql = "'" . $sql . "'";
        push @where_clause, "germplasm_stock_id in ($accession_sql)";
    }
    if ($location_list && scalar(@{$location_list})>0) {
        my $arrayref = $location_list;
        my $sql = join ("','" , @$arrayref);
        my $location_sql = "'" . $sql . "'";
        push @where_clause, "location_id in ($location_sql)";
    }
    if ($year_list && scalar(@{$year_list})>0) {
        my $arrayref = $year_list;
        my $sql = join ("','" , @$arrayref);
        my $year_sql = "'" . $sql . "'";
        push @where_clause, "year in ($year_sql)";
    }
    if ($data_level ne 'all') {
        push @where_clause, "observationunit_type_name = '".$data_level."'"; #ONLY plot or plant or subplot or tissue_sample
    } else {
        push @where_clause, "(observationunit_type_name = 'plot' OR observationunit_type_name = 'plant' OR observationunit_type_name = 'subplot' OR observationunit_type_name = 'tissue_sample')"; #plots AND plants AND subplots AND tissue_samples
    }

    my %trait_list_check;
    my $filter_trait_ids;
    my @or_clause;
    if ($trait_list && scalar(@{$trait_list})>0) {
        print STDERR "A trait list was included\n";
        foreach (@{$trait_list}){
            if ($_){
                #print STDERR "Working on trait $_\n";
                push @or_clause, "observations @> '[{\"trait_id\" : $_}]'";
                $trait_list_check{$_}++;
                $filter_trait_ids = 1;
            }
        }
    }
    my $filter_trait_names;
    if ($trait_contains && scalar(@{$trait_contains})>0) {
        foreach (@{$trait_contains}) {
            if ($_){
                push @or_clause, "observations @> '[{\"trait_name\" : \"$_\"}]'";
                $filter_trait_names = 1;
            }
        }
    }
    if ($observations_list && scalar(@{$observations_list})>0) {
        foreach (@{$observations_list}) {
            if ($_){
                push @or_clause, "observations @> '[{\"phenotype_id\" : $_}]'";
            }
        }
    }

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));
    my $or_clause = '';
    if (scalar(@or_clause) > 0){
        $or_clause = " AND ( " . (join (" OR " , @or_clause)) . " ) ";
    }

    my $offset_clause = '';
    my $limit_clause = '';
    if ($limit){
        $limit_clause = " LIMIT ".$limit;
    }
    if ($offset){
        $offset_clause = " OFFSET ".$offset;
    }

    my  $q = $select_clause . $where_clause . $or_clause . $order_clause . $limit_clause . $offset_clause;

    print STDERR "QUERY: $q\n\n";

    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;

    my $calendar_funcs = CXGN::Calendar->new({});
    my %unique_traits;

    while (my ($observationunit_stock_id, $observationunit_uniquename, $observationunit_type_name, $germplasm_uniquename, $germplasm_stock_id, $rep, $block, $plot_number, $row_number, $col_number, $plant_number, $is_a_control, $notes, $trial_id, $trial_name, $trial_description, $plot_width, $plot_length, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $breeding_program_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $planting_date, $harvest_date, $folder_id, $folder_name, $folder_description, $seedlot_transaction, $seedlot_stock_id, $seedlot_uniquename, $seedlot_current_weight_gram, $seedlot_current_count, $seedlot_box_name, $available_germplasm_seedlots, $treatments, $observations, $full_count) = $h->fetchrow_array()) {
        my $harvest_date_value = $calendar_funcs->display_start_date($harvest_date);
        my $planting_date_value = $calendar_funcs->display_start_date($planting_date);
        my $synonyms = $synonym_hash_lookup{$germplasm_uniquename};
        my $location_name = $location_id ? $location_id_lookup{$location_id} : '';
        my $observations = decode_json $observations;
        my $treatments = decode_json $treatments;
        my $available_germplasm_seedlots = decode_json $available_germplasm_seedlots;
        my $seedlot_transaction = $seedlot_transaction ? decode_json $seedlot_transaction : {};

        my %ordered_observations;
        foreach (@$observations){
            my $id = $_->{phenotype_id};
            $ordered_observations{$id} = $_ if ( !$observations_list || grep(/^$id$/, @$observations_list));
        }

        my @return_observations;;
        foreach my $pheno_id (sort keys %ordered_observations){
            my $o = $ordered_observations{$pheno_id};
            my $trait_name = $o->{trait_name};

            my $phenotype_uniquename = $o->{uniquename};
            $unique_traits{$trait_name}++;
            if ($include_timestamp){
                my $timestamp_value;
                my $operator_value;
                if ($phenotype_uniquename){
                    my ($p1, $p2) = split /date: /, $phenotype_uniquename;
                    if ($p2){
                        my ($timestamp, $operator_value) = split /  operator = /, $p2;
                        if ( $timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                            $timestamp_value = $timestamp;
                        }
                    }
                }
                $o->{timestamp} = $timestamp_value;
            }
            if (!$o->{operator}){
                if ($phenotype_uniquename){
                    my ($p1, $p2) = split /date: /, $phenotype_uniquename;
                    if ($p2){
                        my ($timestamp, $operator_value) = split /  operator = /, $p2;
                        $o->{operator} = $operator_value;
                    }
                }
            }
            push @return_observations, $o;
        }

        no warnings 'uninitialized';
        
        if ($notes) { $notes =~ s/\R//g; }
        if ($trial_description) { $trial_description =~ s/\R//g; }
        if ($breeding_program_description) { $breeding_program_description =~ s/\R//g };
        if ($folder_description) { $folder_description =~ s/\R//g };

        my $seedlot_transaction_description = $seedlot_transaction->{description};
        if ($seedlot_transaction_description) { $seedlot_transaction_description =~ s/\R//g; }

        push @result, {
            observationunit_stock_id => $observationunit_stock_id,
            observationunit_uniquename => $observationunit_uniquename,
            observationunit_type_name => $observationunit_type_name,
            germplasm_uniquename => $germplasm_uniquename,
            germplasm_stock_id => $germplasm_stock_id,
            germplasm_synonyms => $synonyms,
            obsunit_rep => $rep,
            obsunit_block => $block,
            obsunit_plot_number => $plot_number,
            obsunit_row_number => $row_number,
            obsunit_col_number => $col_number,
            obsunit_plant_number => $plant_number,
            obsunit_is_a_control => $is_a_control,
            notes => $notes,
            trial_id => $trial_id,
            trial_name => $trial_name,
            trial_description => $trial_description,
            plot_width => $plot_width,
            plot_length => $plot_length,
            field_size => $field_size,
            field_trial_is_planned_to_be_genotyped => $field_trial_is_planned_to_be_genotyped,
            field_trial_is_planned_to_cross => $field_trial_is_planned_to_cross,
            breeding_program_id => $breeding_program_id,
            breeding_program_name => $breeding_program_name,
            breeding_program_description => $breeding_program_description,
            year => $year,
            design => $design,
            trial_location_id => $location_id,
            trial_location_name => $location_name,
            planting_date => $planting_date_value,
            harvest_date => $harvest_date_value,
            folder_id => $folder_id,
            folder_name => $folder_name,
            folder_description => $folder_description,
            seedlot_transaction_amount => $seedlot_transaction->{amount},
            seedlot_transaction_weight_gram => $seedlot_transaction->{weight_gram},
            seedlot_transaction_timestamp => $seedlot_transaction->{timestamp},
            seedlot_transaction_operator => $seedlot_transaction->{operator},
            seedlot_transaction_description => $seedlot_transaction_description,
            seedlot_stock_id => $seedlot_stock_id,
            seedlot_uniquename => $seedlot_uniquename,
            seedlot_current_count => $seedlot_current_count,
            seedlot_current_weight_gram => $seedlot_current_weight_gram,
            seedlot_box_name => $seedlot_box_name,
            available_germplasm_seedlots => $available_germplasm_seedlots,
            treatments => $treatments,
            observations => \@return_observations,
            full_count => $full_count,
        };
    }

    print Dumper(\@result);
    print STDERR "Search End:".localtime."\n";
    return (\@result, \%unique_traits);
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}

1;

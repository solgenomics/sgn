package CXGN::BrAPI::v2::ObservationUnits;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use Try::Tiny;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::List::Transform;
use JSON;


extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data_files;

    my $data_level = $params->{observationUnitLevelName} || ['all'];
    my $years_arrayref = $params->{seasonDbId} || ($params->{seasonDbIds} || ());
    my $location_ids_arrayref = $params->{locationDbId} || ($params->{locationDbIds} || ());
    my $study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $accession_ids_arrayref = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $trait_list_arrayref = $params->{observationVariableDbId} || ($params->{observationVariableDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $folder_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $start_time = $params->{observationTimeStampRangeStart}->[0] || undef;
    my $end_time = $params->{observationTimeStampRangeEnd}->[0] || undef;
    my $observation_unit_db_id = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
    my $include_observations = $params->{includeObservations}->[0] || "False";
    my $level_order_arrayref = $params->{observationUnitLevelOrder} || ($params->{observationUnitLevelOrders} || ());
    my $level_code_arrayref = $params->{observationUnitLevelCode} || ($params->{observationUnitLevelCodes} || ());
    my $levels_relation_arrayref = $params->{observationLevelRelationships} || ();
    my $levels_arrayref = $params->{observationLevels} || ();
    # externalReferenceID
    # externalReferenceSource

    if ($levels_arrayref){
        $data_level = ();
        foreach ( @{$levels_arrayref} ){
            push @$level_code_arrayref, $_->{levelCode} if ($_->{levelCode});
            push @{$data_level}, $_->{levelName} if ($_->{levelName});
        }
        if (! $data_level) {
            $data_level = ['all'];
        }
    }

    my $lt = CXGN::List::Transform->new();
    my $trait_ids_arrayref = $lt->transform($self->bcs_schema, "traits_2_trait_ids", $trait_list_arrayref)->{transform};

    my $limit = $page_size*($page+1);
    my $offset = $page_size*$page;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level->[0],
            trial_list=>$study_ids_arrayref,
            trait_list=>$trait_ids_arrayref,
            include_timestamp=>1,
            year_list=>$years_arrayref,
            location_list=>$location_ids_arrayref,
            accession_list=>$accession_ids_arrayref,
            folder_list=>$folder_ids_arrayref,
            program_list=>$program_ids_arrayref,
            plot_list=>$observation_unit_db_id,
            limit=>$limit,
            offset=>$offset,
            # phenotype_min_value=>$phenotype_min_value,
            # phenotype_max_value=>$phenotype_max_value,
            # exclude_phenotype_outlier=>$exclude_phenotype_outlier
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    #print STDERR Dumper $data;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;

    my @data_window;
    my $total_count = 0;

    foreach my $obs_unit (@$data){
        my @brapi_observations;
        
        if( lc $include_observations eq 'true') {

            my $observations = $obs_unit->{observations};
            foreach (@$observations){
                my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};
                if ( $start_time && $obs_timestamp < $start_time ) { next; } #skip observations before date range
                if ( $end_time && $obs_timestamp > $end_time ) { next; } #skip observations after date range
                my @season = {
                    year => $obs_unit->{year},
                    season => undef,
                    seasonDbId => undef
                };
                push @brapi_observations, {
                    additionalInfo => {},
                    externalReferences => [],
                    observationDbId => qq|$_->{phenotype_id}|,
                    observationVariableDbId => qq|$_->{trait_id}|,
                    observationVariableName => $_->{trait_name},
                    observationTimeStamp => $obs_timestamp,
                    season => \@season,
                    collector => $_->{operator},
                    value => qq|$_->{value}|,
                    germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
                    germplasmName => $obs_unit->{germplasm_uniquename},
                    observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
                    observationUnitName => $obs_unit->{observationunit_uniquename},
                    studyDbId  => qq|$obs_unit->{trial_id}|,
                    uploadedBy=>undef,
                };
            }
        }

        my @brapi_treatments;
        my $treatments = $obs_unit->{treatments};
        while (my ($factor, $modality) = each %$treatments){
            my $modality = $modality ? $modality : '';
            push @brapi_treatments, {
                factor => $factor,
                modality => $modality,
            };
        }

        my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot_geo_json', 'stock_property')->cvterm_id();
        my $sp_rs ='';
        eval { 
            $sp_rs = $self->bcs_schema->resultset("Stock::Stockprop")->search({ type_id => $type_id, stock_id => $obs_unit->{observationunit_stock_id} });
        };
        my %geolocation_lookup;
        while( my $r = $sp_rs->next()){
            $geolocation_lookup{$r->stock_id} = $r->value;
        }
        my $geo_coordinates_string = $geolocation_lookup{$obs_unit->{observationunit_stock_id}} ?$geolocation_lookup{$obs_unit->{observationunit_stock_id}} : '';
        my $geo_coordinates =''; 

        if ($geo_coordinates_string){
            $geo_coordinates = decode_json $geo_coordinates_string;
        } 

        my $entry_type = $obs_unit->{obsunit_is_a_control} ? 'check' : 'test';

        my $replicate = $obs_unit->{obsunit_rep};
        my $block = $obs_unit->{obsunit_block};
        my $plot = $obs_unit->{obsunit_plot_number};
        my $plant = $obs_unit->{obsunit_plant_number};

        my $level_name = $obs_unit->{observationunit_type_name};
        my $level_order = _order($level_name) + 0;
        my $level_code = eval "\$$level_name" || "";
         
        if ( $level_order_arrayref &&  ! grep { $_ eq $level_order } @{$level_order_arrayref}  ) { next; } 
        if ( $level_code_arrayref &&  ! grep { $_ eq $level_code } @{$level_code_arrayref}  ) { next; } 

        my $observationLevelRelationships = [
            {
                levelCode => $replicate,
                levelName => "replicate",
                levelOrder => _order("replicate"),
            },
            {
                levelCode => $block,
                levelName => "block",
                levelOrder => _order("block"),
            },
            {
                levelCode => $plot,
                levelName => "plot",
                levelOrder => _order("plot"),
            },
            {
                levelCode => $plant,
                levelName => "plant",
                levelOrder => _order("plant"),
            }
        ];

        my %observationUnitPosition = (
            entryType => $entry_type,
            geoCoordinates => $geo_coordinates,
            positionCoordinateX => $obs_unit->{obsunit_col_number},
            positionCoordinateXType => 'GRID_COL',
            positionCoordinateY => $obs_unit->{obsunit_row_number},
            positionCoordinateYType => 'GRID_ROW',
            # replicate => $obs_unit->{obsunit_rep}, #obsolete v2?
            observationLevel =>  { 
                levelName => $level_name,       
                levelOrder => $level_order,
                levelCode => $level_code,
            },
            observationLevelRelationships => $observationLevelRelationships,
        );

        my $brapi_observationUnitPosition = decode_json(encode_json \%observationUnitPosition);

        push @data_window, {
            additionalInfo => {},
            externalReferences => [],
            germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
            germplasmName => $obs_unit->{germplasm_uniquename},
            locationDbId => qq|$obs_unit->{trial_location_id}|,   
            locationName => $obs_unit->{trial_location_name},
            observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
            observations => \@brapi_observations,
            observationUnitName => $obs_unit->{observationunit_uniquename},
            observationUnitPosition => $brapi_observationUnitPosition,
            observationUnitPUI => '',
            programName => $obs_unit->{breeding_program_name},
            programDbId => $obs_unit->{breeding_program_id},
                #seedLotDbId
            studyDbId => qq|$obs_unit->{trial_id}|,
            studyName => $obs_unit->{trial_name},
            treatments => \@brapi_treatments,
            trialDbId => qq|$obs_unit->{trial_id}|,
            trialName => $obs_unit->{trial_name},
        };
        $total_count = $obs_unit->{full_count};       
        
    }

    my %result = (data=>\@data_window);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observation Units search result constructed');
}

sub detail {
    my $self = shift;
    my $observation_unit_db_id = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data_files;

    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>'all',
            include_timestamp=>1,
            plot_list=>[$observation_unit_db_id],
            # limit=>$limit,
            offset=>$offset,
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    #print STDERR Dumper $data;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;

    my @data_window;
    my $total_count = 0;
    my $counter =0;

    foreach my $obs_unit (@$data){
        my @brapi_observations;

        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};
            my @season = {
                year => $obs_unit->{year},
                season => undef,
                seasonDbId => undef
            };
            push @brapi_observations, {
                additionalInfo => {},
                externalReferences => [],
                observationDbId => qq|$_->{phenotype_id}|,
                observationVariableDbId => qq|$_->{trait_id}|,
                observationVariableName => $_->{trait_name},
                observationTimeStamp => $obs_timestamp,
                season => \@season,
                collector => $_->{operator},
                value => qq|$_->{value}|,
                germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
                germplasmName => $obs_unit->{germplasm_uniquename},
                observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
                observationUnitName => $obs_unit->{observationunit_uniquename},
                studyDbId  => qq|$obs_unit->{trial_id}|,
                uploadedBy=>undef,
            };
        }

        my @brapi_treatments;
        my $treatments = $obs_unit->{treatments};
        while (my ($factor, $modality) = each %$treatments){
            my $modality = $modality ? $modality : '';
            push @brapi_treatments, {
                factor => $factor,
                modality => $modality,
            };
        }

        my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot_geo_json', 'stock_property')->cvterm_id();
        my $sp_rs ='';
        eval { 
            $sp_rs = $self->bcs_schema->resultset("Stock::Stockprop")->search({ type_id => $type_id, stock_id => $obs_unit->{observationunit_stock_id} });
        };
        my %geolocation_lookup;
        while( my $r = $sp_rs->next()){
            $geolocation_lookup{$r->stock_id} = $r->value;
        }
        my $geo_coordinates_string = $geolocation_lookup{$obs_unit->{observationunit_stock_id}} ?$geolocation_lookup{$obs_unit->{observationunit_stock_id}} : '';
        my $geo_coordinates =''; 

        if ($geo_coordinates_string){
            $geo_coordinates = decode_json $geo_coordinates_string;
        } 

        my $entry_type = $obs_unit->{obsunit_is_a_control} ? 'check' : 'test';

        my $level_order = _order($obs_unit->{observationunit_type_name});
        my $observationLevelRelationships = [  
            {
                levelCode => $obs_unit->{obsunit_rep},
                levelName => "replicate",
                levelOrder => _order("replicate"),
            },
            {
                levelCode => $obs_unit->{obsunit_block},
                levelName => "block",
                levelOrder => _order("block"),
            },
            {
                levelCode => $obs_unit->{obsunit_plot_number},
                levelName => "plot",
                levelOrder => _order("plot"),
            },
            {
                levelCode => $obs_unit->{obsunit_plant_number},
                levelName => "plant",
                levelOrder => _order("plant"),
            }
        ];

        my %observationUnitPosition = (
            entryType => $entry_type,
            geoCoordinates => $geo_coordinates,
            positionCoordinateX => $obs_unit->{obsunit_col_number},
            positionCoordinateXType => '',
            positionCoordinateY => $obs_unit->{obsunit_row_number},
            positionCoordinateYType => '',
            observationLevel =>  { 
                levelName => $obs_unit->{observationunit_type_name},       
                levelOrder => $level_order,
                levelCode => '',
            },
            observationLevelRelationships => $observationLevelRelationships,
        );

        my $brapi_observationUnitPosition = decode_json(encode_json \%observationUnitPosition);

        push @data_window, {
            additionalInfo => {},
            externalReferences => [],
            germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
            germplasmName => $obs_unit->{germplasm_uniquename},
            locationDbId => qq|$obs_unit->{trial_location_id}|,   
            locationName => $obs_unit->{trial_location_name},
            observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
            observations => \@brapi_observations,
            observationUnitName => $obs_unit->{observationunit_uniquename},
            observationUnitPosition => $brapi_observationUnitPosition,
            observationUnitPUI => '',
            programName => $obs_unit->{breeding_program_name},
            programDbId => $obs_unit->{breeding_program_id},
                #seedLotDbId
            studyDbId => qq|$obs_unit->{trial_id}|,
            studyName => $obs_unit->{trial_name},
            treatments => \@brapi_treatments,
            trialDbId => qq|$obs_unit->{trial_id}|,
            trialName => $obs_unit->{trial_name},
        };
        $total_count = $obs_unit->{full_count};
        $counter++;
    }

    my %result = (data=>\@data_window);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observation Units search result constructed');
}

sub observationunits_store {
    my $self = shift;
    my $observation_unit_db_id = shift;
    my $params = shift;
    my $user_id = shift;
    my $user_type = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $dbh = $self->bcs_schema()->storage()->dbh();

    my $schema = $self->bcs_schema;
    my $data_level = $params->{observationLevel}->[0] || 'all';
    my $years_arrayref = $params->{seasonDbId} || ($params->{seasonDbIds} || ());
    my $location_ids_arrayref = $params->{locationDbId} || ($params->{locationDbIds} || ());
    my $study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $accession_ids_arrayref = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $trait_list_arrayref = $params->{observationVariableDbId} || ($params->{observationVariableDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $folder_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $observationUnit_name = $params->{observationUnitName}->[0] || "";
    my $observationUnit_position_arrayref = $params->{observationUnitPosition} || ($params->{observationUnitPosition} || ());
    my $observationUnit_x_ref = $params->{observationUnitXref} || "";

    my $geo_coordinates = "";

    foreach my $observationUnit_position (@$observationUnit_position_arrayref) {        
        $geo_coordinates = $observationUnit_position->{geoCoordinates} || "";
    }

    my $geno_json_string = encode_json $geo_coordinates;

    #update cvterm
    my $stock_geo_json_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_geo_json', 'stock_property');

    my @parsed_data;
    push @parsed_data, {
        plot_stock_id => $observation_unit_db_id,
    };

    #sub upload coordinates
    my $upload_plot_gps_txn = sub {

        my %plot_stock_ids_hash;
        while (my ($key, $val) = each(@parsed_data)){
            $plot_stock_ids_hash{$val->{plot_stock_id}} = $val;
        }

        my @plot_stock_ids = keys %plot_stock_ids_hash;

        my $plots_rs = $schema->resultset("Stock::Stock")->search({stock_id => {-in=>\@plot_stock_ids}});

        while (my $plot=$plots_rs->next){

            my $previous_plot_gps_rs = $schema->resultset("Stock::Stockprop")->search({stock_id=>$plot->stock_id, type_id=>$stock_geo_json_cvterm->cvterm_id});
            $previous_plot_gps_rs->delete_all();
            $plot->create_stockprops({$stock_geo_json_cvterm->name() => $geno_json_string});
        }
    };

    eval {
        $schema->txn_do($upload_plot_gps_txn);
    };
    if ($@) {
        print STDERR "An error condition occurred, was not able to upload trial plot GPS coordinates. ($@).\n";
        # $c->detach();
    }

    my $result = '';
    my $total_count = 1;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success($result, $pagination, undef, $status, 'Observation Units result constructed');
}

sub _order {
    my $value = shift;
    my %levels = (
        "replicate"  => 0,
        "block"  => 1,
        "plot" => 2,
        "subplot"=> 3,
        "plant"=> 4,
        "tissue_sample"=> 5,

    );
    return $levels{$value} + 0;
}

1;

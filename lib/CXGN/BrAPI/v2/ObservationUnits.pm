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
use JSON::Parse ':all';


extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data_files;

    my $data_level = $params->{observationLevel}->[0] || 'all';
    my $years_arrayref = $params->{seasonDbId} || ($params->{seasonDbIds} || ());
    my $location_ids_arrayref = $params->{locationDbId} || ($params->{locationDbIds} || ());
    my $study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $accession_ids_arrayref = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $trait_list_arrayref = $params->{observationVariableDbId} || ($params->{observationVariableDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $folder_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $start_time = $params->{observationTimeStampRangeStart}->[0] || undef;
    my $end_time = $params->{observationTimeStampRangeEnd}->[0] || undef;
    my $observation_unit_db_id = $params->{observationUnitDbId} || "";

    # not part of brapi standard yet
    # my $phenotype_min_value = $params->{phenotype_min_value};
    # my $phenotype_max_value = $params->{phenotype_max_value};
    # my $exclude_phenotype_outlier = $params->{exclude_phenotype_outlier} || 0;
    # my $search_type = $params->{search_type}->[0] || 'MaterializedViewTable';

    my $lt = CXGN::List::Transform->new();
    my $trait_ids_arrayref = $lt->transform($self->bcs_schema, "traits_2_trait_ids", $trait_list_arrayref)->{transform};

    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level,
            trial_list=>$study_ids_arrayref,
            trait_list=>$trait_ids_arrayref,
            include_timestamp=>1,
            year_list=>$years_arrayref,
            location_list=>$location_ids_arrayref,
            accession_list=>$accession_ids_arrayref,
            folder_list=>$folder_ids_arrayref,
            program_list=>$program_ids_arrayref,
            # limit=>$limit,
            offset=>$offset,
            # phenotype_min_value=>$phenotype_min_value,
            # phenotype_max_value=>$phenotype_max_value,
            # exclude_phenotype_outlier=>$exclude_phenotype_outlier
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    #print STDERR Dumper $data;

    my @data_window;
    my $total_count = 0;
    foreach my $obs_unit (@$data){
        my @brapi_observations;
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};
            if ( $start_time && $obs_timestamp < $start_time ) { next; } #skip observations before date range
            if ( $end_time && $obs_timestamp > $end_time ) { next; } #skip observations after date range
            push @brapi_observations, {
                observationDbId => qq|$_->{phenotype_id}|,
                observationVariableDbId => qq|$_->{trait_id}|,
                observationVariableName => $_->{trait_name},
                observationTimeStamp => $obs_timestamp,
                season => $obs_unit->{year},
                collector => $_->{operator},
                value => qq|$_->{value}|,
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
            $geo_coordinates = parse_json ($geo_coordinates_string);
        } 

        my $entry_type = $obs_unit->{obsunit_is_a_control} ? 'check' : 'test';

        my %observationUnitPosition = ( 
            blockNumber => $obs_unit->{obsunit_block},       
            entryType => $entry_type,
            entryNumber => '',
            geoCoordinates => $geo_coordinates,
            positionCoordinateX => $obs_unit->{obsunit_col_number},
            positionCoordinateXType => '',
            positionCoordinateY => $obs_unit->{obsunit_row_number},
            positionCoordinateYType => '',
            replicate => $obs_unit->{obsunit_rep},
            plotNumber => $obs_unit->{obsunit_plot_number},
            plantNumber => $obs_unit->{obsunit_plant_number}
        );
        my $brapi_observationUnitPosition = parse_json(encode_json \%observationUnitPosition);

        push @data_window, {
            germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
            germplasmName => $obs_unit->{germplasm_uniquename},
            locationDbId => qq|$obs_unit->{trial_location_id}|,   
            locationName => $obs_unit->{trial_location_name},
            observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
            observationLevel => $obs_unit->{observationunit_type_name},
            observationUnitName => $obs_unit->{observationunit_uniquename},
            observationUnitPosition => $brapi_observationUnitPosition,
            observationUnitXref => '',
            programName => $obs_unit->{breeding_program_name},
            programDbId => $obs_unit->{breeding_program_id},
            studyDbId => qq|$obs_unit->{trial_id}|,
            studyName => $obs_unit->{trial_name},
            treatments => \@brapi_treatments,
            trialDbId => qq|$obs_unit->{trial_id}|,
            trialName => $obs_unit->{trial_name},
        };
        $total_count = $obs_unit->{full_count};
    }

    my %result = (data=>\@data_window);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$total_count,$page);
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


1;

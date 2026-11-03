package CXGN::BrAPI::v1::ObservationUnits;

use Moose;
use JSON;
use CXGN::TimeUtils;
use DateTime;
use CXGN::BrAPI::v2::ObservationUnits;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use Try::Tiny;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Phenotypes::RejectedUnits;
use CXGN::List::Transform;

extends 'CXGN::BrAPI::v1::Common';

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
    my $observation_unit_names_list = $params->{observationUnitName} || ($params->{observationUnitNames} || ());
    my $trait_list_arrayref = $params->{observationVariableDbId} || ($params->{observationVariableDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $folder_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my ($start_time, $end_time, $end_date_only);
    my $valid_bounds = eval {
        for my $pair ([observationTimeStampRangeStart => 'start'], [observationTimeStampRangeEnd => 'end']) {
            my $raw = $params->{$pair->[0]};
            if (ref($raw) eq 'ARRAY') {next if !@$raw; die "A timestamp bound must have one value." if @$raw != 1; $raw=$raw->[0];}
            next unless defined($raw) && length($raw);
            my $normalized = CXGN::TimeUtils::normalize_db_timestamp($raw);
            if ($pair->[1] eq 'start') {$start_time=$normalized;}
            else {
                $end_time=$normalized;
                if ($raw =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
                    $end_date_only=1;
                    $end_time=DateTime->new(year=>$1,month=>$2,day=>$3,time_zone=>'UTC')->add(days=>1)->strftime('%Y-%m-%d %H:%M:%S');
                }
            }
        }
        1;
    };
    return CXGN::BrAPI::JSONResponse->return_error($status,'Invalid observation timestamp range.',400) if !$valid_bounds;

    # not part of brapi standard yet
    # my $phenotype_min_value = $params->{phenotype_min_value};
    # my $phenotype_max_value = $params->{phenotype_max_value};
    # my $exclude_phenotype_outlier = $params->{exclude_phenotype_outlier} || 0;
    # my $search_type = $params->{search_type}->[0] || 'MaterializedViewTable';

    my $lt = CXGN::List::Transform->new();
    my $trait_ids_arrayref = $lt->transform($self->bcs_schema, "traits_2_trait_ids", $trait_list_arrayref)->{transform};

    my $limit = $page_size;
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
            observation_unit_names_list=>$observation_unit_names_list,
            exclude_rejected=>0,   # a listing of the units: a rejected plot stays, without its values (below)
            limit=>$limit,
            offset=>$offset,
            # # Order by plot_number, account for non-numeric plot numbers
            # order_by=>'NULLIF(regexp_replace(plot_number, \'\D\', \'\', \'g\'), \'\')::int',
            # phenotype_min_value=>$phenotype_min_value,
            # phenotype_max_value=>$phenotype_max_value,
            # exclude_phenotype_outlier=>$exclude_phenotype_outlier
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my $rejected_units = CXGN::Phenotypes::RejectedUnits->ids($self->bcs_schema, [ map { $_->{observationunit_stock_id} } @$data ]);
    my $unit_status = CXGN::Phenotypes::RejectedUnits->status_details($self->bcs_schema, [map {$_->{observationunit_stock_id}} @$data]);
    # print STDERR Dumper $data;

    my @data_window;
    my $total_count = 0;
    foreach my $obs_unit (@$data){
        my @brapi_observations;
        # the values of a rejected plot are left out, as in the downloads
        my $observations = $rejected_units->{ $obs_unit->{observationunit_stock_id} } ? [] : $obs_unit->{observations};
        foreach (@$observations){
            my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};
            if (defined($start_time) || defined($end_time)) {
                my $normalized=eval {CXGN::TimeUtils::normalize_db_timestamp($obs_timestamp)};
                next if !defined($normalized) || $@;
                next if defined($start_time) && $normalized lt $start_time;
                next if defined($end_time) && ($end_date_only ? $normalized ge $end_time : $normalized gt $end_time);
            }
            push @brapi_observations, {
                observationDbId => qq|$_->{phenotype_id}|,
                observationVariableDbId => qq|$_->{trait_id}|,
                observationVariableName => $_->{trait_name},
                observationTimeStamp => CXGN::TimeUtils::db_time_to_iso($obs_timestamp),
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
        my $entry_type = $obs_unit->{obsunit_is_a_control} ? 'check' : 'test';
        my $state = $unit_status->{$obs_unit->{observationunit_stock_id}} || {};
        my %info;
        $info{designReplicate} = $obs_unit->{obsunit_design_rep}
            if $obs_unit->{obsunit_design_rep_recorded} || defined($obs_unit->{obsunit_design_rep});
        $info{accessionOccurrence} = $obs_unit->{obsunit_accession_occurrence} if $obs_unit->{obsunit_occurrence_ready};
        $info{notPlanted} = JSON::true if $state->{not_planted};
        $info{rejected} = JSON::true if $state->{rejected};
        $info{rejectReason} = $state->{reject_reason} if defined($state->{reject_reason});
        push @data_window, {
            (%info ? (additionalInfo => \%info) : ()),
            observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
            observationLevel => $obs_unit->{observationunit_type_name},
            observationLevels => $obs_unit->{observationunit_type_name},
            plotNumber => $obs_unit->{obsunit_plot_number},
            plantNumber => $obs_unit->{obsunit_plant_number},
            blockNumber => $obs_unit->{obsunit_block},
            replicate => $obs_unit->{obsunit_rep},
            observationUnitName => $obs_unit->{observationunit_uniquename},
            germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
            germplasmName => $obs_unit->{germplasm_uniquename},
            studyDbId => qq|$obs_unit->{trial_id}|,
            studyName => $obs_unit->{trial_name},
            studyLocationDbId => qq|$obs_unit->{trial_location_id}|,
            studyLocation => $obs_unit->{trial_location_name},
            programName => $obs_unit->{breeding_program_name},
            X => $obs_unit->{obsunit_col_number},
            Y => $obs_unit->{obsunit_row_number},
            entryType => $entry_type,
            entryNumber => '',
            treatments => \@brapi_treatments,
            observations => \@brapi_observations,
            observationUnitXref => [],
            pedigree => undef
        };
        $total_count = $obs_unit->{full_count};
    }

    my %result = (data=>\@data_window);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype search result constructed');
}

# The advertised v1 single-unit endpoints share the atomic writer and its
# authorization rules. Only the published flat DTO field names are adapted.
sub _v2_unit_model {
    my ($self, $c) = @_;
    return CXGN::BrAPI::v2::ObservationUnits->new({
        bcs_schema=>$self->bcs_schema,metadata_schema=>$self->metadata_schema,
        phenome_schema=>$self->phenome_schema,people_schema=>$self->people_schema,
        context=>$c,page=>$self->page,page_size=>$self->page_size,status=>$self->status,
    });
}

sub _flat_unit_dto {
    my ($unit) = @_;
    my $pos=$unit->{observationUnitPosition} || {};
    my $level=$pos->{observationLevel} || {};
    my %levels=map {($_->{levelName} // '')=>$_->{levelCode}} @{$pos->{observationLevelRelationships} || []};
    my $info=$unit->{additionalInfo} || {};
    return {
        observationUnitDbId=>$unit->{observationUnitDbId},observationUnitName=>$unit->{observationUnitName},
        observationLevel=>$level->{levelName},observationLevels=>$level->{levelName},
        plotNumber=>$levels{plot},plantNumber=>$levels{plant},blockNumber=>$levels{block},replicate=>$levels{rep},
        X=>$pos->{positionCoordinateX},Y=>$pos->{positionCoordinateY},entryType=>$pos->{entryType},
        germplasmDbId=>$unit->{germplasmDbId} // $unit->{crossDbId} // $info->{familyDbId},
        germplasmName=>$unit->{germplasmName} // $unit->{crossName} // $info->{familyName},
        studyDbId=>$unit->{studyDbId},studyName=>$unit->{studyName},
        studyLocationDbId=>$unit->{locationDbId},studyLocation=>$unit->{locationName},programName=>$unit->{programName},
        observations=>$unit->{observations} || [],treatments=>$unit->{treatments} || [],
        additionalInfo=>$unit->{additionalInfo},externalReferences=>$unit->{externalReferences} || [],
        observationUnitXref=>[],entryNumber=>'',pedigree=>undef,
    };
}

sub detail {
    my ($self,$id,$c)=@_;
    my $response=$self->_v2_unit_model($c)->detail($id,$c);
    $response->{result}=_flat_unit_dto($response->{result}) if defined($response->{result});
    return $response;
}

sub observationunits_update {
    my ($self,$data,$c,$user_id)=@_;
    return CXGN::BrAPI::JSONResponse->return_error($self->status,'Observation units must be an array.',400) if ref($data) ne 'ARRAY';
    my @adapted;
    for my $p (@$data) {
        return CXGN::BrAPI::JSONResponse->return_error($self->status,'Each observation unit must be an object.',400) if ref($p) ne 'HASH';
        my $unit=decode_json(encode_json($p));
        my $pos=$unit->{observationUnitPosition} // {};
        return CXGN::BrAPI::JSONResponse->return_error($self->status,'observationUnitPosition must be an object.',400) if ref($pos) ne 'HASH';
        $pos->{observationLevel} //= {};
        return CXGN::BrAPI::JSONResponse->return_error($self->status,'observationLevel must be an object.',400) if ref($pos->{observationLevel}) ne 'HASH';
        my $name=$unit->{observationLevel};
        $name=$name->[0] if ref($name) eq 'ARRAY';
        $pos->{observationLevel}{levelName}=$name if defined($name) && $name ne 'all';
        $pos->{positionCoordinateX}=$unit->{X} if exists($unit->{X});
        $pos->{positionCoordinateY}=$unit->{Y} if exists($unit->{Y});
        $pos->{entryType}=$unit->{entryType} if exists($unit->{entryType});
        my $id=$unit->{observationUnitDbId};
        $id=$id->[0] if ref($id) eq 'ARRAY' && @$id == 1;
        return CXGN::BrAPI::JSONResponse->return_error($self->status,'observationUnitDbId must be a positive integer.',400)
            if !defined($id) || ref($id) || $id !~ /^[1-9]\d*$/;
        $unit->{observationUnitDbId}=$id;
        my $stored=$self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$id});
        my $type=$stored ? $stored->type->name : '';
        my $number_field=$type eq 'plant' ? 'plantNumber' : $type eq 'plot' ? 'plotNumber' : undef;
        $pos->{observationLevel}{levelCode}=$unit->{$number_field} if $number_field && exists($unit->{$number_field});
        return CXGN::BrAPI::JSONResponse->return_error($self->status,'observationLevelRelationships must be an array.',400)
            if defined($pos->{observationLevelRelationships}) && ref($pos->{observationLevelRelationships}) ne 'ARRAY';
        my @relations=@{$pos->{observationLevelRelationships} || []};
        return CXGN::BrAPI::JSONResponse->return_error($self->status,'Each level relationship must be an object.',400) if grep {ref($_) ne 'HASH'} @relations;
        for my $pair([blockNumber=>'block'],[replicate=>'rep']) {
            next unless exists($unit->{$pair->[0]});
            if ($pair->[1] eq 'rep') {
                for my $relation (grep {($_->{levelName}//'') eq 'rep' && exists($_->{levelCode})} @relations) {
                    return CXGN::BrAPI::JSONResponse->return_error($self->status,'replicate and rep specify conflicting design groups.',400)
                        if !CXGN::BrAPI::v2::ObservationUnits::_unit_same_group($unit->{replicate}, $relation->{levelCode});
                }
            }
            @relations=grep {($_->{levelName}//'') ne $pair->[1]} @relations;
            push @relations,{levelName=>$pair->[1],levelCode=>$unit->{$pair->[0]}};
        }
        $pos->{observationLevelRelationships}=\@relations;
        $unit->{observationUnitPosition}=$pos;
        push @adapted,$unit;
    }
    my $response=$self->_v2_unit_model($c)->observationunits_update(\@adapted,$c,$user_id);
    if (defined($response->{result}) && ref($response->{result}{data}) eq 'ARRAY') {
        $response->{result}{data}=[map {_flat_unit_dto($_)} @{$response->{result}{data}}];
    }
    return $response;
}


1;

package CXGN::BrAPI::v2::ObservationUnits;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::Trial::TrialLayoutSearch;
use CXGN::Trial::FieldMap;
use CXGN::Trial::AccessionChange;
use CXGN::Trial::DesignReplication;
use CXGN::BreederSearch;
use CXGN::BreedersToolbox::Projects;
use CXGN::People::Person;
use CXGN::BrAPI::DataAuthorization;
use CXGN::JSONUtils qw(decode_stored_json);
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use CXGN::BrAPI::v2::ExternalReferences;
use Try::Tiny;
use CXGN::List::Transform;
use Scalar::Util qw(looks_like_number);
use JSON;


extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $c = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data_files;
    my $result;
    my $total_count = 0;

    my ($data,$total_count, $page_size,$page,$status) = _search($self, $params,  $c);

    my %results = (data=>$data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%results, $pagination, \@data_files, $status, 'Observation Units search result constructed');
}


sub _search {
    my $self = shift;
	my $params = shift;
    my $c = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $total_count = 0;

    my $data_level = $params->{observationUnitLevelName} || ['all'];
    my $years_arrayref = $params->{seasonDbId} || ($params->{seasonDbIds} || ());
    my $location_ids_arrayref = $params->{locationDbId} || ($params->{locationDbIds} || ());
    my $accession_ids_arrayref = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $trait_list_arrayref = $params->{observationVariableName} || ($params->{observationVariableNames} || ());
    my $trait_ids_arrayref = $params->{observationVariableDbId} || ($params->{observationVariableDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $folder_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $start_time = $params->{observationTimeStampRangeStart}->[0] || undef;
    my $end_time = $params->{observationTimeStampRangeEnd}->[0] || undef;
    my $observation_unit_db_id = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
    my $observation_unit_names_list = $params->{observationUnitName} || ($params->{observationUnitNames} || ());
    my $include_observations = $params->{includeObservations} || "False";
    $include_observations = ref($include_observations) eq 'ARRAY' ? ${$include_observations}[0] : $include_observations;
    my $level_order_arrayref = $params->{observationUnitLevelOrder} || ($params->{observationUnitLevelOrders} || ());
    my $level_code_arrayref = $params->{observationUnitLevelCode} || ($params->{observationUnitLevelCodes} || ());
    my $levels_relation_arrayref = $params->{observationLevelRelationships} || ();
    my $levels_arrayref = $params->{observationLevels} || ();
    my $reference_ids_arrayref = $params->{externalReferenceId} || $params->{externalReferenceID} || ($params->{externalReferenceIds} || $params->{externalReferenceIDs} || ());
    my $reference_sources_arrayref = $params->{externalReferenceSource} || ($params->{externalReferenceSources} || ());

    my $study_ids_arrayref = $params->{studyDbId} || ($params->{studyDbIds} || ());

    my $phenotype_additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'phenotype_additional_info', 'phenotype_property')->cvterm_id();
    my $external_references_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'phenotype_external_references', 'phenotype_property')->cvterm_id();
    my $plot_geo_json_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot_geo_json', 'stock_property')->cvterm_id();
    my $stock_additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'stock_additional_info', 'stock_property')->cvterm_id();

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
    my $main_production_site_url = $c->config->{main_production_site_url};

    my $lt = CXGN::List::Transform->new();

    if (!$trait_ids_arrayref && $trait_list_arrayref) {
        $trait_ids_arrayref = $lt->transform($self->bcs_schema, "traits_2_trait_ids", $trait_list_arrayref)->{transform};
    }

    my $limit = $page_size;
    my $offset = $page_size*$page;
    print STDERR "ObservationUnits call Checkpoint 1: ".DateTime->now()."\n";

    my $layout_search = CXGN::Trial::TrialLayoutSearch->new(
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level->[0],
            trial_list=>$study_ids_arrayref,
            location_list=>$location_ids_arrayref,
            accession_list=>$accession_ids_arrayref,
            folder_list=>$folder_ids_arrayref,
            program_list=>$program_ids_arrayref,
            observation_unit_id_list=>$observation_unit_db_id,
            observation_unit_names_list=>$observation_unit_names_list,
            experiment_type=>'field_layout',
            include_observations=>  lc($include_observations) eq 'true' ? 1 : 0,
            xref_id_list=>$reference_ids_arrayref,
            xref_source_list=>$reference_sources_arrayref,
            order_by=> ($c && $c->config->{brapi_ou_order_plot_num}) ? 'NULLIF(regexp_replace(plot_number, \'\D\', \'\', \'g\'), \'\')::numeric' : undef,
            limit=>$limit,
            offset=>$offset,
        }
    );
    my ($data,$observations_data) = $layout_search->search();
    print STDERR "ObservationUnits call Checkpoint 2: ".DateTime->now()."\n";
    #print STDERR Dumper $data;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;

    my @data_window;

    # Get the plot parents of the plants
    my @plant_ids;
    my %plant_parents;
    foreach my $obs_unit (@$data){
        if ($obs_unit->{obsunit_type_name} eq 'plant') {
            push @plant_ids, $obs_unit->{obsunit_stock_id};
        }
    }
    if (@plant_ids && scalar @plant_ids > 0) {
        %plant_parents = $self->_get_plants_plot_parent(\@plant_ids);
    }
    print STDERR "ObservationUnits call Checkpoint 3: ".DateTime->now()."\n";

    # One external-reference query for the whole page instead of one per unit. An empty id list
    # would drop the WHERE clause and read every stock's references, so it is skipped outright.
    my @page_stock_ids = map { $_->{obsunit_stock_id} } @$data;
    my $external_references_by_unit = @page_stock_ids
        ? CXGN::BrAPI::v2::ExternalReferences->new({
            bcs_schema => $self->bcs_schema,
            table_name => 'stock',
            table_id_key => 'stock_id',
            id => \@page_stock_ids
        })->search()
        : {};

    my %index_numbers;
    if (@page_stock_ids) {
        my $h = $self->bcs_schema->storage->dbh->prepare("SELECT stock_id, cvterm.name, value FROM stockprop JOIN cvterm ON cvterm_id = type_id WHERE stock_id = ANY(?) AND cvterm.name IN ('plant_index_number','subplot_index_number','tissue_sample_index_number','range')");
        $h->execute(\@page_stock_ids);
        while (my ($id, $name, $value) = $h->fetchrow_array) {$index_numbers{$id}{$name} = $value;}
    }

    foreach my $obs_unit (@$data){

        ## Formatting observations
        my $brapi_observations = [];

        if( lc $include_observations eq 'true' && $observations_data) {
            my $observation_id = $obs_unit->{obsunit_stock_id};
            $brapi_observations = %{$observations_data}{$observation_id} ?  %{$observations_data}{$observation_id} : [];
        }

        ## Formatting treatments
        my @brapi_treatments;
        foreach my $treatment (@{$obs_unit->{treatments}}) {
            while (my ($treatment_id, $treatment_data) = each %$treatment) {
                push @brapi_treatments, {
                    factor   => $treatment_data->{name}."|".$treatment_id." | value = ".$treatment_data->{value},
                    modality => $treatment_data->{description},
                };
            }
        }

	my %numbers;

        my $entry_type = $obs_unit->{is_a_control} ? 'check' : 'test';
	$numbers{entry_type} = $entry_type;
	
        my $replicate = $obs_unit->{rep};
	$numbers{replicate} = $replicate;
	
        my $block = $obs_unit->{block};
	$numbers{block} = $block;
	
        my $plot;

        my $plant;

        my $tissue_sample;

        my $family_stock_id;

        my $family_name;
        my $additional_info = $obs_unit->{additional_info};
        if (!defined($additional_info) || ref($additional_info) eq 'HASH') {
            $additional_info = {%{$additional_info || {}}};
            delete @{$additional_info}{qw(designReplicate accessionOccurrence)};
            $additional_info->{designReplicate} = $replicate
                if $obs_unit->{design_replicate_recorded} || defined($replicate);
            $additional_info->{accessionOccurrence} = $obs_unit->{accession_occurrence}
                if $obs_unit->{accession_occurrence_ready};
        }
        # Range is backed by its actual stock property.
        my $range = $index_numbers{$obs_unit->{obsunit_stock_id}}{range};
        if (defined($range) || (ref($additional_info) eq 'HASH' && exists($additional_info->{range}))) {
            $additional_info = {%{$additional_info || {}}};
            delete $additional_info->{range};
            $additional_info->{range} = $range if defined($range);
        }

        ## Following code lines add observationUnitParent to additionalInfo, useful for BI
        if ($obs_unit->{obsunit_type_name} eq 'plant') {
            $plant = $obs_unit->{plant_number};

	    $numbers{plant} = $plant;

            if ($plant_parents{$obs_unit->{obsunit_stock_id}}) {
                my $plot_object = $plant_parents{$obs_unit->{obsunit_stock_id}};
                $plot = $plot_object->{plot_number};

		$numbers{plot} = $plot;

                $additional_info->{observationUnitParent} = $plot_object->{id};
            }
        } else {
            $plot = $obs_unit->{plot_number};
	    $numbers{plot} = $plot;
        }

        ## Format position coordinates
        my $level_name = $obs_unit->{obsunit_type_name};

	    # print STDERR "LEVEL NAME: ".Dumper(\%numbers);

        my %index_field = (plant => 'plant_index_number', subplot => 'subplot_index_number', tissue_sample => 'tissue_sample_index_number');
        if ($index_field{$level_name}) {
            $numbers{$level_name} = $index_numbers{$obs_unit->{obsunit_stock_id}}{$index_field{$level_name}} // $numbers{$level_name};
            $numbers{$level_name} = $obs_unit->{plot_number} if $level_name eq 'tissue_sample' && !defined($numbers{$level_name}) && ($obs_unit->{plot_number} // '') =~ /^[A-Za-z]\d+$/;
        }
        my $level_order = _order($level_name) + 0;

        my $level_code = $numbers{$level_name}; ###### eval "\$$level_name" || "";

        if ( $level_order_arrayref &&  ! grep { $_ eq $level_order } @{$level_order_arrayref}  ) { next; }
        if ( $level_code_arrayref &&  ! grep { $_ eq $level_code } @{$level_code_arrayref}  ) { next; }

        my @observationLevelRelationships;
        if (defined($replicate)) {
            push @observationLevelRelationships, {
                levelCode => $replicate,
                levelName => "rep",
                levelOrder => _order("rep"),
            };
        }
        if (defined($block) && $block ne '') {
            push @observationLevelRelationships, {
                levelCode => $block,
                levelName => "block",
                levelOrder => _order("block"),
            }
        }
        if (defined($plot) && $plot ne '') {
            push @observationLevelRelationships, {
                levelCode => qq|$plot|,
                levelName => "plot",
                levelOrder => _order("plot"),
            }
        }
        if (defined($plant) && $plant ne '') {
            push @observationLevelRelationships, {
                levelCode => $plant,
                levelName => "plant",
                levelOrder => _order("plant"),
            }
        }
        if (defined($tissue_sample) && $tissue_sample ne '') {
            push @observationLevelRelationships, {
                levelCode => $tissue_sample,
                levelName => "tissue_sample",
                levelOrder => _order("tissue_sample"),
            }
        }

        my %observationUnitPosition = (
            entryType => $entry_type,
            geoCoordinates => $obs_unit->{plot_geo_json},
            positionCoordinateX => defined($obs_unit->{col_number}) ? $obs_unit->{col_number} + 0 : undef,
            positionCoordinateXType => 'GRID_COL',
            positionCoordinateY => defined($obs_unit->{row_number}) ? $obs_unit->{row_number} + 0 : undef,
            positionCoordinateYType => 'GRID_ROW',
            observationLevel =>  {
                levelName => $level_name,
                levelOrder => $level_order,
                levelCode => $level_code,
            },
            observationLevelRelationships => \@observationLevelRelationships,
        );

        my $brapi_observationUnitPosition = decode_json(encode_json \%observationUnitPosition);

        #Get external references, already fetched for the whole page above
        my $formatted_external_references = $external_references_by_unit->{$obs_unit->{obsunit_stock_id}} || [];

        if ($obs_unit->{family_stock_id}) {
            $additional_info->{familyDbId} = qq|$obs_unit->{family_stock_id}|;
            $additional_info->{familyName} = $obs_unit->{family_uniquename};
        }

        ## Get intercropping accessions
        if ($obs_unit->{intercrop_stocks}) {
            my @intercrop;
            foreach my $i (@{$obs_unit->{intercrop_stocks}}) {
                push(@intercrop, { germplasmDbId => $i->{id}, germplasmName => $i->{name} });
            }
            $additional_info->{intercropGermplasm} = \@intercrop if scalar(@intercrop) > 0;
        }

        push @data_window, {
            externalReferences => $formatted_external_references,
            additionalInfo => $additional_info,
            germplasmDbId => $obs_unit->{germplasm_stock_id} ? qq|$obs_unit->{germplasm_stock_id}| : undef,
            germplasmName => $obs_unit->{germplasm_uniquename} ? qq|$obs_unit->{germplasm_uniquename}| : undef,
            crossDbId => $obs_unit->{cross_stock_id} ? qq|$obs_unit->{cross_stock_id}| : undef,
            crossName => $obs_unit->{cross_uniquename} ? qq|$obs_unit->{cross_uniquename}| : undef,
            locationDbId => qq|$obs_unit->{location_id}|,
            locationName => $obs_unit->{location_name},
            observationUnitDbId => qq|$obs_unit->{obsunit_stock_id}|,
            observations => $brapi_observations,
            observationUnitName => $obs_unit->{obsunit_uniquename},
            observationUnitPosition => $brapi_observationUnitPosition,
            observationUnitPUI => $main_production_site_url . "/stock/" . $obs_unit->{obsunit_stock_id} . "/view",
            programName => $obs_unit->{breeding_program_name},
            programDbId => qq|$obs_unit->{breeding_program_id}|,
            seedLotDbId => $obs_unit->{seedlot_id} ? qq|$obs_unit->{seedlot_id}| : undef,
            seedLotName => $obs_unit->{seedlot_name} ? qq|$obs_unit->{seedlot_name}| : undef,
            studyDbId => qq|$obs_unit->{trial_id}|,
            studyName => $obs_unit->{trial_name},
            plotImageDbIds => $obs_unit->{image_ids},
            treatments => \@brapi_treatments,
            trialDbId => $obs_unit->{folder_id} ? qq|$obs_unit->{folder_id}| : qq|$obs_unit->{trial_id}|,
            trialName => $obs_unit->{folder_name} ? $obs_unit->{folder_name} : $obs_unit->{trial_name},
        };
        $total_count = $obs_unit->{full_count};

    }
    print STDERR "ObservationUnits call Checkpoint 4: ".DateTime->now()."\n";
    my $results = (data=>\@data_window);

    return ($results,$total_count, $page_size,$page,$status);
}

sub _get_plants_plot_parent {
    my $self = shift;
    my $plant_id_array = shift;
    my $schema = $self->bcs_schema;

    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $plant_ids_string = join ',', @{$plant_id_array};
    my $select = "select stock.stock_id, stock_relationship.subject_id, stockprop.value from stock join stock_relationship on stock.stock_id = stock_relationship.object_id join stockprop on stock_relationship.subject_id = stockprop.stock_id where stockprop.type_id = $plot_number_cvterm_id and stock_relationship.type_id = $plant_cvterm_id and stock.stock_id in ($plant_ids_string);";
    my $h = $schema->storage->dbh()->prepare($select);
    $h->execute();

    my %plant_hash;
    while (my ($plant_id, $plot_id, $plot_number) = $h->fetchrow_array()) {
        $plant_hash{$plant_id} = { id => $plot_id, plot_number => $plot_number };
    }

    return %plant_hash;
}

sub detail {
    my $self = shift;
    my $observation_unit_db_id = shift;
    my $c = shift;

    my $search_params = {
        observationUnitDbIds => [ $observation_unit_db_id ],
        includeObservations  => 'true'
    };

    my @data_files;
    my ($data,$total_count, $page_size,$page,$status) = _search($self, $search_params,  $c);
    return CXGN::BrAPI::JSONResponse->return_error($self->status, 'ObservationUnitDbId not found', 404) if !$data || !@$data;
    my $results = $data->[0];
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success($results, $pagination, \@data_files, $status, 'Observation Units search result constructed');
}

sub _unit_fail { die { error => $_[0], code => $_[1] || 400 }; }

sub _unit_scalar {
    my ($value, $field) = @_;
    if (ref($value) eq 'ARRAY') {
        _unit_fail("$field must contain one value.") if @$value != 1;
        $value = $value->[0];
    }
    _unit_fail("$field must be a scalar value.") if ref($value);
    return $value;
}

sub _unit_same_group {
    my ($a, $b) = @_;
    return !defined($a) && !defined($b) if !defined($a) || !defined($b);
    return "$a" eq "$b";
}

sub _unit_design_group_request {
    my ($pos, $info) = @_;
    my @values;
    _unit_fail('designReplicate must be a scalar or null.') if exists($info->{designReplicate}) && ref($info->{designReplicate});
    push @values, _unit_scalar($info->{designReplicate}, 'designReplicate') if exists($info->{designReplicate});
    if (exists($pos->{observationLevelRelationships})) {
        _unit_fail('observationLevelRelationships must be an array.') if ref($pos->{observationLevelRelationships}) ne 'ARRAY';
        for my $relation (@{$pos->{observationLevelRelationships}}) {
            _unit_fail('Each level relationship must be an object.') if ref($relation) ne 'HASH';
            next if ($relation->{levelName} // '') ne 'rep' || !exists($relation->{levelCode});
            push @values, _unit_scalar($relation->{levelCode}, 'rep levelCode');
        }
    }
    _unit_fail('rep and designReplicate specify conflicting design groups.')
        if @values > 1 && grep {!_unit_same_group($_, $values[0])} @values[1..$#values];
    return {present => @values ? 1 : 0, value => $values[0]};
}

sub _unit_block_request {
    my ($pos) = @_;
    my @values;
    if (exists($pos->{observationLevelRelationships})) {
        _unit_fail('observationLevelRelationships must be an array.') if ref($pos->{observationLevelRelationships}) ne 'ARRAY';
        for my $relation (@{$pos->{observationLevelRelationships}}) {
            _unit_fail('Each level relationship must be an object.') if ref($relation) ne 'HASH';
            next if ($relation->{levelName} // '') ne 'block' || !exists($relation->{levelCode});
            push @values, _unit_scalar($relation->{levelCode}, 'block levelCode');
        }
    }
    _unit_fail('The request specifies conflicting block groups.')
        if @values > 1 && grep {!_unit_same_group($_, $values[0])} @values[1..$#values];
    return {present=>@values ? 1:0, value=>$values[0]};
}

sub _unit_blocks {
    my ($self, $ids) = @_;
    return {} if !@$ids;
    my $type=SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'block', 'stock_property')->cvterm_id;
    my $rows=$self->bcs_schema->storage->dbh->selectall_arrayref(
        'SELECT stock_id,value FROM stockprop WHERE stock_id=ANY(?) AND type_id=? ORDER BY stock_id,rank',undef,$ids,$type);
    my %values=map {$_=>undef} @$ids;
    my %seen;
    for my $row (@$rows) {
        _unit_fail('An observation unit has multiple block values; correct its layout metadata first.') if $seen{$row->[0]}++;
        $values{$row->[0]}=$row->[1];
    }
    return \%values;
}

sub _unit_inherited_metadata_updates {
    my ($self, $updates, $trials, $property) = @_;
    my $schema=$self->bcs_schema;
    my %inherited;
    for my $trial (keys %$trials) {
        my $service=CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial});
        my $children=$service->_children($trials->{$trial});
        for my $root (keys %$children) {
            $inherited{$_->{stock_id}}{$trial}=1 for @{$children->{$root}{in_trial} || []};
        }
    }
    return $updates if !%inherited;
    # Keep every structural plot ancestor, including plots outside this field.
    # Equal text tags in different field contexts do not identify one group.
    my $roots=$schema->storage->dbh->selectall_arrayref(q{
        WITH RECURSIVE ancestry(unit_id,stock_id) AS (
            SELECT id,id FROM unnest(?::integer[]) id
          UNION
            SELECT a.unit_id,parent.stock_id FROM ancestry a
            JOIN stock child ON child.stock_id=a.stock_id
            JOIN cvterm ct ON ct.cvterm_id=child.type_id
            JOIN stock_relationship r ON
                (ct.name IN ('plant','subplot') AND r.object_id=a.stock_id)
                OR (ct.name='tissue_sample' AND r.subject_id=a.stock_id)
            JOIN cvterm rt ON rt.cvterm_id=r.type_id
            JOIN stock parent ON parent.stock_id=CASE WHEN ct.name='tissue_sample' THEN r.object_id ELSE r.subject_id END
            JOIN cvterm pt ON pt.cvterm_id=parent.type_id
            WHERE ((ct.name='plant' AND rt.name='plant_of') OR
                   (ct.name='subplot' AND rt.name='subplot_of') OR
                   (ct.name='tissue_sample' AND rt.name='tissue_sample_of'))
                AND pt.name IN ('plot','plant','subplot','tissue_sample')
        ) SELECT DISTINCT a.unit_id,a.stock_id FROM ancestry a
          JOIN stock s ON s.stock_id=a.stock_id
          JOIN cvterm st ON st.cvterm_id=s.type_id AND st.name='plot'
    },undef,[keys %inherited]);
    my (%parents,%ids);
    for my $row (@$roots) {$parents{$row->[0]}{$row->[1]}=1;$ids{$row->[1]}=1}
    my $contexts=CXGN::Trial::DesignReplication::read($schema,[keys(%ids),keys(%inherited)]);
    my $field=$property eq 'block' ? 'block' : 'value';
    my $values={map {$_=>$contexts->{$_}{$field}} keys %ids};
    for my $id (keys %inherited) {
        my @fields=@{$contexts->{$id}{field_projects} || []};
        my @expected=keys %{$inherited{$id}};
        my $same_field=@fields==1 && @expected==1 && $fields[0]==$expected[0] && $parents{$id};
        my (%known,$unknown);
        for my $parent (keys %{$parents{$id} || {}}) {
            my @parent_fields=@{$contexts->{$parent}{field_projects} || []};
            $same_field=0 if @parent_fields!=1 || !@fields || $parent_fields[0]!=$fields[0];
            my $value=exists($updates->{$parent}) ? $updates->{$parent} : $values->{$parent};
            defined($value) ? $known{$value}++ : $unknown++;
        }
        # Divergent or partially unknown grouping is valid pooled metadata.
        # It is represented as unknown, not an arbitrary parent or a refusal.
        $updates->{$id}=$same_field && !$unknown && keys(%known)==1 ? (keys %known)[0] : undef;
    }
    return $updates;
}

sub _unit_design_group_updates {
    my ($self, $prepared) = @_;
    my (%updates,%trials);
    for my $unit (@$prepared) {
        next if !$unit->{group_change};
        $updates{$unit->{id}}=$unit->{design_group};
        next if $unit->{type} ne 'plot';
        my $trial=CXGN::Trial::AccessionChange->field_trial_of_plot($self->bcs_schema,$unit->{id});
        push @{$trials{$trial}},$unit->{id} if $trial;
    }
    return $self->_unit_inherited_metadata_updates(\%updates,\%trials,'design_replicate');
}

sub _unit_block_updates {
    my ($self,$prepared) = @_;
    my @ids=map {$_->{id}} @$prepared;
    my $contexts=CXGN::Trial::DesignReplication::read($self->bcs_schema,\@ids);
    my $current={map {$_=>$contexts->{$_}{block}} @ids};
    my (%updates,%trials);
    for my $unit (@$prepared) {
        my $request=_unit_block_request($unit->{pos});
        next if !$request->{present} || _unit_same_group($request->{value},$current->{$unit->{id}});
        _unit_fail('The block group is inherited from the parent plot; edit the parent plot.')
            if $unit->{type} ne 'plot' && @{$contexts->{$unit->{id}}{field_projects} || []};
        $updates{$unit->{id}}=$request->{value};
        next if $unit->{type} ne 'plot';
        my $trial=CXGN::Trial::AccessionChange->field_trial_of_plot($self->bcs_schema,$unit->{id});
        push @{$trials{$trial}},$unit->{id} if $trial;
    }
    return $self->_unit_inherited_metadata_updates(\%updates,\%trials,'block');
}

sub _unit_creation_block {
    my ($self,$unit,$parent) = @_;
    my $request=_unit_block_request($unit->{observationUnitPosition} || {});
    my $block=CXGN::Trial::DesignReplication::read($self->bcs_schema,[$parent])->{$parent}{block};
    _unit_fail('The block group is inherited from the parent plot; use its current block.')
        if $request->{present} && !_unit_same_group($request->{value},$block);
    $unit->{_creation_block}=$block;
    return $block;
}

sub _unit_set_created_child_block {
    my ($self,$id,$unit) = @_;
    _unit_fail('The parent block was not validated before child creation.') if !exists($unit->{_creation_block});
    $self->_unit_prop($id,'block',$unit->{_creation_block});
}

sub _unit_set_design_groups {
    my ($self,$updates,$state) = @_;
    my @ids=sort {$a<=>$b} keys %$updates;
    return if !@ids;
    my $current=CXGN::Trial::DesignReplication::read($self->bcs_schema,\@ids);
    for my $stock_id (@ids) {
        my $value=$updates->{$stock_id};
        next if $current->{$stock_id}{recorded} && _unit_same_group($current->{$stock_id}{value},$value);
        CXGN::Trial::DesignReplication::set($self->bcs_schema,$stock_id,$value);
        $self->{_unit_writes}++;
    }
    $state->{projects}{$_}=1 for @{$self->_unit_projects(\@ids)};
}

sub _unit_set_blocks {
    my ($self,$updates,$state) = @_;
    my @ids=sort {$a<=>$b} keys %$updates;
    return if !@ids;
    my $current=$self->_unit_blocks(\@ids);
    for my $id (@ids) {
        next if _unit_same_group($updates->{$id},$current->{$id});
        $self->_unit_prop($id,'block',$updates->{$id});
    }
    $state->{projects}{$_}=1 for @{$self->_unit_projects(\@ids)};
}

sub _unit_boolean {
    my ($value, $field) = @_;
    return undef if !defined($value) || (!ref($value) && $value =~ /^\s*$/); ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    if (ref($value)) {
        return $value ? 1 : 0 if ref($value) =~ /^(?:JSON::(?:XS|PP)::Boolean|Types::Serialiser::Boolean)$/;
        _unit_fail("$field must be true or false.");
    }
    return 1 if $value =~ /^\s*(?:1|true|yes|t|y)\s*$/i;
    return 0 if $value =~ /^\s*(?:0|false|no|f|n)\s*$/i;
    _unit_fail("$field must be true or false.");
}

sub _unit_validate_additional_fields {
    my ($info) = @_;
    my @unsupported = grep {exists($info->{$_})} qw(notPlanted rejected rejectReason);
    _unit_fail('Unsupported observation-unit additionalInfo field(s): '.join(', ', @unsupported).'.') if @unsupported;
}

sub _unit_prop {
    my ($self, $stock_id, $name, @value) = @_;
    my $schema = $self->bcs_schema;
    my $type = SGN::Model::Cvterm->get_cvterm_row($schema, $name, 'stock_property');
    _unit_fail("The database does not know stock property $name.") if !$type;
    my $rs = $schema->resultset('Stock::Stockprop')->search({stock_id => $stock_id, type_id => $type->cvterm_id});
    my @old = $rs->all;
    _unit_fail("Observation unit $stock_id has multiple $name values; correct its layout metadata first.") if @old > 1;
    if (@value) {
        return undef if !@old && !defined($value[0]); ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
        return $old[0]->value if @old && (
            (!defined($value[0]) && !defined($old[0]->value))
            || (defined($value[0]) && defined($old[0]->value) && $old[0]->value eq $value[0]));
        if (defined($value[0])) {
            if (@old) { $old[0]->update({value => $value[0]}); }
            else { $schema->resultset('Stock::Stockprop')->create({stock_id => $stock_id, type_id => $type->cvterm_id, value => $value[0], rank => 0}); }
        } else {
            $old[0]->delete if @old;
        }
        $self->{_unit_writes}++;
    }
    my $row = $rs->first;
    return $row ? $row->value : undef;
}

sub _unit_projects {
    my ($self, $ids) = @_;
    return [] unless @$ids;
    return $self->bcs_schema->storage->dbh->selectcol_arrayref('SELECT DISTINCT project_id FROM nd_experiment_stock JOIN nd_experiment_project USING(nd_experiment_id) WHERE stock_id = ANY(?) ORDER BY project_id', undef, $ids);
}

sub _unit_error_response {
    my ($self, $error) = @_;
    my $message = ref($error) eq 'HASH' ? ($error->{error} || 'The request could not be applied.') : "$error";
    my $code = ref($error) eq 'HASH' ? ($error->{code} || $error->{errorCode} || 400) : 400;
    $message =~ s/\s+at \/\S+ line \d+\.?//g; $message =~ s/\s+$//;
    $message =~ s/^Nothing was changed:\s*//;
    return CXGN::BrAPI::JSONResponse->return_error($self->status, 'Nothing was changed: '.$message, $code);
}

sub _unit_validate_references {
    my ($refs) = @_;
    my $error = CXGN::BrAPI::v2::ExternalReferences::validate_payload($refs);
    _unit_fail($error->{error}, $error->{code}) if $error;
}

sub _unit_resolve_germplasm {
    my ($self, $id, $name) = @_;
    my $schema = $self->bcs_schema;
    $id = _unit_scalar($id, 'germplasmDbId'); $name = _unit_scalar($name, 'germplasmName');
    my $rs;
    if (defined($id) && length($id)) {
        _unit_fail('germplasmDbId must be a positive integer.') unless $id =~ /^[1-9]\d*$/;
        $rs = $schema->resultset('Stock::Stock')->search({stock_id => $id});
    } elsif (defined($name) && length($name)) {
        my @types = map {SGN::Model::Cvterm->get_cvterm_row($schema, $_, 'stock_type')->cvterm_id} qw(accession cross family_name);
        $rs = $schema->resultset('Stock::Stock')->search({uniquename => $name, type_id => {-in => \@types}, is_obsolete => 0});
    } else { _unit_fail('Either germplasmDbId or germplasmName is required.'); }
    _unit_fail('Germplasm does not exist.', 404) if !$rs->count;
    _unit_fail('The germplasm name is ambiguous; supply germplasmDbId.', 409) if $rs->count != 1;
    my $stock = $rs->first;
    _unit_fail('germplasmDbId and germplasmName identify different stocks.') if defined($name) && length($name) && $name ne $stock->uniquename;
    return {id => $stock->stock_id, name => $stock->uniquename};
}

sub _unit_old_germplasm {
    my ($self, $id) = @_;
    my $rows = $self->bcs_schema->storage->dbh->selectall_arrayref(q{
        SELECT DISTINCT g.stock_id FROM stock_relationship r
        JOIN cvterm rt ON rt.cvterm_id = r.type_id
        JOIN stock g ON g.stock_id = r.object_id JOIN cvterm gt ON gt.cvterm_id = g.type_id
        WHERE r.subject_id = ? AND rt.name IN ('plot_of','plant_of','subplot_of','tissue_sample_of')
          AND gt.name IN ('accession','cross','family_name')
    }, undef, $id);
    _unit_fail('The observation unit is not linked to exactly one germplasm stock.') if @$rows != 1;
    return $rows->[0][0];
}

sub _unit_batch_germplasms {
    my ($groups)=@_;
    my %final;
    for my $group (values %$groups) {
        for my $change (@{$group->{changes}}) {
            $final{$change->{plot_id}}=$change->{new_stock_id} if defined($change->{new_stock_id});
        }
    }
    return \%final;
}

sub _unit_apply_service_groups {
    my ($self, $groups, $user_id, $state, $locked_projects, $locked_lots) = @_;
    my $schema = $self->bcs_schema;
    my %roles = map {$_ => 1} CXGN::People::Person->new($schema->storage->dbh, $user_id)->get_roles;
    for my $trial_id (sort {$a <=> $b} keys %$groups) {
        my $g = $groups->{$trial_id};
        my $svc = CXGN::Trial::AccessionChange->new({schema => $schema, trial_id => $trial_id, _final_stock_by_plot=>_unit_batch_germplasms($groups), _locked_projects=>$locked_projects, _locked_seedlots=>$locked_lots});
        my $options = {rename_plots => 'none', curator => $roles{curator} ? 1 : 0};
        my $plan = $svc->plan($g->{changes}, $options);
        _unit_fail(join(' ', @{$plan->{errors}})) if @{$plan->{errors}};
        next if !@{$plan->{changes}};
        my $precheck = CXGN::Trial::FieldMap->new({bcs_schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout'})->update_fieldmap_precheck;
        _unit_fail($precheck, 403) if $precheck && !$roles{curator};
        push @{$state->{warnings}},'Curator correction: '.$precheck if $precheck;
        $plan = $svc->apply($g->{changes}, $options);
        push @{$state->{warnings}},@{$plan->{warnings} || []};
        $state->{changed} = 1;
        $state->{projects}{$_} = 1 for $trial_id, @{$plan->{affected_project_ids} || []};
        $state->{fullview} = 1 if @{$plan->{external_samples} || []};
    }
}

sub _unit_apply_updates {
    my ($self, $data, $user_id, $state, $locked_projects, $locked_lots) = @_;
    my $schema = $self->bcs_schema;
    _unit_fail('The request must contain observation-unit objects.') if ref($data) ne 'ARRAY' || !@$data;
    my (@ids, %seen);
    for my $p (@$data) {
        _unit_fail('Each observation unit must be an object.') if ref($p) ne 'HASH';
        my $id = _unit_scalar($p->{observationUnitDbId}, 'observationUnitDbId');
        _unit_fail('observationUnitDbId must be a positive integer.') if !defined($id) || $id !~ /^[1-9]\d*$/;
        _unit_fail('The same observation unit appears more than once in the request.') if $seen{$id}++;
        push @ids, $id;
    }
    my $auth = CXGN::BrAPI::DataAuthorization::observation_units_error($schema, $user_id, \@ids);
    die $auth if $auth;
    my $projects = $self->_unit_projects(\@ids);
    # Prepare without writes, compute the complete source/descendant closure,
    # then lock it canonically and prepare again from the protected state.
    $state->{projects}{$_} = 1 for @$projects;
    my $replication = CXGN::Trial::DesignReplication::read($schema, \@ids);
    my (%groups, @prepared);
    for my $p (@$data) {
        my $id = _unit_scalar($p->{observationUnitDbId}, 'observationUnitDbId');
        my $stock = $schema->resultset('Stock::Stock')->find({stock_id => $id});
        my $type = $stock->type->name;
        _unit_fail('Only plot, plant, subplot and tissue_sample units can be updated.') if $type !~ /^(?:plot|plant|subplot|tissue_sample)$/;
        my $pos = $p->{observationUnitPosition} // {};
        my $info = $p->{additionalInfo} // {};
        _unit_fail('observationUnitPosition and additionalInfo must be objects.') if ref($pos) ne 'HASH' || ref($info) ne 'HASH';
        _unit_validate_additional_fields($info);
        _unit_fail('observationLevel must be an object.') if exists($pos->{observationLevel}) && ref($pos->{observationLevel}) ne 'HASH';
        my $level = $pos->{observationLevel} || {};
        my $replication_state = $replication->{$id} || {};
        my $design_group = _unit_design_group_request($pos, $info);
        if (exists($info->{accessionOccurrence})) {
            _unit_fail('accessionOccurrence must be a scalar or null.') if ref($info->{accessionOccurrence});
            my $echo = _unit_scalar($info->{accessionOccurrence}, 'accessionOccurrence');
            _unit_fail('accessionOccurrence is assigned by the field layout and cannot be changed.')
                if $replication_state->{occurrence_ready}
                    ? !_unit_same_group($echo, $replication_state->{occurrence}) : defined($echo);
        }
        # A flat v1 GET contains replicate:null even for an unrecorded legacy
        # group. Its unchanged PUT must not create a metadata write.
        my $group_change = $design_group->{present} &&
            !_unit_same_group($design_group->{value}, $replication_state->{value});
        _unit_fail('The design group is inherited from the parent plot; edit the parent plot.')
            if $group_change && $type ne 'plot' && @{$replication_state->{field_projects} || []};
        _unit_fail('The observation level does not match the stored unit type.') if defined($level->{levelName}) && $level->{levelName} ne $type;
        _unit_fail('Observation-unit renaming is not supported by this update.') if defined($p->{observationUnitName}) && $p->{observationUnitName} ne $stock->uniquename;
        my $old_control = _unit_boolean($self->_unit_prop($id, 'is a control'), 'stored control') || 0;
        my $control = exists($info->{control}) ? _unit_boolean($info->{control}, 'control') : undef;
        if (defined($pos->{entryType}) && length($pos->{entryType})) {
            _unit_fail('entryType must be CHECK or TEST.') if ref($pos->{entryType}) || $pos->{entryType} !~ /^(?:CHECK|TEST)$/i;
            $control = uc($pos->{entryType}) eq 'CHECK' ? 1 : 0;
        }
        my %change = (plot_id => $id);
        my $identity = 0;
        if (defined($p->{germplasmDbId}) || defined($p->{germplasmName})) {
            my $target = $self->_unit_resolve_germplasm($p->{germplasmDbId}, $p->{germplasmName});
            if ($target->{id} != $self->_unit_old_germplasm($id)) {
                _unit_fail('Germplasm can only be changed for plots.') if $type ne 'plot';
                $change{new_stock_id} = $target->{id}; $identity = 1;
            }
        }
        if (keys(%change) > 1) {
            my $trial = CXGN::Trial::AccessionChange->field_trial_of_plot($schema, $id);
            _unit_fail('The plot is not part of a field trial.') if !$trial;
            push @{$groups{$trial}{changes}}, \%change;
            $groups{$trial}{identity_change} ||= $identity;
        }
        _unit_validate_references($p->{externalReferences}) if exists($p->{externalReferences});
        my %old = (replicate=>$replication_state->{value}, block=>$replication_state->{block});
        push @prepared, {params => $p, id => $id, type => $type, pos => $pos, info => $info, control => $control, old_control => $old_control, old => \%old, identity => $identity, group_change=>$group_change, design_group=>$design_group->{value}};
    }
    my $design_updates = $self->_unit_design_group_updates(\@prepared);
    my $block_updates = $self->_unit_block_updates(\@prepared);
    my %inherited_ids=map {$_=>1} keys %$design_updates,keys %$block_updates;
    if (%inherited_ids) {
        my $inherited_auth=CXGN::BrAPI::DataAuthorization::observation_units_error($schema,$user_id,[keys %inherited_ids]);
        die $inherited_auth if $inherited_auth;
    }
    my %required=map {$_=>1} @$projects;
    $required{$_}=1 for @{$self->_unit_projects([keys %$design_updates,keys %$block_updates])};
    my %roles=map {$_=>1} CXGN::People::Person->new($schema->storage->dbh,$user_id)->get_roles;
    my $final_stock=_unit_batch_germplasms(\%groups);
    my %required_lots;
    for my $trial_id (sort {$a<=>$b} keys %groups) {
        my $service=CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial_id,_final_stock_by_plot=>$final_stock});
        my $plan=$service->plan($groups{$trial_id}{changes},{rename_plots=>'none',curator=>$roles{curator} ? 1:0});
        _unit_fail(join(' ',@{$plan->{errors}})) if @{$plan->{errors}};
        $required{$_}=1 for @{$plan->{affected_project_ids} || []};
        $required_lots{$_}=1 for @{$service->seedlot_ids_for_plan($plan)};
    }
    if (!defined($locked_projects)) {
        my @closure=sort {$a<=>$b} keys %required;
        $schema->storage->dbh->selectcol_arrayref('SELECT project_id FROM project WHERE project_id=ANY(?) ORDER BY project_id FOR UPDATE',undef,\@closure);
        # Global write order: projects, packet lots, observation units, then
        # relationship rows. The shared transaction writer takes the same order.
        CXGN::Stock::Seedlot::lock_for_recount($schema,[keys %required_lots]);
        $schema->storage->dbh->selectcol_arrayref('SELECT stock_id FROM stock WHERE stock_id=ANY(?) ORDER BY stock_id FOR UPDATE',undef,\@ids);
        return $self->_unit_apply_updates($data,$user_id,$state,\%required,\%required_lots);
    }
    _unit_fail('Layout membership changed while locking this batch; retry the request.',409)
        if grep {!$locked_projects->{$_}} keys %required;
    _unit_fail('Packet lots changed while locking this batch; retry the request.',409)
        if grep {!$locked_lots->{$_}} keys %required_lots;
    $self->_unit_apply_service_groups(\%groups, $user_id, $state, $locked_projects, $locked_lots);
    $self->_unit_set_design_groups($design_updates, $state);
    $self->_unit_set_blocks($block_updates, $state);
    for my $u (@prepared) {
        my ($p, $id, $pos, $info) = @{$u}{qw(params id pos info)};
        my $control = $u->{control};
        if ($u->{identity} && defined($control)) {
            # A complete GET object carries the old check marker. It must not
            # undo the service's check/accession inference after a correction.
            $control = undef if $control == $u->{old_control};
            _unit_fail('Control conflicts with the corrected germplasm.') if defined($control) && $control != (_unit_boolean($self->_unit_prop($id,'is a control'),'stored control') || 0);
        }
        my $current_control = _unit_boolean($self->_unit_prop($id, 'is a control'), 'stored control') || 0;
        $self->_unit_prop($id, 'is a control', "$control") if defined($control) && $control != $current_control;
        for my $pair ([positionCoordinateY => 'row_number'], [positionCoordinateX => 'col_number']) {
            next unless exists($pos->{$pair->[0]});
            $self->_unit_prop($id, $pair->[1], _unit_scalar($pos->{$pair->[0]}, $pair->[0]));
        }
        if (exists($pos->{geoCoordinates})) {
            _unit_fail('geoCoordinates must be an object or null.') if defined($pos->{geoCoordinates}) && ref($pos->{geoCoordinates}) ne 'HASH';
            $self->_unit_prop($id, 'plot_geo_json', defined($pos->{geoCoordinates}) ? encode_json($pos->{geoCoordinates}) : undef);
        }
        my $level = $pos->{observationLevel} || {};
        if (defined($level->{levelCode}) && length($level->{levelCode})) {
            my $number = _unit_scalar($level->{levelCode}, 'levelCode');
            my %field = (plot => 'plot number', plant => 'plant_index_number', subplot => 'subplot_index_number', tissue_sample => 'tissue_sample_index_number');
            $number = $1 if $u->{type} eq 'plant' && $number =~ /^plant_(\d+)$/;
            if ($u->{type} eq 'tissue_sample' && $number =~ /^[A-Za-z]\d+$/) {
                $self->_unit_prop($id, 'plot number', $number); # genotyping well code
            } else {
                # BrAPI plot codes are literal labels; child indexes remain numeric.
                _unit_fail('The stored unit numbering requires a positive integer.')
                    if $u->{type} ne 'plot' && $number !~ /^[1-9]\d*$/;
                $self->_unit_prop($id, $field{$u->{type}}, $number);
            }
        }
        # Replication/block relationships were validated together and applied
        # once above, including inherited children and deliberate NULL clears.
        $self->_unit_prop($id, 'range', _unit_scalar($info->{range}, 'range')) if exists($info->{range});
        my %reserved = map {$_ => 1} qw(observationUnitParent control range familyDbId familyName intercropGermplasm designReplicate accessionOccurrence);
        my %extra = map {$_ => $info->{$_}} grep {!$reserved{$_}} keys %$info;
        if (%extra) {
            my $old = $self->_unit_prop($id, 'stock_additional_info');
            my $decoded = defined($old) ? decode_stored_json($old) : {};
            _unit_fail('Stored additionalInfo is not an object.') if ref($decoded) ne 'HASH';
            $self->_unit_prop($id, 'stock_additional_info', encode_json({%$decoded, %extra}));
        }
        if (exists($p->{externalReferences}) && defined($p->{externalReferences})) {
            my $references = CXGN::BrAPI::v2::ExternalReferences->new({bcs_schema=>$schema,table_name=>'stock',table_id_key=>'stock_id',id=>"$id",external_references=>$p->{externalReferences}});
            my $existing = $references->search->{$id} || [];
            my $json = JSON->new->canonical;
            if ($json->encode($existing) ne $json->encode($p->{externalReferences})) {
                my $result = $references->store;
                _unit_fail($result->{error}, $result->{code} || 400) if $result->{error};
                $self->{_unit_writes}++;
            }
        }
    }
    $state->{changed} ||= $self->{_unit_writes};
    $state->{ids} = \@ids;
}

sub _unit_regenerate_layouts {
    my ($self, $state) = @_;
    return if !$state->{changed};
    for my $id (sort {$a <=> $b} keys %{$state->{projects}}) {
        my $schema = $self->bcs_schema;
        my $design = $schema->resultset('Project::Projectprop')->find({project_id=>$id,type_id=>SGN::Model::Cvterm->get_cvterm_row($schema,'design','project_property')->cvterm_id});
        next unless $design;
        my $kind = CXGN::Trial->new({bcs_schema=>$schema,trial_id=>$id})->get_cxgn_project_type->{experiment_type};
        CXGN::Trial::TrialLayout->new({schema=>$schema,trial_id=>$id,experiment_type=>$kind})->generate_and_cache_layout;
    }
}

sub _unit_finish_request {
    my ($self, $c, $state) = @_;
    $self->page(0);
    $self->page_size(scalar @{$state->{ids}}) if @{$state->{ids}} > $self->page_size;
    return $self->search({observationUnitDbIds=>$state->{ids}},$c) if !$state->{changed};
    my $refresh = CXGN::BreederSearch->new({dbh=>$c->dbc->dbh,dbname=>$c->config->{dbname}})->refresh_matviews_after_change($c->config->{dbhost},$c->config->{dbname},$c->config->{dbuser},$c->config->{dbpass},$state->{fullview} ? 'fullview' : 'phenotypes','concurrent',$c->config->{basepath});
    # Also clear on refresh failure: no old completed result is advertised as
    # current. This response reads live unit metadata and never recaches an
    # analytical result while its refresh is pending.
    my $cleared = eval {$c->controller('solGS::clearCache')->clear_cached_analyses_result($c,{trials=>[sort {$a <=> $b} keys %{$state->{projects}}]})};
    my $response = $self->search({observationUnitDbIds=>$state->{ids}},$c);
    my %warning_seen;
    for my $message (@{$state->{warnings} || []}) {
        next if $warning_seen{$message}++;
        push @{$response->{status}},{messageType=>'WARNING',message=>$message};
    }
    if ($refresh->{refresh_pending} || $refresh->{error} || !$cleared) {
        push @{$response->{status}}, {messageType=>'WARNING',message=>'Changes saved; analytical refresh needs retry before using analytical results.'};
        $response->{http_code} = 200;
        $response->{refresh_pending} = 1;
        $response->{result}{changesSaved} = JSON::true;
        $response->{result}{refreshPending} = JSON::true;
    }
    return $response;
}

sub observationunits_update {
    my ($self, $data, $c, $user_id) = @_;
    my $state = {projects=>{},ids=>[]};
    $self->{_unit_writes} = 0;
    my $ok = eval {
        $self->bcs_schema->txn_do(sub {
            $self->_unit_apply_updates($data,$user_id,$state);
            $self->_unit_regenerate_layouts($state);
        });
        1;
    };
    return $self->_unit_error_response($@) if !$ok;
    return $self->_unit_finish_request($c,$state);
}

sub _get_existing_germplasm {
    my ($self,$schema,$id,$name)=@_;
    my $resolved=eval {$self->_unit_resolve_germplasm($id,$name)};
    return $resolved if $resolved;
    return {error=>$self->_unit_error_response($@)};
}

sub observationunits_store {
    my ($self,$data,$c,$user_id)=@_;
    my $state={projects=>{},ids=>[],fullview=>1,changed=>1};
    $self->{_unit_writes} = 0;
    my $ok=eval {
        $self->bcs_schema->txn_do(sub {
            _unit_fail('The request must contain observation-unit objects.') if ref($data) ne 'ARRAY' || !@$data;
            my @study_ids;
            my @parents;
            my @copy;
            for my $p (@$data) {
                _unit_fail('Each observation unit must be an object.') if ref($p) ne 'HASH';
                my $unit=decode_json(encode_json($p));
                my $info=$unit->{additionalInfo} // {};
                my $pos=$unit->{observationUnitPosition} // {};
                _unit_fail('additionalInfo and observationUnitPosition must be objects.') if ref($info) ne 'HASH' || ref($pos) ne 'HASH';
                _unit_fail('observationLevel must be an object.') if ref($pos->{observationLevel}) ne 'HASH';
                my $level=$pos->{observationLevel}{levelName} // '';
                _unit_fail('Only plot, plant or tissue_sample units can be created.') if $level !~ /^(?:plot|plant|tissue_sample)$/;
                my $study=_unit_scalar($unit->{studyDbId},'studyDbId');push @study_ids,$study;
                $unit->{studyDbId}=$study;
                $unit->{additionalInfo}=$info;
                $unit->{observationUnitPosition}=$pos;
                $pos->{observationLevelRelationships} //= [];
                _unit_fail('observationLevelRelationships must be an array.') if ref($pos->{observationLevelRelationships}) ne 'ARRAY';
                my $design_group = _unit_design_group_request($pos, $info);
                _unit_fail('accessionOccurrence is assigned by the field layout; omit it when creating a unit.')
                    if exists($info->{accessionOccurrence}) && defined($info->{accessionOccurrence});
                $unit->{_creation_design_replicate} = $design_group->{value};
                delete $unit->{_creation_occurrence};
                delete $unit->{_creation_block};
                my $target=$self->_unit_resolve_germplasm($unit->{germplasmDbId},$unit->{germplasmName});
                $unit->{germplasmDbId}=''.$target->{id};$unit->{germplasmName}=$target->{name};
                _unit_fail('observationUnitName is required.') if !defined($unit->{observationUnitName}) || ref($unit->{observationUnitName}) || !length($unit->{observationUnitName});
                _unit_validate_references($unit->{externalReferences}) if exists($unit->{externalReferences});
                _unit_boolean($info->{control},'control') if exists($info->{control});
                if (defined($pos->{entryType}) && $pos->{entryType} !~ /^(?:CHECK|TEST)$/i) {_unit_fail('entryType must be CHECK or TEST.')}
                _unit_validate_additional_fields($info);
                if ($level ne 'plot') {
                    my $parent=_unit_scalar($info->{observationUnitParent},'observationUnitParent');
                    _unit_fail('A parent plot is required for a child unit.') if !defined($parent) || $parent !~ /^[1-9]\d*$/;
                    push @parents,$parent;
                    my $stock=$self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$parent});
                    _unit_fail('Parent plot does not exist.',404) if !$stock;
                    my $parent_type = $stock->type->name;
                    _unit_fail('This creation endpoint requires a plot parent, or a plant parent for a tissue sample.')
                        if $parent_type ne 'plot' && !($level eq 'tissue_sample' && $parent_type eq 'plant');
                    _unit_fail('The new child germplasm must match its parent plot.') if $target->{id} != $self->_unit_old_germplasm($parent);
                    my $parent_trial=CXGN::Trial::AccessionChange->field_trial_of_plot($self->bcs_schema,$parent);
                    _unit_fail('This child-creation endpoint requires its parent plot in the same field study.') if !$parent_trial || !defined($study) || $parent_trial ne $study;
                    my $parent_replication = CXGN::Trial::DesignReplication::read($self->bcs_schema, [$parent])->{$parent};
                    _unit_fail('The design group is inherited from the parent plot.')
                        if $design_group->{present} && !_unit_same_group($design_group->{value}, $parent_replication->{value});
                    $unit->{_creation_design_replicate} = $parent_replication->{value};
                    $unit->{_creation_occurrence} = $parent_replication->{occurrence};
                    $self->_unit_creation_block($unit,$parent);
                }
                push @copy,$unit;
            }
            my $auth=CXGN::BrAPI::DataAuthorization::projects_error($self->bcs_schema,$user_id,\@study_ids);die $auth if $auth;
            if(@parents){
                $auth=CXGN::BrAPI::DataAuthorization::observation_units_error($self->bcs_schema,$user_id,\@parents);die $auth if $auth;
            }
            my %locks=map {$_=>1} (@study_ids,@{$self->_unit_projects(\@parents)});
            $self->bcs_schema->storage->dbh->selectcol_arrayref('SELECT project_id FROM project WHERE project_id = ANY(?) ORDER BY project_id FOR UPDATE',undef,[keys %locks]);
            if(@parents){
                $self->bcs_schema->storage->dbh->selectcol_arrayref('SELECT stock_id FROM stock WHERE stock_id = ANY(?) ORDER BY stock_id FOR UPDATE',undef,\@parents);
                my $parent_replication = CXGN::Trial::DesignReplication::read($self->bcs_schema, \@parents);
                for my $unit (@copy) {
                    next if $unit->{observationUnitPosition}{observationLevel}{levelName} eq 'plot';
                    my $parent = $unit->{additionalInfo}{observationUnitParent};
                    _unit_fail('The parent plot germplasm changed while the request was checked; retry with its current germplasm.',409)
                        if $unit->{germplasmDbId} != $self->_unit_old_germplasm($parent);
                    my $declared = _unit_design_group_request($unit->{observationUnitPosition}, $unit->{additionalInfo});
                    _unit_fail('The design group is inherited from the parent plot; retry with its current group.',409)
                        if $declared->{present} && !_unit_same_group($declared->{value}, $parent_replication->{$parent}{value});
                    $unit->{_creation_design_replicate} = $parent_replication->{$parent}{value};
                    $unit->{_creation_occurrence} = $parent_replication->{$parent}{occurrence};
                    $self->_unit_creation_block($unit,$parent);
                }
            }
            $self->page(0);
            my $created=$self->_store_units_legacy(\@copy,$c,$user_id);
            if(!$created || !defined($created->{result})) {
                my @errors=grep {($_->{messageType}//'') eq 'ERROR'} @{$created->{status}||[]};
                _unit_fail(@errors ? $errors[-1]{message} : 'Could not create observation units.',$created->{http_code}||400);
            }
            for my $p (@copy) {
                my $type=SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,$p->{observationUnitPosition}{observationLevel}{levelName},'stock_type')->cvterm_id;
                my $rs=$self->bcs_schema->resultset('Stock::Stock')->search({uniquename=>$p->{observationUnitName},type_id=>$type});
                _unit_fail('Created unit identity could not be resolved uniquely.') if $rs->count != 1;
                $p->{observationUnitDbId}=''.$rs->first->stock_id;
                $self->_unit_set_created_child_block($rs->first->stock_id,$p)
                    if $p->{observationUnitPosition}{observationLevel}{levelName} ne 'plot';
            }
            $self->_unit_apply_updates(\@copy,$user_id,$state);
            $self->_unit_regenerate_layouts($state);
        });
        1;
    };
    return $self->_unit_error_response($@) if !$ok;
    return $self->_unit_finish_request($c,$state);
}

sub _store_units_legacy {
    my $self = shift;
    my $data = shift;
    my $c = shift;
    my $user_id = shift;

    my $schema = $self->bcs_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $user_name = $person->get_username;

    my %study_plots;
    my %seen_plot_numbers;
    foreach my $params (@{$data}) {
        my $study_id = $params->{studyDbId} || undef;
        my $plot_name = defined($params->{observationUnitName}) ? $params->{observationUnitName} : undef;
        my $plot_number = defined($params->{observationUnitPosition}->{observationLevel}->{levelCode}) ? $params->{observationUnitPosition}->{observationLevel}->{levelCode} : undef;
        my $plot_parent_id = defined($params->{additionalInfo}->{observationUnitParent}) ? $params->{additionalInfo}->{observationUnitParent} : undef;
        my $accession_id = defined($params->{germplasmDbId}) ? $params->{germplasmDbId} : undef;
        my $accession_name = defined($params->{germplasmName}) ? $params->{germplasmName} : undef;
        my $entry_type = defined($params->{observationUnitPosition}->{entryType}) ? $params->{observationUnitPosition}->{entryType} : undef;
        my $is_a_control = defined($params->{additionalInfo}->{control}) ? $params->{additionalInfo}->{control} : undef;

        # BrAPI entryType overrides additionalinfo.control
        if ($entry_type) {
            $is_a_control = uc($entry_type) eq 'CHECK' ? 1 : 0;
        }

        my $range_number = $params->{additionalInfo}->{range};
        my $row_number = defined($params->{observationUnitPosition}->{positionCoordinateY}) ? $params->{observationUnitPosition}->{positionCoordinateY} : undef;
        my $col_number = defined($params->{observationUnitPosition}->{positionCoordinateX}) ? $params->{observationUnitPosition}->{positionCoordinateX} : undef;
        my $seedlot_id = defined($params->{seedLotDbId}) ? $params->{seedLotDbId} : undef;
        my $plot_geo_json = $params->{observationUnitPosition}->{geoCoordinates} ? $params->{observationUnitPosition}->{geoCoordinates} : undef;
        my $levels = $params->{observationUnitPosition}->{observationLevelRelationships} ? $params->{observationUnitPosition}->{observationLevelRelationships} : undef;
        my $ou_level = $params->{observationUnitPosition}->{observationLevel}->{levelName} || undef;
        my $observationUnit_x_ref = $params->{externalReferences} ? $params->{externalReferences} : undef;
        my $raw_additional_info = $params->{additionalInfo} || undef;
        my %specific_keys = map { $_ => 1 } ("observationUnitParent","control","designReplicate","accessionOccurrence");
        my %additional_info;
        if (defined $raw_additional_info) {
            foreach my $key (keys %$raw_additional_info) {
                if (!exists($specific_keys{$key})) {
                    $additional_info{$key} = $raw_additional_info->{$key};
                }
            }
        }
        my $block_number;
        my $rep_number;
        my $design_rep_number = $params->{_creation_design_replicate};

        # Required fields check
        if (! defined $accession_id && ! defined $accession_name) {
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Either germplasmDbId or germplasmName is required.'), 400);
        }

        if ($ou_level ne 'plant' && $ou_level ne 'plot' && $ou_level ne 'tissue_sample') {
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Only "plot", "plant" or "tissue_sample" allowed for observation level.'), 400);
        }

        my $project = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $study_id });
        if (! defined $project) {
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf("A study with id $study_id does not exist"), 404);
        }

        # Get the germplasm name from germplasmDbId. Check if a germplasm name passed exists
        my $germplasm_search_result = $self->_get_existing_germplasm($schema, $accession_id, $accession_name);
        if ($germplasm_search_result->{error}) {
            return $germplasm_search_result->{error};
        } else {
            $accession_name = $germplasm_search_result->{name};
        }

        foreach (@$levels){
            if($_->{levelName} eq 'block'){
                $block_number = defined($_->{levelCode}) ? $_->{levelCode} : undef;
            }
        }
        $block_number=$params->{_creation_block} if exists($params->{_creation_block});
        # The public rep relationship is the declared design group. Counters
        # are assigned by native storage; a child starts from its parent's value.
        $rep_number = $params->{_creation_occurrence};

        # The trial designer expects a list of plant names, this object is a plant, so add to single item list
        my $plot_hash;
        if ($ou_level eq 'plant') {
            # Check that the parent already exists
            my $plot_parent_name;
            if ($plot_parent_id) {
                my $rs = $schema->resultset("Stock::Stock")->search({stock_id=>$plot_parent_id});
                if ($rs->count() eq 0){
                    return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Plot with id %s does not exist.', $plot_parent_id), 404);
                }
                $plot_parent_name = $rs->first()->uniquename();
            } else {
                return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('addtionalInfo.observationUnitParent for observation unit with level "plant" is required'), 404);
            }

            $plot_hash = {
                plot_name       => $plot_parent_name,
                _existing_parent_stock_id => $plot_parent_id,
                plant_names     => [ $plot_name ],
                # accession_name => $accession_name,
                stock_name      => $accession_name,
                plot_number     => $plot_number,
                block_number    => $block_number,
                is_a_control    => $is_a_control,
                rep_number      => $rep_number,
                design_rep_number => $design_rep_number,
                range_number    => $range_number,
                row_number      => $row_number,
                col_number      => $col_number,
                # plot_geo_json => $plot_geo_json,
                additional_info => \%additional_info,
                external_refs   => $observationUnit_x_ref
            };
        } elsif ($ou_level eq 'tissue_sample') {
            my $plot_parent_name;
            if ($plot_parent_id) {
                my $rs = $schema->resultset("Stock::Stock")->search({stock_id=>$plot_parent_id});
                if ($rs->count() eq 0){
                    return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Plot with id %s does not exist.', $plot_parent_id), 404);
                }
                $plot_parent_name = $rs->first()->uniquename();
            } else {
                return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('addtionalInfo.observationUnitParent for observation unit with level "tissue_sample" is required'), 404);
            }

            $plot_hash = {
                plot_name       =>  $plot_parent_name,
                _existing_parent_stock_id => $plot_parent_id,
                tissue_sample_names => [ $plot_name ],                
                stock_name => $accession_name,
                plot_number => $plot_number,
                block_number    => $block_number,
                is_a_control    => $is_a_control,
                rep_number      => $rep_number,
                design_rep_number => $design_rep_number,
                range_number    => $range_number,
                row_number      => $row_number,
                col_number      => $col_number,
                additional_info => \%additional_info,
                external_refs   => $observationUnit_x_ref
            }
        } else {
            $plot_hash = {
                plot_name => $plot_name,
                # accession_name => $accession_name,
                stock_name => $accession_name,
                plot_number => $plot_number,
                block_number => $block_number,
                is_a_control => $is_a_control,
                rep_number => $rep_number,
                design_rep_number => $design_rep_number,
                range_number => $range_number,
                row_number => $row_number,
                col_number => $col_number,
                # plot_geo_json => $plot_geo_json,
                additional_info => \%additional_info,
                external_refs   => $observationUnit_x_ref
            };
        }

        $study_plots{$study_id}{$plot_number} = $plot_hash;
        $seen_plot_numbers{$study_id}{$plot_number}++;
    }

    # Check that the plot numbers passed are unique per study
    foreach my $study_design (values %seen_plot_numbers) {
        foreach my $seen_plot_number (keys %{$study_design}) {
            if ($study_design->{$seen_plot_number} > 1) {
                return CXGN::BrAPI::JSONResponse->return_error($self->status, "Plot number '$seen_plot_number' is duplicated in the data sent. Plot Number must be unique", 422);
            }
        }
    }

    my $coderef = sub {
        foreach my $study_id (keys %study_plots) {

            # Get the study design type
            my $study = $study_plots{$study_id};
            my $project = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $study_id });
            my $design_prop = $project->projectprops->find({ 'type.name' => 'design' }, { join => 'type' }); #there should be only one design prop.
            if (!$design_prop) {
                die {error => 'Study does not have a study type.', errorCode => 500};
            }
            my $design_type = $design_prop->value;

            # Get the study location
            my $location_id;
            my $location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property');
            my $row = $self->bcs_schema()->resultset('Project::Projectprop')->find({
                project_id => $project->project_id(),
                type_id    => $location_type_id->cvterm_id(),
            });
            if ($row) {
                print('Row value: ' . $row->value());
                $location_id = $row->value();
            }
            else {
                die {error => sprintf('Error retrieving the location of the study'), errorCode => 500};
            }

            my $trial_design_store = CXGN::Trial::TrialDesignStore->new({
                bcs_schema                        => $schema,
                trial_id                          => $study_id,
                nd_geolocation_id                 => $location_id,
                # nd_experiment_id => $nd_experiment->nd_experiment_id(), #optional
                is_genotyping                     => 0,
                #new_treatment_has_plant_entries   => 0,
                #new_treatment_has_subplot_entries => 0,
                operator                          => $user_name,
                trial_stock_type                  => 'accessions',
                design_type                       => $design_type,
                design                            => $study,
                operator                          => $user_name
            });

            my $error;
            my $validate_design_error = $trial_design_store->validate_design();
            if ($validate_design_error) {
                die {error => sprintf('Error validating study design: ' . $validate_design_error), errorCode => 422};
            }
            else {
                $error = $trial_design_store->store();
                if ($error) {
                    die {error => sprintf('ERROR store: ' . $error), errorCode => 500};
                }
                # Exact requested IDs are resolved by the owning wrapper. It
                # applies external references and rebuilds the final layout
                # after all metadata writes; child indexes are not plot keys.
            }
        }
    };

    # The owning transaction formats native hash and string errors consistently.
    $schema->txn_do($coderef);

    # The transactional wrapper resolves the requested identities and performs
    # the final read after applying all metadata. An intermediate search would
    # add a duplicate response status before that authoritative read.
    $self->page_size(scalar @{$data});
    return {result => {}};
}

sub _order {
    my $value = shift;
    my %levels = (
        "rep"  => 0,
        "block"  => 1,
        "plot" => 2,
        "subplot"=> 3,
        "plant"=> 4,
        "tissue_sample"=> 5,

    );
    return $levels{$value} + 0;
}

1;

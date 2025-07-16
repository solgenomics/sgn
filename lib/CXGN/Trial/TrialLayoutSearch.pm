package CXGN::Trial::TrialLayoutSearch;

=head1 NAME

CXGN::Trial::TrialLayoutSearch - Module to get layout information about one or more trials

=head1 SYNOPSIS

    This object has been converted to a factory object that will produce different classes
    based on the experiment_type. The usage has been kept the same for backwards compatibility,
    but a cleaner factory object implementation should be adopted in the future.

    It works similar to Phenotypes search but it doesn't merge with phenotypes table. Phenotypes table
    will be joined only when IncludeObservations parameter is passed by as 1;

    my $trial_layout = CXGN::Trial::TrialLayout->new({
        schema => $schema,
        data_level=>$data_level->[0],
        trial_list=>$study_ids_arrayref,
        include_observations=>$include_observations,
        location_list=>$location_ids_arrayref,
        accession_list=>$accession_ids_arrayref,
        folder_list=>$folder_ids_arrayref,
        program_list=>$program_ids_arrayref,
        observation_unit_id_list=>$observation_unit_db_id,
        observation_unit_names_list=>$observation_unit_names_list,
        xref_id_list=>$reference_ids_arrayref,
        xref_source_list=>$reference_sources_arrayref,
    });

=head1 DESCRIPTION


=head1 AUTHORS

 Mirella Flores (mrf252@cornell.edu)

=cut

# use strict;
# use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Calendar;
use JSON;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#(plot, plant, or all)
has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'program_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'folder_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'observation_unit_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'observation_unit_names_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
    );

has 'experiment_type' => (
    isa => 'Str',
    is => 'rw',
    default => 'field_layout',
    );

has 'include_observations' => (
    isa => 'Int|Undef',
    is => 'rw',
    default => 0
);

has 'order_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    print STDERR "Search Start:".localtime."\n";
    my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $is_a_control_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is a control', 'stock_property')->cvterm_id();
    my $plant_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_index_number', 'stock_property')->cvterm_id();
    my $breeding_program_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $folder_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_folder', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_sample_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();

    my $treatment_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_treatment_relationship', 'project_relationship')->cvterm_id();
    my $treatment_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'treatment_experiment', 'experiment_type')->cvterm_id();
    my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $seedlot_transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seed transaction', 'stock_relationship')->cvterm_id();

    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';

    #For performance reasons the number of joins to stock can be reduced if a trial is given.

    my $from_clause = " FROM stock as observationunit
        JOIN stock_relationship ON (observationunit.stock_id=subject_id)
        JOIN cvterm as observationunit_type ON (observationunit_type.cvterm_id = observationunit.type_id)
        JOIN stock as germplasm ON (object_id=germplasm.stock_id) AND germplasm.type_id IN ($accession_type_id, $cross_type_id, $family_name_type_id)
        JOIN cvterm as germplasm_type ON (germplasm_type.cvterm_id = germplasm.type_id)
        JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=observationunit.stock_id)
        JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
        JOIN project USING(project_id)
        LEFT JOIN project_relationship ON (project.project_id=project_relationship.subject_project_id AND project_relationship.type_id = $breeding_program_rel_type_id)
        LEFT JOIN project as breeding_program ON (breeding_program.project_id=project_relationship.object_project_id)
        LEFT JOIN project_relationship folder_rel ON (project.project_id = folder_rel.subject_project_id AND folder_rel.type_id = $folder_rel_type_id)
        LEFT JOIN project folder ON (folder.project_id = folder_rel.object_project_id)
        LEFT JOIN projectprop as location ON (project.project_id=location.project_id AND location.type_id = $project_location_type_id)
        LEFT JOIN nd_experiment_stock treatment_nds ON (treatment_nds.type_id = $treatment_experiment_type_id AND treatment_nds.stock_id = observationunit.stock_id)
        LEFT JOIN nd_experiment_project treatment_ndp ON (treatment_ndp.nd_experiment_id = treatment_nds.nd_experiment_id)
        LEFT JOIN project_relationship treatment_rel ON (project.project_id = treatment_rel.object_project_id AND treatment_rel.type_id = $treatment_rel_type_id)
        LEFT JOIN project treatment ON (treatment.project_id = treatment_rel.subject_project_id AND treatment.project_id = treatment_ndp.project_id)
        LEFT JOIN stock_relationship AS seedplot_planted ON(seedplot_planted.subject_id = observationunit.stock_id AND seedplot_planted.type_id=$seedlot_transaction_type_id)
        LEFT JOIN stock AS seedlot ON(seedplot_planted.object_id = seedlot.stock_id AND seedlot.type_id=$seedlot_type_id)
        LEFT JOIN stockprop AS rep ON (observationunit.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
        LEFT JOIN stockprop AS block_number ON (observationunit.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
        LEFT JOIN stockprop AS plot_number ON (observationunit.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
        LEFT JOIN stockprop AS row_number ON (observationunit.stock_id=row_number.stock_id AND row_number.type_id = $row_number_type_id)
        LEFT JOIN stockprop AS col_number ON (observationunit.stock_id=col_number.stock_id AND col_number.type_id = $col_number_type_id)
        LEFT JOIN stockprop AS plant_number ON (observationunit.stock_id=plant_number.stock_id AND plant_number.type_id = $plant_number_type_id)
        LEFT JOIN stockprop AS is_a_control ON (observationunit.stock_id=is_a_control.stock_id AND is_a_control.type_id = $is_a_control_type_id) ";


    my $select_clause = "SELECT observationunit.stock_id, observationunit.uniquename, observationunit_type.name, germplasm.uniquename, germplasm.stock_id, germplasm_type.name, project.project_id, project.name, project.description, breeding_program.project_id, breeding_program.name, breeding_program.description, folder.project_id, folder.name, folder.description,rep.value, block_number.value, plot_number.value, is_a_control.value, row_number.value, col_number.value, plant_number.value, location.value, STRING_AGG(treatment.name, '|'), STRING_AGG(treatment.description, '|'), seedlot.stock_id, seedlot.uniquename, count(observationunit.stock_id) OVER() AS full_count ";

    my $order_clause = $self->order_by ? " ORDER BY ".$self->order_by : " ORDER BY project.name, observationunit.uniquename";

    my $group_by = " GROUP BY observationunit.stock_id, observationunit.uniquename, observationunit_type.name, germplasm.uniquename, germplasm.stock_id, germplasm_type.name, project.project_id, project.name, project.description, breeding_program.project_id, breeding_program.name, breeding_program.description, folder.project_id, folder.name, folder.description, rep.value, block_number.value, plot_number.value, is_a_control.value, row_number.value, col_number.value, plant_number.value, location.value, seedlot.stock_id, seedlot.uniquename ";

    # WHERE
    my @where_clause;

    if ($self->accession_list && scalar(@{$self->accession_list})>0) {
        my $accession_sql = _sql_from_arrayref($self->accession_list);
        push @where_clause, "germplasm.stock_id in ($accession_sql)";
    }

    if ($self->observation_unit_names_list && scalar(@{$self->observation_unit_names_list})>0) {
        my $arrayref = $self->observation_unit_names_list;
        my $sql = join ("','" , @$arrayref);
        my $observationunit_sql = "'" . $sql . "'";
        push @where_clause, "observationunit.uniquename in ($observationunit_sql)";
    }

    if ($self->observation_unit_id_list && scalar(@{$self->observation_unit_id_list})>0) {
        my $plot_sql = _sql_from_arrayref($self->observation_unit_id_list);
        push @where_clause, "observationunit.stock_id in ($plot_sql)";
    }

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, "project.project_id in ($trial_sql)";
    }
    if ($self->program_list && scalar(@{$self->program_list})>0) {
        my $program_sql = _sql_from_arrayref($self->program_list);
        push @where_clause, "breeding_program.project_id in ($program_sql)";
    }
    if ($self->folder_list && scalar(@{$self->folder_list})>0) {
        my $folder_sql = _sql_from_arrayref($self->folder_list);
        push @where_clause, "folder.project_id in ($folder_sql)";
    }

    if ($self->data_level ne 'all') {
        my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $self->data_level, 'stock_type')->cvterm_id();
        push @where_clause, "observationunit.type_id = $stock_type_id"; #ONLY plot or plant or subplot or tissue_sample
    } else {
        push @where_clause, "(observationunit.type_id = $plot_type_id OR observationunit.type_id = $plant_type_id OR observationunit.type_id = $subplot_type_id OR observationunit.type_id = $tissue_sample_type_id)"; #plots AND plants AND subplots AND tissue_samples
    }

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));

    # If limit
    my $offset_clause = '';
    my $limit_clause = '';
    if ($self->limit){
        $limit_clause = " LIMIT ".$self->limit;
    }
    if ($self->offset){
        $offset_clause = " OFFSET ".$self->offset;
    }

    my  $q = $select_clause . $from_clause . $where_clause . $group_by . $order_clause . $limit_clause . $offset_clause;

    print STDERR "QUERY: $q\n\n";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;


    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }

    my @observation_units;

    while (my ($observationunit_stock_id, $observationunit_uniquename, $observationunit_type_name, $germplasm_uniquename, $germplasm_stock_id, $germplasm_type_name, $project_project_id, $project_name, $project_description, $breeding_program_project_id, $breeding_program_name, $breeding_program_description,
    $folder_id, $folder_name, $folder_description, $rep, $block_number, $plot_number, $is_a_control, $row_number, $col_number, $plant_number, $location_id, $treatment_name, $treatment_description, $seedlot_id, $seedlot_name, $full_count) = $h->fetchrow_array()) {

        my $location_name = $location_id ? $location_id_lookup{$location_id} : undef;

        # Split treatment names and descriptions on | and parse into an array
        my @names = split(/\|/, $treatment_name);
        my @descriptions = split(/\|/, $treatment_description);
        my @treatments;
        for my $i (0 .. $#names) {
            my $n = $names[$i];
            my $d = $descriptions[$i];
            push @treatments, { $n => $d };
        }
        if ( scalar(@treatments) == 0 ) {
            push @treatments, { 'No ManagementFactor' => undef };
        }
        # my $treatments = $treatment_name ? { $treatment_name => $treatment_description } : { 'No ManagementFactor'=>undef };

        if ($project_description) { $project_description =~ s/\R//g; }
        if ($breeding_program_description) { $breeding_program_description =~ s/\R//g };
        if ($folder_description) { $folder_description =~ s/\R//g };

        push @observation_units, $observationunit_stock_id;

        my $accession_stock_id;
        my $accession_name;
        my $cross_stock_id;
        my $cross_name;
        my $family_stock_id;
        my $family_name;

        if ($germplasm_type_name eq 'cross') {
            $cross_stock_id = $germplasm_stock_id;
            $cross_name = $germplasm_uniquename;
        } elsif ($germplasm_type_name eq 'family_name') {
            $family_stock_id = $germplasm_stock_id;
            $family_name = $germplasm_uniquename;
        } else {
            $accession_stock_id = $germplasm_stock_id;
            $accession_name = $germplasm_uniquename;
        }

        push @result, {
            obsunit_stock_id => $observationunit_stock_id,
            obsunit_uniquename => $observationunit_uniquename,
            obsunit_type_name => $observationunit_type_name,
            germplasm_uniquename => $accession_name,
            germplasm_stock_id => $accession_stock_id,
            cross_uniquename => $cross_name,
            cross_stock_id => $cross_stock_id,
            family_uniquename => $family_name,
            family_stock_id => $family_stock_id,
            trial_id => $project_project_id,
            trial_name => $project_name,
            trial_description => $project_description,
            location_name => $location_name,
            location_id => $location_id,
            breeding_program_id => $breeding_program_project_id,
            breeding_program_name => $breeding_program_name,
            breeding_program_description => $breeding_program_description,
            folder_id => $folder_id,
            folder_name => $folder_name,
            folder_description => $folder_description,
            rep => $rep,
            block => $block_number,
            plot_number => $plot_number,
            is_a_control => $is_a_control,
            row_number => $row_number,
            col_number => $col_number,
            plant_number => $plant_number,
            treatments => \@treatments ,
            full_count => $full_count,
            seedlot_id => $seedlot_id,
            seedlot_name => $seedlot_name,
        };
    }

    ## Query observations if requested. No requested by default
    my $observations;
    if ($self->include_observations > 0){

        $observations = _include_observations($self,\@observation_units)

    }

    print STDERR "Search End:".localtime."\n";
    return (\@result,$observations);
}

sub _include_observations {
    my $self = shift;
    my $observation_units = shift;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'Native',
    {
        bcs_schema=>$self->bcs_schema,
        data_level=>$self->data_level,
        plot_list=>$observation_units,
        order_by=>"plot_number",
        include_timestamp=>1
    });
    my ($data, $unique_traits) = $phenotypes_search->search();

    my %data_window;

    foreach (@$data){

        if ( ($_->{phenotype_value} && $_->{phenotype_value} ne "") || $_->{phenotype_value} eq '0' ) {
            my $observation_id = "$_->{phenotype_id}";
            my $observation_unit_id = "$_->{obsunit_stock_id}";
            my $additional_info;
            my $external_references;

            my %season = (
                year => $_->{year},
                season => undef,
                seasonDbId => undef
            );

            my $obs_timestamp = $_->{collect_date} ? $_->{collect_date} : $_->{timestamp};

            push @{$data_window{$observation_unit_id}}, {
                additionalInfo => $_->{phenotype_additional_info} ? decode_json($_->{phenotype_additional_info}) : undef,
                externalReferences => $_->{phenotype_external_references} ? decode_json($_->{phenotype_external_references}) : undef,
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
                uploadedBy=> $_->{operator},
                value => qq|$_->{phenotype_value}|,
                # geoCoordinates => undef #needs to be implemented for v2.1
            };
        }
    }
    return \%data_window;
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}

1;

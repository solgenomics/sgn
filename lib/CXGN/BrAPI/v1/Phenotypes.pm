package CXGN::BrAPI::v1::Phenotypes;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use Try::Tiny;

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


sub search {
    my $self = shift;
    my $inputs = shift;
    my $data_level = $inputs->{data_level} || 'all';
    my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
    my $phenotype_min_value = $inputs->{phenotype_min_value};
    my $phenotype_max_value = $inputs->{phenotype_max_value};
    my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
    my @accession_ids_array = $inputs->{accession_ids} ? @{$inputs->{accession_ids}} : ();
    my @study_ids_array = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @location_ids_array = $inputs->{location_ids} ? @{$inputs->{location_ids}} : ();
    my @years_array = $inputs->{years} ? @{$inputs->{years}} : ();
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level,
            trial_list=>\@study_ids_array,
            trait_list=>\@trait_ids_array,
            include_timestamp=>1,
            year_list=>\@years_array,
            location_list=>\@location_ids_array,
            accession_list=>\@accession_ids_array,
            exclude_phenotype_outlier=>$exclude_phenotype_outlier,
            limit=>$limit,
            offset=>$offset,
            phenotype_min_value=>$phenotype_min_value,
            phenotype_max_value=>$phenotype_max_value
        }
    );
    my $data = $phenotypes_search->search();
    #print STDERR Dumper $data;

    my @data_window;
    my $total_count = 0;
    foreach my $obs_unit (@$data){
        my @brapi_observations;
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            push @brapi_observations, {
                observationDbId => $_->{phenotype_id},
                observationVariableDbId => $_->{trait_id},
                observationVariableName => $_->{trait_name},
                observationTimestamp => $_->{timestamp},
                season => $obs_unit->{year},
                collector => $_->{operator},
                value => $_->{value},
            };
        }
        my @brapi_treatments;
        my $treatments = $obs_unit->{treatments};
        while (my ($factor, $modality) = each %$treatments){
            push @brapi_treatments, {
                factor => $factor,
                modality => $modality,
            };
        }
        my $entry_type = $obs_unit->{is_a_control} ? 'check' : 'test';
        push @data_window, {
            observationUnitDbId => qq|$obs_unit->{observationunit_stock_id}|,
            observationLevel => $_->{observationunit_type_name},
            observationLevels => $obs_unit->{observationunit_type_name},
            plotNumber => $obs_unit->{obsunit_plot_number},
            plantNumber => $obs_unit->{obsunit_plant_number},
            blockNumber => $obs_unit->{obsunit_block_number},
            replicate => $obs_unit->{obsunit_rep_number},
            observationUnitName => $obs_unit->{observationunit_uniquename},
            germplasmDbId => qq|$obs_unit->{germplasm_stock_id}|,
            germplasmName => $obs_unit->{germplasm_uniquename},
            studyDbId => qq|$obs_unit->{trial_id}|,
            studyName => $obs_unit->{trial_name},
            studyLocationDbId => $obs_unit->{trial_location_id},
            studyLocation => $obs_unit->{trial_location_name},
            programName => $obs_unit->{breeding_program_name},
            X => $obs_unit->{obsunit_col_number},
            Y => $obs_unit->{obsunit_row_number},
            entryType => $entry_type,
            entryNumber => '',
            treatments => \@brapi_treatments,
            observations => \@brapi_observations
        };
        $total_count = $obs_unit->{full_count};
    }
    my %result = (data=>\@data_window);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype search result constructed');
}

sub search_table {
    my $self = shift;
    my $inputs = shift;
    my $data_level = $inputs->{data_level} || 'plot';
    my $search_type = $inputs->{search_type} || 'fast';
    my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
    my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
    my @accession_ids_array = $inputs->{accession_ids} ? @{$inputs->{accession_ids}} : ();
    my @study_ids_array = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @location_ids_array = $inputs->{location_ids} ? @{$inputs->{location_ids}} : ();
    my @years_array = $inputs->{years} ? @{$inputs->{years}} : ();
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $factory_type;
    if ($search_type eq 'complete'){
        $factory_type = 'Native';
    }
    if ($search_type eq 'fast'){
        $factory_type = 'MaterializedView';
    }
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$self->bcs_schema,
        data_level=>$data_level,
        search_type=>$factory_type,
        trial_list=>\@study_ids_array,
        trait_list=>\@trait_ids_array,
        include_timestamp=>1,
        year_list=>\@years_array,
        location_list=>\@location_ids_array,
        accession_list=>\@accession_ids_array,
        exclude_phenotype_outlier=>$exclude_phenotype_outlier
    );
    my @data;
    try {
        @data = $phenotypes_search->get_phenotype_matrix();
    }
    catch {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'An Error Occured During Phenotype Search Table');
    }

    my @data_files;
    my $total_count = scalar(@data)-1;
    my @header_names = @{$data[0]};
    my @trait_names = @header_names[30 .. $#header_names];
    my @header_ids;
    foreach my $t (@trait_names) {
        push @header_ids, SGN::Model::Cvterm->get_cvterm_row_from_trait_name($self->bcs_schema, $t)->cvterm_id();
    }

    my $start = $page_size*$page;
    my $end = $page_size*($page+1)-1;
    my @data_window;
    for (my $line = $start; $line < $end; $line++) {
        if ($data[$line]) {
            my $columns = $data[$line];
            push @data_window, $columns;
        }
    }

    #print STDERR Dumper \@data_window;

    my %result = (
        headerRow => ['studyYear', 'programDbId', 'programName', 'programDescription', 'studyDbId', 'studyName', 'studyDescription', 'studyDesign', 'plotWidth', 'plotLength', 'fieldSize', 'fieldTrialIsPlannedToBeGenotyped', 'fieldTrialIsPlannedToCross', 'plantingDate', 'harvestDate', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber', 'rowNumber', 'colNumber', 'entryType', 'plantNumber'],
        observationVariableDbIds => \@header_ids,
        observationVariableNames => \@trait_names,
        data=>\@data_window
    );

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype-search table result constructed');
}

sub search_table_csv_or_tsv {
    my $self = shift;
    my $inputs = shift;
    my $format = $inputs->{format} || 'json';
       my $file_path = $inputs->{file_path};
       my $file_uri = $inputs->{file_uri};
    my $data_level = $inputs->{data_level} || 'plot';
    my $search_type = $inputs->{search_type} || 'fast';
    my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
    my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
    my @accession_ids_array = $inputs->{accession_ids} ? @{$inputs->{accession_ids}} : ();
    my @study_ids_array = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @location_ids_array = $inputs->{location_ids} ? @{$inputs->{location_ids}} : ();
    my @years_array = $inputs->{years} ? @{$inputs->{years}} : ();
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $factory_type;
    if ($search_type eq 'complete'){
        $factory_type = 'Native';
    }
    if ($search_type eq 'fast'){
        $factory_type = 'MaterializedView';
    }
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$self->bcs_schema,
        data_level=>$data_level,
        search_type=>$factory_type,
        trial_list=>\@study_ids_array,
        trait_list=>\@trait_ids_array,
        include_timestamp=>1,
        year_list=>\@years_array,
        location_list=>\@location_ids_array,
        accession_list=>\@accession_ids_array,
        exclude_phenotype_outlier=>$exclude_phenotype_outlier
    );
    my @data;
    try {
        @data = $phenotypes_search->get_phenotype_matrix();
    }
    catch {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'An Error Occured During Phenotype Search CSV');
    }

    my %result;
    my $total_count = 0;

    my $file_response = CXGN::BrAPI::FileResponse->new({
        absolute_file_path => $file_path,
        absolute_file_uri => $inputs->{main_production_site_url}.$file_uri,
        format => $format,
        data => \@data
    });
    my @data_files = $file_response->get_datafiles();
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype-search csv result constructed');
}

1;

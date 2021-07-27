package CXGN::BrAPI::v1::ObservationTables;

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
    my $trait_list_arrayref = $params->{observationVariableDbId} || ($params->{observationVariableDbIds} || ());
    my $program_ids_arrayref = $params->{programDbId} || ($params->{programDbIds} || ());
    my $folder_ids_arrayref = $params->{trialDbId} || ($params->{trialDbIds} || ());
    my $start_time = $params->{observationTimeStampRangeStart}->[0] || undef;
    my $end_time = $params->{observationTimeStampRangeEnd}->[0] || undef;

    # not part of brapi standard yet
    # my $phenotype_min_value = $params->{phenotype_min_value};
    # my $phenotype_max_value = $params->{phenotype_max_value};
    # my $exclude_phenotype_outlier = $params->{exclude_phenotype_outlier} || 0;
    # my $search_type = $params->{search_type}->[0] || 'MaterializedViewTable';

    my $lt = CXGN::List::Transform->new();
    my $trait_ids_arrayref = $lt->transform($self->bcs_schema, "traits_2_trait_ids", $trait_list_arrayref)->{transform};

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$self->bcs_schema,
        data_level=>$data_level,
        search_type=>'MaterializedViewTable',
        trial_list=>$study_ids_arrayref,
        trait_list=>$trait_ids_arrayref,
        include_timestamp=>1,
        year_list=>$years_arrayref,
        location_list=>$location_ids_arrayref,
        accession_list=>$accession_ids_arrayref,
        folder_list=>$folder_ids_arrayref,
        program_list=>$program_ids_arrayref,
        # phenotype_min_value=>$phenotype_min_value,
        # phenotype_max_value=>$phenotype_max_value,
        # exclude_phenotype_outlier=>$exclude_phenotype_outlier
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
    my @trait_names = @header_names[39 .. $#header_names];
    my @header_ids;
    foreach my $t (@trait_names) {
        if ($t eq 'notes') { next; }
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
        headerRow => ['studyYear', 'programDbId', 'programName', 'programDescription', 'studyDbId', 'studyName', 'studyDescription', 'studyDesign', 'plotWidth', 'plotLength', 'fieldSize', 'fieldTrialIsPlannedToBeGenotyped', 'fieldTrialIsPlannedToCross', 'plantingDate', 'harvestDate', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber', 'rowNumber', 'colNumber', 'entryType', 'plantNumber', 'plantedSeedlotStockDbId', 'plantedSeedlotStockUniquename', 'plantedSeedlotCurrentCount', 'plantedSeedlotCurrentWeightGram', 'plantedSeedlotBoxName', 'plantedSeedlotTransactionCount', 'plantedSeedlotTransactionWeight', 'plantedSeedlotTransactionDescription', 'availableGermplasmSeedlotUniquenames'],
        observationVariableDbIds => \@header_ids,
        observationVariableNames => \@trait_names,
        data=>\@data_window
    );

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype-search table result constructed');
}

1;

package CXGN::BrAPI::v1::ObservationUnits;

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
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data_files;

    my $data_level = $params->{observationLevel}->[0] || 'all';
    my @years_array = $params->{seasonDbId} || $params->{seasonDbIds};
    my @location_ids_array = $params->{locationDbId} || $params->{locationDbIds};
    my @study_ids_array = $params->{studyDbId} || $params->{studyDbIds};
    my @accession_ids_array = $params->{germplasmDbId}|| $params->{germplasmDbIds};
    my @trait_ids_array = $params->{observationVariableDbId} || $params->{observationVariableDbIds};
    my @program_ids_array = $params->{programDbId} || $params->{programDbIds};
    my @folder_ids_array = $params->{trialDbId} || $params->{trialDbIds};
    my $start_time = $params->{observationTimeStampRangeStart} || undef;
    my $end_time = $params->{observationTimeStampRangeEnd} || undef;

    # not part of brapi standard yet
    # my $phenotype_min_value = $params->{phenotype_min_value};
    # my $phenotype_max_value = $params->{phenotype_max_value};
    # my $exclude_phenotype_outlier = $params->{exclude_phenotype_outlier} || 0;
    # my $search_type = $params->{search_type}->[0] || 'MaterializedViewTable';

    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level,
            trial_list=>\@study_ids_array,
            program_list=>\@program_ids_array,
            folder_list=>\@folder_ids_array,
            trait_list=>\@trait_ids_array,
            include_timestamp=>1,
            year_list=>\@years_array,
            location_list=>\@location_ids_array,
            accession_list=>\@accession_ids_array,
            limit=>$limit,
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
        my $entry_type = $obs_unit->{obsunit_is_a_control} ? 'check' : 'test';
        push @data_window, {
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
            observations => \@brapi_observations
        };
        $total_count = $obs_unit->{full_count};
    }

    my %result = (data=>\@data_window);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype search result constructed');
}

1;

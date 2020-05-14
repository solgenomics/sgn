package CXGN::BrAPI::v2::Samples;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::TissueSample;
use CXGN::Stock::TissueSample::Search;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub detail {
    my $self = shift;
    my $sample_id = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data;

    my $s = CXGN::Stock::TissueSample->new(schema=>$self->bcs_schema, tissue_sample_id=>$sample_id);
    my $accession_id = $s->get_accession ? $s->get_accession->[0] : "";
    my $accession_name = $s->get_accession ? $s->get_accession->[1] : "";
    my $source_plot_id = $s->get_source_plot ? $s->get_source_plot->[0] : "";
    my $source_plot_name = $s->get_source_plot ? $s->get_source_plot->[1] : "";
    my $source_plant_id = $s->get_source_plant ? $s->get_source_plant->[0] : "";
    my $source_plant_name = $s->get_source_plant ? $s->get_source_plant->[1] : "";
    my $source_sample_id = $s->get_source_tissue_sample ? $s->get_source_tissue_sample->[0] : "";
    my $source_sample_name = $s->get_source_tissue_sample ? $s->get_source_tissue_sample->[1] : "";
    my $source_obs_id = $s->source_observation_unit ? $s->source_observation_unit->[0] : "";
    my $source_obs_name = $s->source_observation_unit ? $s->source_observation_unit->[1] : "";
    my $plate_id = $s->get_plate ? $s->get_plate->[0] : "";
    my $plate_name = $s->get_plate ? $s->get_plate->[1] : "";
    my $trial_id = $s->get_trial ? $s->get_trial->[0] : "";
    my $trial_name = $s->get_trial ? $s->get_trial->[1] : "";
    my $sample_db_id = $s->stock_id;
    my %result = (
        sampleDbId => qq|$sample_db_id|,
        sampleName => $s->uniquename,
        observationUnitDbId => qq|$source_obs_id|,
        observationUnitName => $source_obs_name,
        germplasmDbId => qq|$accession_id|,
        germplasmName => $accession_name,
        studyDbId => qq|$trial_id|,
        studyName => $trial_name,
        # plotDbId => qq|$source_plot_id|,
        plotName => $source_plot_name,
        # plantDbId => qq|$source_plant_id|,
        plantName => $source_plant_name,
        sourceSampleDbId => qq|$source_sample_id|,
        sourceSampleName => $source_sample_name,
        plateDbId => qq|$plate_id|,
        plateName => $plate_name,
        # plateIndex => 0,
        takenBy => $s->dna_person,
        sampleTimestamp => $s->acquisition_date,
        sampleType => $s->get_plate_sample_type,
        tissueType => $s->tissue_type,
        # notes => $s->notes,
        #
        sampleGroupDbId => undef,
        trialDbId => qq|$trial_id|,
        sampleBarcode => undef, 
        samplePUI  => undef, 
        row  => undef,
        column => undef, 
        sampleDescription  => undef,
        well  => undef,
        additionalInfo => $s->notes,
        externalReferences => undef, 
        programDbId => undef
    );
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Sample get result constructed');
}


sub search {
    my $self = shift;
    my $search_params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data;
    
    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my @tissue_ids = $search_params->{sampleDbId} || ($search_params->{sampleDbIds} || ());
    my @study_names = $search_params->{studyName} || ($search_params->{studyNames} || ());
    my @study_ids = $search_params->{studyDbId} || ($search_params->{studyDbIds} || ());
    my @plate_ids = $search_params->{plateDbId} || ($search_params->{plateDbIds} || ());
    my @accession_ids = $search_params->{germplasmDbId} || ($search_params->{germplasmDbIds} || ());
    my @accession_names = $search_params->{germplasmName} || ($search_params->{germplasmNames} || ());
    my @obs_ids = $search_params->{observationUnitDbId} || ($search_params->{observationUnitDbIds} || ());
    my @externalreference_ids = $search_params->{externalReferenceID} || ($search_params->{externalReferenceIDs} || ());
    my @externalreference_sources = $search_params->{externalReferenceSource} || ($search_params->{externalReferenceSources} || ());

    if (scalar(@externalreference_sources)>0 || scalar(@externalreference_ids)>0){
        push @$status, { 'error' => 'The following search parameters are not implemented: externalReferenceID, externalReferenceSource' };
    }

    my @geno_trial_ids = [];
    if (@study_ids || @plate_ids){
        @geno_trial_ids = (@study_ids, @plate_ids); 
    }

    my $sample_search = CXGN::Stock::TissueSample::Search->new({
        bcs_schema=>$self->bcs_schema,
        tissue_sample_db_id_list => \@tissue_ids,
        # tissue_sample_name_list => \@tissue_names,
        plate_db_id_list => @geno_trial_ids,
        plate_name_list => \@study_names,
        germplasm_db_id_list => \@accession_ids,
        germplasm_name_list => \@accession_names,
        observation_unit_db_id_list => \@obs_ids,
        # observation_unit_name_list => \@obs_names,
        limit => $limit,
        offset => $offset
    });
    my ($search_res, $total_count) = $sample_search->search();
    foreach (@$search_res){
        push @data, {
            sampleDbId => qq|$_->{sampleDbId}|,
            sampleName => $_->{sampleName},
            observationUnitDbId => qq|$_->{observationUnitDbId}|,
            observationUnitName => $_->{observationUnitName},
            observationUnitType => $_->{observationUnitType},
            germplasmDbId => qq|$_->{germplasmDbId}|,
            germplasmName => $_->{germplasmName},
            studyDbId => qq|$_->{studyDbId}|,
            studyName => $_->{studyName},
            # plotDbId => qq|$_->{plotDbId}|,
            plotName => $_->{plotName},
            # plantDbId => qq|$_->{plantDbId}|,
            plantName => $_->{plantName},
            sourceSampleDbId => qq|$_->{sourceSampleDbId}|,
            sourceSampleName => $_->{sourceSampleName},
            plateDbId => qq|$_->{plateDbId}|,
            plateName => $_->{plateName},
            # plateIndex => 0,
            takenBy => $_->{dna_person},
            sampleTimestamp => $_->{acquisition_date},
            sampleType => $_->{tissue_type},
            tissueType => $_->{tissue_type},
            extraction => $_->{extraction},
            # notes => $_->{notes},
            well => $_->{well},
            concentration => $_->{concentration},
            volume => $_->{volume},
            is_blank => $_->{is_blank},
            #
            sampleGroupDbId => undef,
            trialDbId => qq|$_->{studyDbId}|,
            sampleBarcode => undef, 
            samplePUI  => undef, 
            row  => undef,
            column => undef, 
            sampleDescription  => undef,
            additionalInfo => $_->{notes},
            externalReferences => undef, 
            programDbId => undef
        };
    }
    my %result = (data => \@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Sample search result constructed');
}

1;

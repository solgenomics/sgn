package CXGN::BrAPI::v1::Samples;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::TissueSample;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::JSONResponse;

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

sub detail {
    my $self = shift;
    my $sample_id = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data;

    my $s = CXGN::Stock::TissueSample->new(schema=>$self->bcs_schema, tissue_sample_id=>$sample_id);
    my $accession_id = $s->get_accession ? $s->get_accession->[0] : undef;
    my $accession_name = $s->get_accession ? $s->get_accession->[1] : undef;
    my $source_plot_id = $s->get_source_plot ? $s->get_source_plot->[0] : undef;
    my $source_plot_name = $s->get_source_plot ? $s->get_source_plot->[1] : undef;
    my $source_plant_id = $s->get_source_plant ? $s->get_source_plant->[0] : undef;
    my $source_plant_name = $s->get_source_plant ? $s->get_source_plant->[1] : undef;
    my $source_sample_id = $s->get_source_tissue_sample ? $s->get_source_tissue_sample->[0] : undef;
    my $source_sample_name = $s->get_source_tissue_sample ? $s->get_source_tissue_sample->[1] : undef;
    my $source_obs_id = $s->source_observation_unit ? $s->source_observation_unit->[0] : undef;
    my $source_obs_name = $s->source_observation_unit ? $s->source_observation_unit->[1] : undef;
    my $plate_id = $s->get_plate ? $s->get_plate->[0] : undef;
    my $plate_name = $s->get_plate ? $s->get_plate->[1] : undef;
    my $trial_id = $s->get_trial ? $s->get_trial->[0] : undef;
    my $trial_name = $s->get_trial ? $s->get_trial->[1] : undef;
    my %result = (
        sampleDbId => $s->stock_id,
        sampleName => $s->uniquename,
        observationUnitDbId => $source_obs_id,
        observationUnitName => $source_obs_name,
        germplasmDbId => $accession_id,
        germplasmName => $accession_name,
        studyDbId => $trial_id,
        studyName => $trial_name,
        plotDbId => $source_plot_id,
        plotName => $source_plot_name,
        plantDbId => $source_plant_id,
        plantName => $source_plant_name,
        sourceSampleDbId => $source_sample_id,
        sourceSampleName => $source_sample_name,
        plateDbId => $plate_id,
        plateName => $plate_name,
        plateIndex => 0,
        takenBy => $s->dna_person,
        sampleTimestamp => $s->acquisition_date,
        sampleType => $s->get_plate_sample_type,
        tissueType => $s->tissue_type,
        notes => $s->notes
    );
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Sample get result constructed');
}

1;

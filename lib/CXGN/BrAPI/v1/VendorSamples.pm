package CXGN::BrAPI::v1::VendorSamples;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Stock::TissueSample;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v1::Common';

sub detail {
    my $self = shift;
    my $trial_id = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data;

    my $trial = CXGN::Trial->new({bcs_schema=>$self->schema, trial_id=>$trial_id});
    my $tl = CXGN::Trial::TrialLayout->new({ schema => $self->bcs_schema, trial_id => $trial_id, experiment_type=>'genotyping_layout' });
	my $design = $tl->get_design();
    my @samples;
    foreach (sort keys %$design){
        push @samples, {
            sampleDbId => $design->{$_}->{'plot_name'},
            well => $design->{$_}->{'plot_number'},
            row => $design->{$_}->{'row_number'},
            column => $design->{$_}->{'col_number'},
            concentration => $design->{$_}->{'concentration'},
            volume => $design->{$_}->{'volume'},
            tissueType => $design->{$_}->{'tissue_type'},
            taxonId => {}
        };
    }
    my $plate_info = {
        vendorProjectDbId =>,
        clientPlateDbId => $trial_id,
        plateFormat => $trial->get_genotyping_plate_format,
        sampleType => $trial->get_genotyping_plate_sample_type,
        samples => \@samples
    };

    my %result = ( plates => [$plate_info] );
	my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Plate get result constructed');
}

1;

package CXGN::BrAPI::v1::Markers;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Marker::SearchBrAPI;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use JSON;

use CXGN::DB::Connection;

extends 'CXGN::BrAPI::v1::Common';

sub search {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @marker_ids = $inputs->{markerDbIds} ? @{$inputs->{markerDbIds}} : ();
    my @marker_names = $inputs->{markerNames} ? @{$inputs->{markerNames}} : ();
    my @types = $inputs->{types} ? @{$inputs->{types}} : ();
    my $method = $inputs->{method};
    my $schema = $self->bcs_schema;
    my @data_out;

    my $marker_search = CXGN::Marker::SearchBrAPI->new({
        bcs_schema=>$schema,
        marker_ids=>\@marker_ids
        # markerNames=>\@marker_names,
        # matchMethod=>[$method],
        # types=>\@types,
        # offset=>$page_size*$page,
        # limit=>$page_size
    });
    my ($data, $total_count) = $marker_search->search();

    foreach (@$data){
        # my %additional_info = (
        #     design => $_->{design},
        #     description => $_->{description},
        # );
        my %data_obj = (
            markerDbId => qq|$_->{marker_id}|,
            markerName => $_->{location_id} 
        );
        push @data_out, \%data_obj;
    }

    my %result = (data=>\@data_out);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Marker-search result constructed');

}

1;

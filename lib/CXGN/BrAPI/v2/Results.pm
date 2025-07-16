package CXGN::BrAPI::v2::Results;

=head1 NAME

CXGN::BrAPI::Results - an object to handle saving and retrieving BrAPI search results in tempfiles brapi_searches dir

=head1 SYNOPSIS

This module is used to save and retrieve the results of complex BrAPI search requests

=head1 AUTHORS

=cut

use Moose;
use Data::Dumper;
use JSON;
use File::Slurp;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub save_results {
    my $self = shift;
    my $tempfile = shift;
    my $search_result =shift;
    my $search_type = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data_files;

    open my $fh, ">", $tempfile;
    my $json_result = encode_json($search_result);
    print $fh $json_result;
    close $fh;

    my $search_id = substr($tempfile, -16);
    my %result = ( searchResultsDbId => $search_id );
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, "search $search_type result constructed");

}

sub retrieve_results {
    my $self = shift;
    my $tempfiles_subdir = shift;
    my $search_id = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $search_json;
    my @data_files;
    my $filename = $tempfiles_subdir . "/" . $search_id;

    # check if file exists, if it does retrive and return contents
    if (-e $filename) {
        $search_json = read_file($filename) ;
    }

    #read data 
    my $decoded_json = decode_json($search_json);
    my @data = \@{ $decoded_json->{result}->{data} } ;

    my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(@data,$page_size,$page);
    my %result = ( data => $data_window );
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, "search result constructed");
}

1;

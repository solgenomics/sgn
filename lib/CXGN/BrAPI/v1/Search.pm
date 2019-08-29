package CXGN::BrAPI::v1::Search;

=head1 NAME

CXGN::BrAPI::Search - an object to handle saving and retrieving BrAPI search parameters in tempfiles brapi_searches dir

=head1 SYNOPSIS

This module is used to save and retrieve parameters for complex BrAPI search requests

=head1 AUTHORS

=cut

use Moose;
use Data::Dumper;
use JSON;
use File::Slurp;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

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

sub save_search {
    my $self = shift;
    my $tempfiles_subdir = shift;
    my $search_id = shift;
    my $search_result =shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $filename = $tempfiles_subdir . "/" . $search_id;
    my @data_files;

    #write to tmp file with id as name
    if (!-e $filename) {
        open my $fh, ">", $tempfiles_subdir . "/" . $search_id;
        my $search_retrieve = encode_json($search_result);
        print $fh $search_retrieve;
        close $fh;
    }

    my %result = ( searchResultsDbId => $search_id );
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'search/germplasm result constructed');

}

sub retrieve_search {
    my $self = shift;
    my $tempfiles_subdir = shift;
    my $search_id = shift;
    my $search_json;
    my $filename = $tempfiles_subdir . "/" . $search_id;

    # check if file exists, if it does retrive and return contents
    if (-e $filename) {
        $search_json = read_file($filename) ;
    }
    my $search_params = decode_json($search_json);
    return $search_params;
}

1;

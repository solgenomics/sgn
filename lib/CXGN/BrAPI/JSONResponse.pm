package CXGN::BrAPI::JSONResponse;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;

sub return_error {
    my $self = shift;
    my $status = shift;
    my $message = shift;
    my $http_code = shift;
    push @$status, { 'ERROR' => $message };
    my $formatted_status = _convert_status_obj($status);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,1,0);
    my $response = {
        'status' => $formatted_status,
        'pagination' => $pagination,
        'result' => undef,
        'datafiles' => [],
        'http_code' => $http_code
    };
    return $response;
}

sub return_success {
    my $self = shift;
    my $result = shift;
    my $pagination = shift;
    my $data_files = shift;
    my $status = shift;
    my $message = shift;
    push @$status, { 'INFO' => $message };
    my $formatted_status = _convert_status_obj($status);
    my $response = { 
        'status' => $formatted_status,
        'pagination' => $pagination,
        'result' => $result,
        'datafiles' => $data_files
    };
    return $response;
}

sub _convert_status_obj {
    my $status = shift;
    my @formatted_status;
    foreach (@$status){
        while (my ($code, $message) = each %$_){
            push @formatted_status, {
                messageType => $code,
                message => $message
            };
        }
    }
    return \@formatted_status;
}

1;

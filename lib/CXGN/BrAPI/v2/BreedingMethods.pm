package CXGN::BrAPI::v2::BreedingMethods;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
	my $c = shift;
    my $status = $self->status;



    my @data;

    foreach (@$search_res){
        push @data, {
            abbreviation=>$_->{'abbreviation'},
            breedingMethodDbId=>$_->{'breeding method db id'},
            breedingMethodName=>$_->{'breeding method name'},
            description=>$_->{'breeding method description'} || 0,
        };
    }

    my %result = (data => \@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Sample search result constructed');
}

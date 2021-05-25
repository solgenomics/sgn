package CXGN::BrAPI::v2::BreedingMethods;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
	my $c = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
    my $status = $self->status;

	my @crosstypes;
	my @data;
	my @data_files;
	my $total_count = 1;

	my $cross_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'cross_type', 'nd_experiment_property')->cvterm_id();

	my $q = "SELECT distinct(value) FROM nd_experimentprop where type_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($cross_type_cvterm_id);

	while (my ($cross_type) = $h->fetchrow_array()) {
		push @crosstypes, $cross_type;
	}

    foreach (@crosstypes){
    	my $id = $_;
    	$id =~ s/ /_/g;

        push @data, {
            abbreviation=>$_,
            breedingMethodDbId=>$id,
            breedingMethodName=>$_,
            description=>$_,
        };
    }

    my %result = (data => \@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
#    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Breeding methods result constructed');
}

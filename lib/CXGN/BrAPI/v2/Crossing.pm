package CXGN::BrAPI::v2::Crossing;

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

    my $crossing_ids = $params->{crossingProjectDbId} || undef;
    my $reference_ids_arrayref = $params->{externalReferenceID} || ();
    my $reference_sources_arrayref = $params->{externalReferenceSources} || ();

    if (($reference_ids_arrayref && scalar(@$reference_ids_arrayref)>0) || ($reference_sources_arrayref && scalar(@$reference_sources_arrayref)>0) ){
        push @$status, { 'error' => 'The following search parameters are not implemented: externalReferenceID, externalReferenceSources' };
    }
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
	my $counter = 0;
	my @data;

	if (! $crossing_ids){
	    my $crossingtrial = CXGN::BreedersToolbox::Projects->new( { schema=>$self->bcs_schema });
	    my $crossing_trials = $crossingtrial->get_crossing_trials();
	    foreach (@$crossing_trials){
	    	push(@$crossing_ids, $_->[0]);
	    }
	}

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$self->bcs_schema ,
        trial_id_list=>$crossing_ids,
        limit => $page_size,
        offset => $page_size*$page,
        # field_trials_only => 1
    });
    my ($data, $total_count) = $trial_search->search();

    foreach my $experiment (@$data){
    	push @data, {
                additionalInfo=>{},
                commonCropName=>undef,
                crossingProjectDbId=>qq|$experiment->{trial_id}|,
                crossingProjectDescription=>$experiment->{trial_name},
                crossingProjectName=>$experiment->{trial_name},
                externalReferences=>[],
                programDbId=>qq|$experiment->{breeding_program_id}|,
                programName=>$experiment->{breeding_program_name},
            };
    }

	my %result = (data=>\@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Crossing projects result constructed');
}

sub detail {
	my $self = shift;
	my $crossing_id = shift;
    my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $counter = 0;
	my %result;

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$self->bcs_schema ,
        trial_id_list=>[$crossing_id],
        limit => $page_size,
        offset => $page_size*$page,
    });
    my ($data, $total_count) = $trial_search->search();

    foreach my $experiment (@$data){
    	%result = (
                additionalInfo=>{},
                commonCropName=>undef,
                crossingProjectDbId=>qq|$experiment->{trial_id}|,
                crossingProjectDescription=>$experiment->{trial_name},
                crossingProjectName=>$experiment->{trial_name},
                externalReferences=>[],
                programDbId=>qq|$experiment->{breeding_program_id}|,
                programName=>$experiment->{breeding_program_name},
            );
    	$counter++;
    }

	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Crossing projects result constructed');
}

1;

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
	my $crossingproj_id = shift;
    my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $counter = 0;
	my %result;

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$self->bcs_schema ,
        trial_id_list=>[$crossingproj_id],
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

sub crosses {
    my $self = shift;
    my $params = shift;
    my $c = shift;
    my $status = $self->status;

    my $crossingproj_id = $params->{crossingProjectDbId} || undef;
    my $crossing_id = $params->{crossDbId} || undef;
    my $reference_ids_arrayref = $params->{externalReferenceID} || ();
    my $reference_sources_arrayref = $params->{externalReferenceSources} || ();

    if (($reference_ids_arrayref && scalar(@$reference_ids_arrayref)>0) || ($reference_sources_arrayref && scalar(@$reference_sources_arrayref)>0) ){
        push @$status, { 'error' => 'The following search parameters are not implemented: externalReferenceID, externalReferenceSources' };
    }
    my $page_size = $self->page_size;
    my $page = $self->page;
    my @data;
    my %crossing_proj;
    my $counter=0;

    if (!$crossingproj_id){
        my $crossingtrial = CXGN::BreedersToolbox::Projects->new( { schema=>$self->bcs_schema });
        my $crossing_trials = $crossingtrial->get_crossing_trials();
        foreach (@$crossing_trials){
            $crossing_proj{$_->[0]} = $_->[1];
        }
    } else{
        $crossing_proj{$crossingproj_id->[0]} = $crossingproj_id;
    }

    foreach my $trial_id (keys %crossing_proj){
        # my $trial = CXGN::Cross->new({ schema => $self->bcs_schema, trial_id => $trial_id , cross_stock_id => '42817'});print Dumper  $trial->get_cross_info();
        my $trial = CXGN::Cross->new({ schema => $self->bcs_schema, trial_id => $trial_id});
        my $result = $trial->get_crosses_and_details_in_crossingtrial();
        my @crosses;
        foreach my $r (@$result){

            my ($cross_id, $cross_name, $cross_combination, $cross_type, $female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name, $female_plant_id, $female_plant_name, $male_plant_id, $male_plant_name) =@$r;
           
            push @data, {
                additionalInfo=>{},
                crossAttributes=>[
                  {
                    crossAttributeName=>undef,
                    crossAttributeValue=>undef,
                  }
                ],
                crossDbId=>qq|$cross_id|,
                crossName=>$cross_name,
                crossType=>$cross_type,
                crossingProjectDbId=>qq|$trial_id|,
                crossingProjectName=>$crossing_proj{$trial_id},
                externalReferences=> [],
                parent1=> {
                  germplasmDbId=>qq|$female_parent_id|,
                  germplasmName=>$female_parent_name,
                  observationUnitDbId=>$female_plot_id,
                  observationUnitName=>$female_plot_name,
                  parentType=>"FEMALE",
                },      
                parent2=>{
                  germplasmDbId=>qq|$male_parent_id|,
                  germplasmName=>$male_parent_name,
                  observationUnitDbId=>$male_plot_id,
                  observationUnitName=>$male_plot_name,
                  parentType=>"MALE",
                },
                pollinationTimeStamp=>undef,
            };
            $counter++;
        }

    }

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Crossing projects result constructed');
}

1;

package CXGN::BrAPI::v2::Crossing;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use CXGN::Location::LocationLookup;

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

    my %result = _get_detail($self,$crossingproj_id);
    $counter = 1 if (%result);

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Crossing projects result constructed');
}

sub _get_detail {
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
    return %result;
}

sub store_crossingproject {
    my $self = shift;
    my $data = shift;
    my $c = shift;
    my $user_id = shift;

    my $schema = $self->bcs_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;

    my @list;
    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, 'You need to be logged in to add a crossingtrial.');
    }

    foreach my $params (@$data){
        my $crossingtrial_name = $params->{crossingProjectName} ? $params->{crossingProjectName} : undef;
        my $breeding_program_id = $params->{programDbId} ? $params->{programDbId} : undef;
        my $breeding_program_name = $params->{programName} ? $params->{programName} : undef;
        my $location = $params->{additionalInfo}->{locationName} ? $params->{additionalInfo}->{locationName} : undef;
        my $year = $params->{additionalInfo}->{year} ? $params->{additionalInfo}->{year} : undef;
        my $project_description = $params->{crossingProjectDescription} ? $params->{crossingProjectDescription} : undef;
        my $additional_info = $params->{additionalInfo} ? $params->{additionalInfo} : undef; #not implemented
        my $crop_name = $params->{commonCropName} ? $params->{commonCropName} : undef; #not implemented
        my $external_references = $params->{externalReferences} ? $params->{externalReferences} : undef; #not implemented

        my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
        $geolocation_lookup->set_location_name($location);

        if(!$geolocation_lookup->get_geolocation()){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, "Location not found");
        }

        my $error;
        my $crossingproj_id;
        eval{
            my $add_crossingtrial = CXGN::Pedigree::AddCrossingtrial->new({
                chado_schema => $schema,
                dbh => $dbh,
                breeding_program_id => $breeding_program_id,
                year => $year,
                project_description => $project_description,
                crossingtrial_name => $crossingtrial_name,
                nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id(),
                owner_id => $user_id
            });
            my $store_return = $add_crossingtrial->save_crossingtrial();
            if ($store_return->{error}){
                $error = $store_return->{error};
            }
            $crossingproj_id = $store_return->{trial_id};
        };

        if ($@) {
            return CXGN::BrAPI::JSONResponse->return_error($self->status, $@);
        };

        if ($error){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, $error);
        }
        push @list, $crossingproj_id;
    }

    my $counter = scalar @list;
    my %result;

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, $counter . ' Crossing projects stored');

}

sub update_crossingproject {
    my $self = shift;
    my $crossingproj_id = shift;
    my $params = shift;
    my $c = shift;
    my $user_id = shift;
    my $user_type = shift;

    my $schema = $self->bcs_schema;
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $user_id);
    my $phenome_schema = $self->phenome_schema();
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;

    my $crossingtrial_name = $params->{crossingProjectName} ? $params->{crossingProjectName} : undef;
    my $breeding_program_id = $params->{programDbId} ? $params->{programDbId} : undef;
    my $breeding_p_name = $params->{programName} ? $params->{programName} : undef;
    my $location = $params->{additionalInfo}->{locationName} ? $params->{additionalInfo}->{locationName} : undef;
    my $year = $params->{year} ? $params->{year} : undef;
    my $project_description = $params->{crossingProjectDescription} ? $params->{crossingProjectDescription} : undef;
    my $additional_info = $params->{additionalInfo} ? $params->{additionalInfo} : undef; #not implemented
    my $crop_name = $params->{commonCropName} ? $params->{commonCropName} : undef; #not implemented
    my $external_references = $params->{externalReferences} ? $params->{externalReferences} : undef; #not implemented

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, 'You need to be logged in to add a crossingtrial.');
    }
    my $id = $schema->resultset('Project::Project')->find({name => $breeding_p_name})->project_id();
    if($id ne $breeding_program_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, 'You should provide a valid programDbId and programName.');
    }

    my $trial = CXGN::Trial->new({
        bcs_schema => $schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        trial_id => $crossingproj_id
    });

    my $location_id;
    if ($location) {
        my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $schema);
    	$geolocation_lookup->set_location_name($location);
    	$location_id = $geolocation_lookup->get_geolocation()->nd_geolocation_id;
    }

    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
    my $program_ref = $program_object->get_breeding_programs_by_trial($crossingproj_id);

    my $program_array = @$program_ref[0];
    my $breeding_program_name = @$program_array[1];
    my @user_roles = $user_type;
    my %has_roles = ();
    map { $has_roles{$breeding_program_name} = 1; } @user_roles;

    if (!exists($has_roles{$breeding_program_name})) {
      return CXGN::BrAPI::JSONResponse->return_error($self->status, "You need to be associated with breeding program $breeding_program_name to change the details of this trial.");
    }

    # set each new detail that is defined
    eval {
      if ($crossingtrial_name) { $trial->set_name($crossingtrial_name); }
      if ($breeding_program_id) { $trial->set_breeding_program($breeding_program_id); }
      if ($location_id) { $trial->set_location($location_id); }
      if ($year) { $trial->set_year($year); }
      if ($project_description) { $trial->set_description($project_description); }
    };

    if ($@) {
        return CXGN::BrAPI::JSONResponse->return_error($self->status, $@);
    };

    my $counter = 0;
    my %result = _get_detail($self,$crossingproj_id);
    $counter = 1 if (%result);

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Crossing project updated');

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
        my $trial = CXGN::Cross->new({ schema => $self->bcs_schema, trial_id => $trial_id});
        my $result = $trial->get_crosses_and_details_in_crossingtrial();
        my @crosses;
        foreach my $r (@$result){

            my ($cross_id, $cross_name, $cross_combination, $cross_type, $female_parent_id, $female_parent_name, $female_ploidy, $male_parent_id, $male_parent_name, $male_ploidy, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name, $female_plant_id, $female_plant_name, $male_plant_id, $male_plant_name) =@$r;

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

sub store_crosses { #crosses must belong to same experiment
    my $self = shift;
    my $data = shift;
    my $c = shift;
    my $user_id = shift;

    my $chado_schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, 'You need to be logged in to add a crossingtrial.');
    }
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $user_name = $person->get_username;
    my $crossing_trial_id;
    my $crossing_trial_name;
    my @array_of_pedigree_objects;

    foreach my $params (@$data){
        my $cross_name = $params->{crossName} ? $params->{crossName}  : undef;
        my $cross_type = $params->{crossType} ? $params->{crossType}  : undef;
        $crossing_trial_id = $params->{crossingProjectDbId} ? $params->{crossingProjectDbId}  : undef;
        my $parent =  $params->{parent1}->{parentType}; #First female is maternal name, second parent is paternal_name
        my $maternal_name;
        my $paternal_name;
        my $female_plot_id;
        my $male_plot_id;
        if($parent eq 'FEMALE'){
            $maternal_name = $params->{parent1}->{germplasmName} ? $params->{parent1}->{germplasmName}  : undef;
            $paternal_name = $params->{parent2}->{germplasmName} ? $params->{parent2}->{germplasmName}  : undef;
            $female_plot_id = $params->{parent1}->{observationUnitDbId} ? $params->{parent1}->{observationUnitDbId}  : undef;
            $male_plot_id = $params->{parent2}->{observationUnitDbId} ? $params->{parent2}->{observationUnitDbId}  : undef;
        } else {
            $maternal_name = $params->{parent2}->{germplasmName} ? $params->{parent2}->{germplasmName}  : undef;
            $paternal_name = $params->{parent1}->{germplasmName} ? $params->{parent1}->{germplasmName}  : undef;
            $female_plot_id = $params->{parent2}->{observationUnitDbId} ? $params->{parent2}->{observationUnitDbId}  : undef;
            $male_plot_id = $params->{parent1}->{observationUnitDbId} ? $params->{parent1}->{observationUnitDbId}  : undef;
        }
        my $cross_combination = $params->{crossName} ? $params->{crossName}  : undef;
        $crossing_trial_name = $params->{crossingProjectName} ? $params->{crossingProjectName}  : undef;
        my $crossing_attributes = $params->{crossAttributes} ? $params->{crossAttributes}  : undef; #not supported
        my $crossing_timeStamp = $params->{pollinationTimeStamp} ? $params->{pollinationTimeStamp}  : undef; #not supported
        $cross_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end.

        my $cross = $self->_format_cross($c, $chado_schema, $cross_name, $cross_type, $crossing_trial_id, $female_plot_id, $male_plot_id, $maternal_name, $paternal_name, $user_name, $cross_combination);

        push(@array_of_pedigree_objects, $cross);
    }

    eval {
        #create array of pedigree objects to add, in this case just one pedigree
        my $cross_add = CXGN::Pedigree::AddCrosses->new({
            chado_schema => $chado_schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
            crossing_trial_id => $crossing_trial_id,
            crosses =>  \@array_of_pedigree_objects,
            user_id => $user_id,
        });

        #add the crosses
        $cross_add->add_crosses();
    };

    if ($@) {
        return CXGN::BrAPI::JSONResponse->return_error($self->status, "Error!");
    }

    my $trial = CXGN::Cross->new({ schema => $self->bcs_schema, trial_id => $crossing_trial_id});
    my $result = $trial->get_crosses_and_details_in_crossingtrial();
    my $counter=0;
    my @data;
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
            crossingProjectDbId=>qq|$crossing_trial_id|,
            crossingProjectName=>$crossing_trial_name,
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


    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Crosses result constructed');
}

sub update_crosses {
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

    #will be implemented in the future when cross properties from conf file are stadarized
}

sub _format_cross {
    my $self = shift;
    my $c = shift;
    my $chado_schema = shift;
    my $cross_name = shift;
    my $cross_type = shift;
    my $crossing_trial_id = shift;
    my $female_plot_id = shift;
    my $female_plot;
    my $male_plot_id = shift;
    my $male_plot;
    my $maternal = shift;
    my $paternal = shift;
    my $owner_name = shift;
    my $cross_combination = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $dbh = $c->dbc->dbh;

    if ($female_plot_id){
        my $female_plot_rs = $chado_schema->resultset("Stock::Stock")->find({stock_id => $female_plot_id});
        $female_plot = $female_plot_rs->name();
    }

    if ($male_plot_id){
        my $male_plot_rs = $chado_schema->resultset("Stock::Stock")->find({stock_id => $male_plot_id});
        $male_plot = $male_plot_rs->name();
    }

    #check that maternal name is not blank
    if ($maternal eq "") {
        $c->stash->{rest} = {error =>  "Female parent name cannot be blank." };
        return 0;
    }

    #if required, check that paternal parent name is not blank;
    if ($paternal eq "" && ($cross_type ne "open") && ($cross_type ne "bulk_open")) {
        $c->stash->{rest} = {error =>  "Male parent name cannot be blank." };
        return 0;
    }

    #check that parents exist in the database
    if (! $chado_schema->resultset("Stock::Stock")->find({uniquename=>$maternal,})){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, "Female parent does not exist");
    }

    if ($paternal) {
        if (! $chado_schema->resultset("Stock::Stock")->find({uniquename=>$paternal,})){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, "Male parent does not exist.");
        }
    }

    #check that cross name does not already exist
    if ($chado_schema->resultset("Stock::Stock")->find({uniquename=>$cross_name})){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, "Cross Unique ID already exists");
    }

    #objects to store cross information
    my $cross_to_add = Bio::GeneticRelationships::Pedigree->new(name => $cross_name, cross_type => $cross_type, cross_combination => $cross_combination,);
    my $female_individual = Bio::GeneticRelationships::Individual->new(name => $maternal);
    $cross_to_add->set_female_parent($female_individual);

    if ($paternal) {
        my $male_individual = Bio::GeneticRelationships::Individual->new(name => $paternal);
        $cross_to_add->set_male_parent($male_individual);
    }

    if ($female_plot) {
        my $female_plot_individual = Bio::GeneticRelationships::Individual->new(name => $female_plot);
        $cross_to_add->set_female_plot($female_plot_individual);
    }

    if ($male_plot) {
        my $male_plot_individual = Bio::GeneticRelationships::Individual->new(name => $male_plot);
        $cross_to_add->set_male_plot($male_plot_individual);
    }

    $cross_to_add->set_cross_type($cross_type);
    $cross_to_add->set_name($cross_name);
    $cross_to_add->set_cross_combination($cross_combination);

    return $cross_to_add;
}

1;

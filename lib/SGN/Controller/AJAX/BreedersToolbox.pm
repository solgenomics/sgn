
package SGN::Controller::AJAX::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';
use Data::Dumper;

use CXGN::List;
use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Delete;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub insert_new_project : Path("/ajax/breeders/project/insert") Args(0) { 
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to add projects." } ;
	return;
    }

    my $params = $c->req->parameters();

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    my $exists = $schema->resultset('Project::Project')->search(
	{ name => $params->{project_name} } 
	);
    
    if ($exists > 0) { 
	$c->stash->{rest} = { error => "This trial name is already used." };
	return; 
    }


    my $project = $schema->resultset('Project::Project')->find_or_create(
	{
	    name => $params->{project_name},
	    description => $params->{project_description},
	}
	);
    
    my $projectprop_year = $project->create_projectprops( { 'project year' => $params->{year},}, {autocreate=>1}); #cv_name => 'project_property' } );

    

    $c->stash->{rest} = { error => '' };
}


sub get_all_locations :Path("/ajax/breeders/location/all") Args(0) { 
    my $self = shift;
    my $c = shift;

    my $bp = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $all_locations = $bp->get_all_locations();

    $c->stash->{rest} = { locations => $all_locations };

}

sub insert_new_location :Path("/ajax/breeders/location/insert") Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $params = $c->request->parameters();

    my $description = $params->{description};
    my $longitude   = $params->{longitude};
    my $latitude    = $params->{latitude};
    my $altitude    = $params->{altitude};

    if (! $c->user()) { # redirect
	$c->stash->{rest} = { error => 'You must be logged in to add a location.' };
	return;
    }

    if (! $c->user->check_roles("submitter") && !$c->user->check_roles("curator")) { 
	$c->stash->{rest} = { error => 'You do not have the necessary privileges to add locations.' };
	return;
    }
    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $exists = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $description } )->count();

    if ($exists > 0) { 
	$c->stash->{rest} = { error => "The location - $description - already exists. Please choose another name." };
	return;
    }

    if ( ($longitude && $longitude !~ /^[0-9.]+$/) || ($latitude && $latitude !~ /^[0-9.]+$/) || ($altitude && $altitude !~ /^[0-9.]+$/) ) { 
	$c->stash->{rest} = { error => "Longitude, latitude and altitude must be numbers." };
	return;
    }

    my $new_row;
    $new_row = $schema->resultset('NaturalDiversity::NdGeolocation')
      ->new({
	     description => $description,
	    });
    if ($longitude) {
      $new_row->longitude($longitude);
    }
    if ($latitude) {
      $new_row->latitude($latitude);
    }
    if ($altitude) {
      $new_row->altitude($altitude);
    }
    $new_row->insert();
    $c->stash->{rest} = { success => 1, error => '' };
}

sub delete_location :Path('/ajax/breeders/location/delete') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $location_id = shift;

    if (!$c->user) {  # require login
	$c->stash->{rest} = { error => "You need to be logged in to delete a location." };
	return;
    }
    # require curator or submitter roles
    if (! ($c->user->check_roles('curator') || $c->user->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => "You don't have the privileges to delete a location." };
	return;
    }
    my $del = CXGN::BreedersToolbox::Delete->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema") } );
    if ($del->can_delete_location($location_id)) { 
	my $success = $del->delete_location($location_id);
	
	if ($success) { 
	    $c->stash->{rest} = { success => 1 };
	}
	else { 
	    $c->stash->{rest} = { error => "Could not delete location $location_id" };
	}
    }
    else { 
	$c->stash->{rest} = { error => "This location cannot be deleted because it has associated data." }
    }
    
}
	

sub get_breeding_programs : Path('/ajax/breeders/all_programs') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $po = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $breeding_programs = $po->get_breeding_programs();
    
    $c->stash->{rest} = $breeding_programs;
}


sub associate_breeding_program_with_trial : Path('/breeders/program/associate') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $breeding_program_id = shift;
    my $trial_id = shift;

    my $message = "";

    if ($c->user() && ( $c->user()->check_roles('submitter')  || $c->user()->check_roles('curator'))) { 
	my $program = CXGN::BreedersToolbox::Projects->new( { schema=> $c->dbic_schema("Bio::Chado::Schema") } );
	
	$message = $program->associate_breeding_program_with_trial($breeding_program_id, $trial_id);
	
	#print STDERR "MESSAGE: $xmessage->{error}\n";
    }
    else { 
	$message = { error => "You need to be logged in and have sufficient privileges to associate trials to programs." };
    }
    $c->stash->{rest} = $message;
    
}


sub remove_breeding_program_from_trial : Path('/breeders/program/remove') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $breeding_program_id = shift;
    my $trial_id = shift;

    my $message = "";


    if ($c->user() && ( $c->user()->check_roles('submitter')  || $c->user()->check_roles('curator'))) { 
	my $program = CXGN::BreedersToolbox::Projects->new( { schema=> $c->dbic_schema("Bio::Chado::Schema") } );
	
	$message = $program->remove_breeding_program_from_trial($breeding_program_id, $trial_id);
	
	#print STDERR "MESSAGE: $xmessage->{error}\n";
    }
    else { 
	$message = { error => "You need to be logged in and have sufficient privileges to associate trials to programs." };
    }
    $c->stash->{rest} = $message;
    

}

sub new_breeding_program :Path('/breeders/program/new') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $name = $c->req->param("name");
    my $desc = $c->req->param("desc");

    if (!($c->user() || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You need to be logged in and have sufficient privileges to add a breeding program.' };
    }
	    
       
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $error = $p->new_breeding_program($name, $desc);

    if ($error) { 
	$c->stash->{rest} = { error => $error };
    }
    else { 
	$c->stash->{rest} =  {};
    }

}

sub delete_breeding_program :Path('/breeders/program/delete') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $program_id = shift;

    if ($c->user && ($c->user->check_roles("curator"))) { 
	my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });
	$p->delete_breeding_program($program_id); 
	$c->stash->{rest} = [ 1 ];
    }
    else { 
	$c->stash->{rest} = { error => "You don't have sufficient privileges to delete breeding programs." };
    }
}


sub get_breeding_programs_by_trial :Path('/breeders/programs_by_trial/') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );

    my $projects = $p->get_breeding_programs_by_trial($trial_id);

    $c->stash->{rest} =   { projects => $projects };
    
}
	    
sub add_data_agreement :Path('/breeders/trial/add/data_agreement') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $project_id = $c->req->param('project_id');
    my $data_agreement = $c->req->param('text');

    if (!$c->user()) { 
	$c->stash->{rest} = { error => 'You need to be logged in to add a data agreement' };
	return;
    }

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have the required privileges to add a data agreement to this trial.' };
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $data_agreement_cvterm_id_rs = $schema->resultset('Cv::Cvterm')->search( { name => 'data_agreement' });

    my $type_id;
    if ($data_agreement_cvterm_id_rs->count>0) { 
	$type_id = $data_agreement_cvterm_id_rs->first()->cvterm_id();
    }

    eval { 
	my $project_rs = $schema->resultset('Project::Project')->search(
	    { project_id => $project_id } 
	    );
	
	if ($project_rs->count() == 0) { 
	    $c->stash->{rest} = { error => "No such project $project_id", };
	    return; 
	}
	
	my $project = $project_rs->first();

	my $projectprop_rs = $schema->resultset("Project::Projectprop")->search( { 'project_id' => $project_id, 'type_id'=>$type_id });

	my $projectprop;
	if ($projectprop_rs->count() > 0) { 
	    $projectprop = $projectprop_rs->first();
	    $projectprop->value($data_agreement);
	    $projectprop->update();
	    $c->stash->{rest} = { message => 'Updated data agreement.' };
	}
	else { 
	    $projectprop = $project->create_projectprops( { 'data_agreement' => $data_agreement,}, {autocreate=>1}); 
	    $c->stash->{rest} = { message => 'Inserted new data agreement.'};
	}
    };
    if ($@) { 
	$c->stash->{rest} = { error => $@ };
	return;
    }
}

sub get_data_agreement :Path('/breeders/trial/data_agreement/get') :Args(0) { 
    my $self = shift;
    my $c = shift;

    my $project_id = $c->req->param('project_id');

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    my $data_agreement_cvterm_id_rs = $schema->resultset('Cv::Cvterm')->search( { name => 'data_agreement' });
    
    if ($data_agreement_cvterm_id_rs->count() == 0) { 
	$c->stash->{rest} = { error => "No data agreements have been added yet." };
	return;
    }

    my $type_id = $data_agreement_cvterm_id_rs->first()->cvterm_id();

    print STDERR "PROJECTID: $project_id TYPE_ID: $type_id\n";

    my $projectprop_rs = $schema->resultset('Project::Projectprop')->search(
	{ project_id => $project_id, type_id=>$type_id } 
	);
    
    if ($projectprop_rs->count() == 0) { 
	$c->stash->{rest} = { error => "No such project $project_id", };
	return; 
    }
    my $projectprop = $projectprop_rs->first();
    $c->stash->{rest} = { prop_id => $projectprop->projectprop_id(), text => $projectprop->value() };

}

sub get_all_years : Path('/ajax/breeders/trial/all_years' ) Args(0) { 
    my $self = shift;
    my $c = shift;

    my $bp = CXGN::BreedersToolbox::Projects->new({ schema => $c->dbic_schema("Bio::Chado::Schema") });
    my @years = $bp->get_all_years();

    $c->stash->{rest} = { years => \@years };
}

sub get_trial_location : Path('/ajax/breeders/trial/location') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    
    my $t = CXGN::Trial->new(
	{ 
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    trial_id => $trial_id 
	});
    
    if ($t) { 
	$c->stash->{rest} = { location => $t->get_location() };
    }
    else { 
	$c->stash->{rest} = { error => "The trial with id $trial_id does not exist" };
	
    }
}

sub get_trial_type : Path('/ajax/breeders/trial/type') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $t = CXGN::Trial->new(
	{ 
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    trial_id => $trial_id 
	});
    
    my $type = $t->get_project_type();
    $c->stash->{rest} = { type => $type };
}

sub set_trial_type : Path('/ajax/breeders/trial/settype') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $type = $c->req->param("type");

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }

    my $t = CXGN::Trial->new( 
	{ 
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    trial_id => $trial_id 
	});

    if (!$t) { 
	$c->stash->{rest} = { error => "The specified trial with id $trial_id does not exist" };
	return;
    }
    # remove previous associations
    #
    $t->dissociate_project_type();
    
    # set the new trial type
    #
    $t->associate_project_type($type);
    
    $c->stash->{rest} = { success => 1 };
}

sub get_all_trial_types : Path('/ajax/breeders/trial/alltypes') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my @types = CXGN::Trial::get_all_project_types($c->dbic_schema("Bio::Chado::Schema"));
    
    $c->stash->{rest} = { types => \@types };
}

sub genotype_trial : Path('/ajax/breeders/genotypetrial') Args(0) { 
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) { 
	$c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
	return;
    }

    my $list_id = $c->req->param("list_id");
    my $name = $c->req->param("name");
    my $breeding_program_id = $c->req->param("breeding_program");
    my $description = $c->req->param("description");
    my $location_id = $c->req->param("location");
    my $year = $c->req->param("year");

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh(), list_id => $list_id });
    my $elements = $list->elements();

    if (!$name || !$list_id || !$breeding_program_id || !$location_id || !$year) { 
	$c->stash->{rest} = { error => "Please provide all parameters." };
	return;
    }

    my $td = CXGN::Trial::TrialDesign->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    $td->set_stock_list($elements);

    $td->set_block_size(96);

    $td->set_design_type("genotyping_plate");
    $td->set_trial_name($name);
    my $design;

    if (!$td->calculate_design()) { 
	$c->stash->{rest} = { error => "Design failed. Sorry." };
	return;
    }
    $design = $td->get_design();

    print STDERR Dumper($design);
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $location_id } );
    if (!$location) { 
	$c->stash->{rest} = { error => "Unknown location" };
	return;
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $breeding_program_id });
    if (!$breeding_program) {
	$c->stash->{rest} = { error => "Unknown breeding program" };
	return;
    }
    
    
    my $ct = CXGN::Trial::TrialCreate->new( { 
     	chado_schema => $c->dbic_schema("Bio::Chado::Schema"),
     	phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema"),
     	metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
     	dbh => $c->dbc->dbh(),
     	user_name => $c->user()->get_object()->get_username(),
     	trial_year => $year,
	trial_location => $location->description(),
	program => $breeding_program->name(), 
	trial_description => $description,
	design_type => 'genotyping_plate',
	design => $design,
	trial_name => $name,
	is_genotyping => 1,
    });
    
    my %message;
    eval { 
	%message = $ct->save_trial();
	if ($message{error}) { 
	    $c->stash->{rest} = $message{error};
	}
    };
    if ($@) { 
	$c->stash->{rest} = { error => "Error saving the trial. $@" };
    }
    $c->stash->{rest} = { 
	message => "Successfully stored the trial.",
	trial_id => $message{trial_id},
    };
}

1;

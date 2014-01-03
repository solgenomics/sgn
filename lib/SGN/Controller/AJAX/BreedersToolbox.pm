
package SGN::Controller::AJAX::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';

use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Delete;

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
	

sub get_breeding_programs : Path('/breeders/programs') Args(0) { 
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

    if ($c->user() && $c->user()->check_roles('submitter')) { 
	my $program = CXGN::BreedersToolbox::Projects->new( { schema=> $c->dbic_schema("Bio::Chado::Schema") } );
	
	$message = $program->associate_breeding_program_with_trial($breeding_program_id, $trial_id);
	
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
	
	    

1;

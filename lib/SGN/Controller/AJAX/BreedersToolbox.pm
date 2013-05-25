
package SGN::Controller::AJAX::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';

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
    my $longitude =   $params->{longitude};
    my $latitude  =   $params->{latitude};

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

    my $new_row = $schema->resultset('NaturalDiversity::NdGeolocation')->new( 
	{ 
	    description => $description,
	    longitude   => $longitude,
	    latitude    => $latitude,
	});

    $new_row->insert();

    $c->stash->{rest} = { error => '' };
    
}


1;

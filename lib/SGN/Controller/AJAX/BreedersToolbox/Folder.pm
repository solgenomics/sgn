
package SGN::Controller::AJAX::BreedersToolbox::Folder;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub get_folder : Chained('/') PathPart('ajax/folder') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    
    my $folder_id = shift;
    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{folder_id} = $folder_id;

}

sub create_folder :Path('/ajax/folder/new') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $parent_folder_id = $c->req->param("parent_folder_id");
    my $folder_name = $c->req->param("folder_name");
    my $breeding_program_id = $c->req->param("breeding_program_id");

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $existing = $schema->resultset("Project::Project")->find( { name => $folder_name });

    if ($existing) { 
	$c->stash->{rest} = { error => "An folder or trial with that name already exists in the database. Please select another name." };
	return;
    }
    my $folder = CXGN::Trial::Folder->create(
	{
	    bcs_schema => $schema,
	    parent_folder_id => $parent_folder_id,
	    name => $folder_name,
	    breeding_program_id => $breeding_program_id,
	});

    $c->stash->{rest} = { success => 1 };
}

sub associate_child_folder :Chained('get_folder') PathPart('associate/child') Args(1) { 
    my $self = shift;
    my $c = shift;
    
    my $child_id = shift;
    
    my $folder = CXGN::Trial::Folder->new( 
	{ 
	    bcs_schema => $c->stash->{schema}, 
	    folder_id => $c->stash->{folder_id} 
	});

    $folder->associate_child($child_id);
    
    $c->stash->{rest} = { success => 1 };
}

sub associate_parent_folder : Chained('get_folder') 
    PathPart('associate/parent') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $parent_id = shift;

    my $folder = CXGN::Trial::Folder->new( 
	{ 
	    bcs_schema => $c->stash->{schema}, 
	    folder_id => $c->stash->{folder_id} 
	});

    $folder->associate_parent($parent_id);
    
    $c->stash->{rest} = { success => 1 };

}





1;

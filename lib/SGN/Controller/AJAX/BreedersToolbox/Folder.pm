
package SGN::Controller::AJAX::BreedersToolbox::Folder;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub create_folder :Path('/ajax/folder/create') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $parent_folder_id = $c->req->param("parent_folder_id");
    my $folder_name = $c->req->param("folder_name");

    my $folder = CXGN::Trial::Folder->create(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    parent_folder_id => $parent_folder_id,
	    name => $folder_name,
	});

    $c->stash->{rest} = { success => 1 };
}

sub associate_folder :Path('/ajax/folder/associate') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $parent_folder_id = $c->req->param("parent_folder_id");
    my $child_folder_id = $c->req->param("child_folder_id");


}

sub list_folders : Path('/ajax/folder/list') Args(0) { 
    my $self = shift;
    my $c = shift;
    

}


1;

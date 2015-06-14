
package SGN::Controller::AJAX::BreedersToolbox::Folder;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub create_folder :Path('/ajax/folder/create/') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $parent_folder_id = shift;
    my $folder_name = shift;

    my $folder = CXGN::Trial::Folder->new(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    parent_folder_id => $parent_folder_id,
	    name => $folder_name,
	});
    
}

1;

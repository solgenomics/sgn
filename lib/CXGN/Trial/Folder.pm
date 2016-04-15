
package CXGN::Trial::Folder;

use Moose;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
		      is => 'rw',
		      required => 1,
    );

has 'folder_id' => ( isa => 'Int',
		     is => 'rw',
		     required => 1,
    );

has 'name' => ( isa => 'Str',
		is  => 'rw',
    );

has 'description' => (isa => 'Str',
		      is  => 'rw',
    );

has 'parent_folder_id' => (isa => 'Int',
			   is => 'rw',
    );



sub BUILD { 
    my $self = shift;

    my $row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=>$self->folder_id(), });
    
    if (!$row) { 
	die "The specified folder does not exist";
    }
    
    my $folder_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'trial_folder', 'project_property');

    my $prop = $self->bcs_schema()->resultset('Project::Projectprop')->find( { 
	project_id => $self->folder_id() });
    
    if ($prop->type->name() ne "folder") { 
	die "The folder you are trying to instantiate is not actually a folder";
    }

    my $parent_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find( { subject_project_id => $row->project_id() });

    my $parent_id = $parent_rel_row->object_project_id();

    $self->name( $row->name() );
    $self->description( $row->description );
    $self->parent_folder_id( $parent_id );    
}

# class method to create a folder
# CXGN::Trial::Folder::create( { bcs_schema => ... , name => ... });

sub create { 
    my $args = shift;
    
    # check if name is already taken
    #
    my $check_rs = $args->{bcs_schema}->resultset('Project::Project')->search( { name => $args->{name} } );
    if ($check_rs->count() > 0) { 
	die "The name ".$args->{name}." cannot be used for a folder because it already exists.";
    }
    
     my $folder_cvterm = SGN::Model::Cvterm->get_cvterm_row($args->{bcs_schema},'trial_folder', 'project_property');
    
    my $project_row = $args->{bcs_schema}->resultset('Project::Project')->create(
	    { 
		name =>  $args->{name},
		description => $args->{description},
	    });
	
    $project_row->create_projectprops( 
	    { 
		folder => 1,
	    },
	    { 
		cv_name => 'local'
	    });
    
    my $project_rel_rs = $args->{bcs_schema}->resultset('Project::ProjectRelationship')->create( 
	    { 
		object_project_id => $args->{parent_folder_id},
		subject_project_id => $project_row->project_id(),
		type_id => $folder_cvterm->cvterm_id(),
	    });
    return $project_row->project_id();
}


__PACKAGE__->meta->make_immutable();

1;

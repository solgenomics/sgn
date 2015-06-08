
package CXGN::Trial::Folder;

use Moose;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
		      is => 'rw',
		      required => 1,
    );

has 'project' => ( isa => 'Bio::Chado::Schema::Result::Project::Project', 
		   is => 'rw',
    );

has 'folder_id' => (isa => "Int",
		    is => 'rw',
    );

has 'parent_folder_id' => (isa => 'Int',
			   is => 'rw',
    );

has 'folder_type_id' => (isa => 'Int',
			 is => 'rw',    );

has 'breeding_program' => (isa => 'Bio::Chado::Schema::Project::Project',
			  is => 'rw',
    );

sub BUILD { 
    my $self = shift;

    my $row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=>$self->folder_id() });
    
    if (!$row) { 
	die "The specified folder does not exist!";
    }
    my $folder_cvterm = $self->bcs_schema()->resultset('Cv::Cvterm')->create_with(
	{ name   => 'folder',
	  cv     => 'local',
	  db     => 'local',
	  dbxref => 'folder',
	});
    
    my $prop = $self->bcs_schema()->resultset('Project::Projectprop')->find( { 
	project_id => $self->folder_id() });
    
    if ($prop->type->name() ne "folder") { 
	die "The folder you are trying to instantiate is not actually a folder";
    }
    
    my $parent_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find( { subject_project_id => $row->project_id() });

    my $parent_id;
    if ($parent_rel_row) { 
	$parent_id = $parent_rel_row->object_project_id();
	$self->parent_folder_id( $parent_id );    
    }
    $self->project($row);
    $self->folder_type_id($folder_cvterm->cvterm_id());
}
    
# class methods

sub create { 
    my $class = shift;
    my $args = shift;
    
    # check if name is already taken
    #
    my $check_rs = $args->{bcs_schema}->resultset('Project::Project')->search( { name => $args->{name} } );

    if ($check_rs->count() > 0) { 
	die "The name ".$args->{name}." cannot be used for a folder because it already exists.";
    }
    
    my $folder_type_id = CXGN::Trial::Folder->folder_cvterm_id( $args );
        
    my $project_row = $args->{bcs_schema}->resultset('Project::Project')->create(
	{ 
	    name =>  $args->{name},
	    description => $args->{description} || "",
	});
    
    my $project_id = $project_row->project_id();

    my $folder_projectprop_row = $args->{bcs_schema}->resultset('Project::Projectprop')->create( 
	{ 
	    project_id => $project_id,
	    type_id => $folder_type_id }
	);
	
    return $project_row;
}


sub list { 
    my $class = shift;
    my $args = shift;
    
    my $folder_type_id = CXGN::Trial::Folder->folder_cvterm_id( $args );

    my $breeding_program_type_id = $args->{bcs_schema}->resultset("Cv::Cvterm")->find( { name => 'breeding_program' })->cvterm_id();
    
    my $search_params = { type_id => { -in => $folder_type_id }};

    if ($args->{breeding_program_id}) { 
	push @{$search_params->{type_id}->{'-in'}}, $breeding_program_type_id;
    }

    my $rs = $args->{bcs_schema}->resultset("Project::Projectprop")->search($search_params)->search_related("project");
    
    my @folders;
    while (my $row = $rs->next()) { 
	push @folders, [ $row->project_id(), $row->get_column('name') ];
    }

    return @folders;								}


sub folder_cvterm_id { 
    my $class = shift;
    my $args = shift;
    
    my $folder_cvterm = $args->{bcs_schema}->resultset('Cv::Cvterm')->create_with(
	{ 
	    name   => 'trial_folder',
	    cv     => 'local',
	    db     => 'local',
	    dbxref => 'trial_folder',
	});
    
    return $folder_cvterm->cvterm_id();
}

### OBJECT METHODS

# returns a project row representing the parent, or undef.
#
sub get_parent { 
    my $self = shift;

    my $parent_rs = $self->project()->project_relationship_object_projects();

    if ($parent_rs->count() > 1) { 
	print STDERR "A folder can only have one parent... ignoring some parents.\n";
    }
    
    if ($parent_rs->count() == 0) { 
	return undef;
    }

    my $p_row = $parent_rs->first();
    return [ $p_row->project_id(), $p_row->name(), $p_row->description() ];
}


# return a resultset with children of the folder
#
sub children { 
    my $self = shift;
    
    my $rs = $self->bcs_schema()->resultset("Project::Project")->search_related( 'project_relationship_subject_projects', { object_project_id => $self->folder_id() });

    my @child_ids;
    while (my $child = $rs->next()) { 
	push @child_ids, $child->subject_project_id();
    }

    print STDERR "child_ids: ".(join(",",@child_ids))."; parent id: ".$self->folder_id()."\n";

    my $children_rs = $self->bcs_schema()->resultset("Project::Project")->search( { project_id => { -in => [ @child_ids] }});
    my @children;
    while (my $child = $children_rs->next()) { 
	push @children, [ $child->project_id(), $child->name(), $child->description() ];
    }

    return \@children;
}

sub associate_parent { 
    my $self = shift;
    my $parent_id = shift;

    # to do: check if parent is of type folder or breeding program
        
    my $project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->create( 
	{ 
	    object_project_id => $parent_id,
	    subject_project_id => $self->project()->project_id(),
	    type_id => $self->folder_type_id(),
	});

    $project_rel_row->insert();


}

sub associate_child { 
    my $self = shift;
    my $child_id = shift;
        
    # to do: check if child is of type "folder" or "trial"; otherwise refuse to associate

    my $project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->create( 
	{ 
	    subject_project_id => $child_id,
	    subject_project_id => $self->project()->project_id(),
	    type_id => $self->folder_type_id(),
	});

    $project_rel_row->insert();
}


sub remove_parent { 


}


sub remove_child { 


}



__PACKAGE__->meta->make_immutable();

1;

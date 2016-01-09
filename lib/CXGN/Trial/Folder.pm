
package CXGN::Trial::Folder;

use CXGN::Chado::Cvterm;

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
			 is => 'rw',
    );

has 'is_folder' => (isa => 'Bool',
		    is => 'rw',
		    default => 0,
    );

has 'name' => (isa => 'Str',
	       is => 'rw',
	       default => 'Untitled',
    );

has 'trial_breeding_program_relationship_type_id' =>  (isa => 'Int',
						       is => 'rw',
    );

has 'breeding_program' => (isa => 'Bio::Chado::Schema::Result::Project::Project',
			  is => 'rw',
    );

sub BUILD { 
    my $self = shift;

    my $row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=>$self->folder_id() });
    
    if (!$row) { 
	die "The specified folder with id ".$self->folder_id()." does not exist!";
    }

    $self->name($row->name());

    my $folder_cvterm_id = CXGN::Trial::Folder->folder_cvterm_id( { bcs_schema => $self->bcs_schema });
    my $breeding_program_type_id = $self->bcs_schema()->resultset("Cv::Cvterm")->find( { name => 'breeding_program' })->cvterm_id();
    
    
    print STDERR "FOLDER CVTERM ID: $folder_cvterm_id. FOLDER ID ".$self->folder_id()."\n";
    my $parent_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find( { subject_project_id => $self->folder_id(), type_id => $folder_cvterm_id });

    my $parent_id;
    if ($parent_rel_row) { 
	$parent_id = $parent_rel_row->object_project_id();
	$self->parent_folder_id( $parent_id );    
    }
    $self->project($row);

    my $breeding_program_trial_relationship_type_id = $self->bcs_schema()->resultset('Cv::Cvterm')->find( { name => 'breeding_program_trial_relationship' });

    my $folder_type = $self->bcs_schema()->resultset('Project::Projectprop')->find( { project_id => $self->folder_id(), type_id => { -in => [ $folder_cvterm_id, $breeding_program_type_id ] } } );
    if ($folder_type) { 
	$self->folder_type_id($folder_type->type_id());
    }
    
    
    if (defined($self->folder_type_id()) && ($self->folder_type_id() == $folder_cvterm_id || $self->folder_type_id() == $breeding_program_type_id)) { 
	print STDERR "Setting folder type to FOLDER.\n";
	$self->is_folder(1);
    }



    my $breeding_program_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find( { subject_project_id => $self->folder_id(), type_id => $breeding_program_trial_relationship_type_id->cvterm_id() });

    if ($breeding_program_rel_row) { 
	my $row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=> $breeding_program_rel_row->object_project_id() });
	$self->breeding_program($row);
    }

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
    print STDERR "PROJECT ID = $project_id\n";
    my $folder = CXGN::Trial::Folder->new( { bcs_schema => $args->{bcs_schema}, folder_id => $project_id });

    $folder->associate_parent($args->{parent_folder_id});
    $folder->associate_breeding_program($args->{breeding_program_id});
	
    return $folder;
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
    
    my $rs = $self->bcs_schema()->resultset("Project::Project")->search_related( 'project_relationship_subject_projects', { object_project_id => $self->folder_id() }, { order_by => 'me.name' });

    my @children;
    while (my $child = $rs->next()) { 
	push @children, CXGN::Trial::Folder->new( { bcs_schema=> $self->bcs_schema(), folder_id=>$child->subject_project_id() });

    }
    
    return \@children;
}

sub associate_parent { 
    my $self = shift;
    my $parent_id = shift;

    my $folder_type_id = CXGN::Trial::Folder->folder_cvterm_id( { bcs_schema => $self->bcs_schema() } );
    my $breeding_program_type_id = $self->bcs_schema()->resultset("Cv::Cvterm")->find( { name => 'breeding_program' })->cvterm_id();

    my $parent_row = $self->bcs_schema()->resultset("Project::Project")->find( { project_id => $parent_id } );

    if (!$parent_row) { 
	return "The folder specified as parent does not exist";
    }
    
    my $parentprop_row = $self->bcs_schema()->resultset("Project::Projectprop")->find( { project_id => $parent_id, type_id => { '-in' => [ $folder_type_id, $breeding_program_type_id ] } } );

    if (!$parentprop_row) { 
	return "The specified parent folder is not of type folder";
    }

    my $project_rels = $self->bcs_schema()->resultset('Project::ProjectRelationship')->search( 
	{ object_project_id => $parent_id, 
	  subject_project_id => $self->folder_id(),
	  type_id => $folder_type_id,
	});

    if ($project_rels->count() > 0) {
	while (my $p = $project_rels->next()) {
	    print STDERR "Removing parent folder association...\n";
	    $p->delete();
	}
    }

    my $project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->create( 
	{ 
	    object_project_id => $parent_id,
	    subject_project_id => $self->project()->project_id(),
	    type_id => $folder_type_id,
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
	    object_project_id => $self->project()->project_id(),
	    type_id => $self->folder_type_id(),
	});

    $project_rel_row->insert();
}

sub associate_breeding_program { 
    my $self = shift;
    my $breeding_program_id = shift;

    my $breeding_program_trial_relationship_type_id = $self->bcs_schema()->resultset('Cv::Cvterm')->find( { name => 'breeding_program_trial_relationship' });    
    my $project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find( 
	{ object_project_id => $breeding_program_id, 
	  subject_project_id =>  $self->folder_id(),
	});

    if (! $project_rel_row) { 
	$project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->create( 
	    { 
		object_project_id => $breeding_program_id,
		subject_project_id => $self->folder_id(),
		type_id => $breeding_program_trial_relationship_type_id,
	    });
	
	$project_rel_row->insert();
    }
    else { 
	$project_rel_row->object_project_id($breeding_program_id);
	$project_rel_row->update();
    }
}

sub remove_parent { 


}


sub remove_child { 


}

sub get_jstree_html { 
    my $self = shift;
    
    my $html = "";

    $html .= $self->_jstree_li_html('folder', $self->folder_id(), $self->name());
    $html .= "<ul>";	
    my $children = $self->children();

    if (@$children > 0) { 
	foreach my $child (@$children) { 
	    if ($child->is_folder()) { 

		$html .= $child->get_jstree_html();

	    }
	    else { 
		$html .= $self->_jstree_li_html('trial', $child->folder_id(), $child->name())."</li>\n";
	    }
	    
	}
	
    }
    
    $html .= '</ul></li>';
    return $html;
}

sub _jstree_li_html { 
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $name = shift;

    return "<li data-jstree='{\"type\":\"$type\"}' id=\"$id\">$name\n";
}




__PACKAGE__->meta->make_immutable();

1;

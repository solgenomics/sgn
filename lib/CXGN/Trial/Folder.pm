
package CXGN::Trial::Folder;

use CXGN::Chado::Cvterm;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
		      is => 'rw',
		      required => 1,
    );

has 'folder_id' => (isa => "Int",
		    is => 'rw',
    );

has 'children' => (is => 'rw',
		   lazy => 1,
		   default => sub {
		       my $self = shift;
		       $self->_get_children();
		   });

has 'is_folder' => (isa => 'Bool',
		    is => 'rw',
		    default => 0,
    );

has 'folder_type' => (isa => 'Str',
		      is => 'rw',
    );

has 'name' => (isa => 'Str',
	       is => 'rw',
	       default => 'Untitled',
    );

has 'breeding_program_trial_relationship_id' =>  (isa => 'Int',
						  is => 'rw',
		);

has 'project_parent' => (isa => 'Bio::Chado::Schema::Result::Project::Project',
			  is => 'rw',
    );

has 'breeding_program' => (isa => 'Bio::Chado::Schema::Result::Project::Project',
			  is => 'rw',
    );

has 'breeding_program_cvterm_id' => (isa => 'Int',
				     is => 'rw',
    );

has 'folder_cvterm_id' => (isa => 'Int',
			 is => 'rw',
			 );


sub BUILD {
    my $self = shift;

    my $row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=>$self->folder_id() });

    if (!$row) {
	die "The specified folder with id ".$self->folder_id()." does not exist!";
    }

    $self->name($row->name());

		my $breeding_program_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'breeding_program', 'project_property')->cvterm_id();
    $self->breeding_program_cvterm_id($breeding_program_type_id);

    my $folder_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'trial_folder', 'project_property')->cvterm_id();
		$self->folder_cvterm_id($folder_cvterm_id);

		my $breeding_program_trial_relationship_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
		$self->breeding_program_trial_relationship_id($breeding_program_trial_relationship_id);

    my $folder_type = $self->bcs_schema()->resultset('Project::Projectprop')-> search( { project_id => $self->folder_id() });

    while (my $folder_type_row = $folder_type->next) {
		if ($folder_type_row->type_id() == $self->folder_cvterm_id() ) {
			$self->folder_type("folder");
			$self->is_folder(1);
		}
		elsif ($folder_type_row->type_id() == $self->breeding_program_cvterm_id()) {
			#print STDERR "Setting folder type to breeding_program.\n";
			$self->folder_type("breeding_program");
		}
	}

		if (!$self->folder_type) {
				$self->folder_type("trial");
		}

    my $breeding_program_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find( { subject_project_id => $self->folder_id(), type_id =>  $self->breeding_program_trial_relationship_id() });
    if ($breeding_program_rel_row) {
				my $parent_row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=> $breeding_program_rel_row->object_project_id() });
				$self->project_parent($parent_row);
				$self->breeding_program($parent_row);
    }

    my $folder_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find( { subject_project_id => $self->folder_id(), type_id =>  $self->folder_cvterm_id() });
    if ($folder_rel_row) {
				my $parent_row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=> $folder_rel_row->object_project_id() });
				$self->project_parent($parent_row);
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

     my $folder_cvterm = SGN::Model::Cvterm->get_cvterm_row($args->{bcs_schema},'trial_folder', 'project_property');

    my $project_row = $args->{bcs_schema}->resultset('Project::Project')->create(
	{
	    name =>  $args->{name},
	    description => $args->{description} || "",
	});

    my $project_id = $project_row->project_id();

    my $folder_projectprop_row = $args->{bcs_schema}->resultset('Project::Projectprop')->create(
	{
	    project_id => $project_id,
	    type_id => $folder_cvterm->cvterm_id() }
	);

    my $folder = CXGN::Trial::Folder->new( { bcs_schema => $args->{bcs_schema}, folder_id => $project_id });

    $folder->associate_parent($args->{parent_folder_id});
    $folder->associate_breeding_program($args->{breeding_program_id});

    return $folder;
}


sub list {
    my $class = shift;
    my $args = shift;
		my $schema = $args->{bcs_schema};

    my $folder_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'trial_folder', 'project_property')->cvterm_id();
		my $breeding_program_trial_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema,'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
		
		my $breeding_program_rel;
		if ($args->{breeding_program_id}) {
			$breeding_program_rel = $schema->resultset('Project::ProjectRelationship')->search({ 'me.object_project_id' => $args->{breeding_program_id}, 'me.type_id' => $breeding_program_trial_relationship_id })->search_related("subject_project")->search_related("projectprops", {'projectprops.type_id'=>$folder_cvterm_id}, {'+select'=>'subject_project.name', '+as'=>'name' } );
		} else {
			$breeding_program_rel = $schema->resultset('Project::ProjectRelationship')->search({ 'me.type_id' => $breeding_program_trial_relationship_id })->search_related("subject_project")->search_related("projectprops", {'projectprops.type_id'=>$folder_cvterm_id}, {'+select'=>'subject_project.name', '+as'=>'name' } );
		}


    my @folders;
    while (my $row = $breeding_program_rel->next()) {
			push @folders, [ $row->project_id(), $row->get_column('name') ];
    }

    return @folders;
}



### OBJECT METHODS


# return a resultset with children of the folder
#
sub _get_children {
    my $self = shift;

    my @children;

    my $rs = $self->bcs_schema()->resultset("Project::Project")->search_related( 'project_relationship_subject_projects', { object_project_id => $self->folder_id() }, { order_by => 'me.name' });

    @children = map { $_->subject_project_id() } $rs->all();

    my @child_folders;
    foreach my $id (@children) {
	my $folder = CXGN::Trial::Folder->new( { bcs_schema=> $self->bcs_schema(), folder_id=>$id });

	# if the parent is a breeding program, don't
	# push children that have other parents
	#

	if ($self->folder_type() eq "breeding_program") {
		if ($folder->project_parent()) {
	    if ($folder->project_parent()->name() eq $self->name()) {
				#print STDERR "Pushing ".$folder->name()."\n";
				push @child_folders, $folder;
	    }
		}
	}
	else {
	    #print STDERR "parent is not a breeding program... pushing ".$folder->name()."...\n";
	    push @child_folders, $folder;
	}
    }

    return \@child_folders;
}

sub associate_parent {
    my $self = shift;
		my $parent_id = shift;
		
		my $folder_cvterm_id = $self->folder_cvterm_id();
		my $breeding_program_trial_relationship_id = $self->breeding_program_trial_relationship_id();
		
		#If the user selects 'None' to remove the trial from the folder, then the parent_id will be passed as 0. No new parent will be created.
		if ($parent_id == 0) {
			$self->remove_parents;
			return;
		}

		my $parent_row = $self->bcs_schema()->resultset("Project::Project")->find( { project_id => $parent_id } );

		if (!$parent_row) {
			print STDERR "The folder specified as parent does not exist";
			return;
		}

		my $parentprop_row = $self->bcs_schema()->resultset("Project::Projectprop")->find( { project_id => $parent_id,  type_id => { -in => [ $folder_cvterm_id, $breeding_program_trial_relationship_id ] } } );

		if (!$parentprop_row) {
			print STDERR "The specified parent folder is not of type folder or breeding program. Ignoring.";
			return;
		}
		
		$self->remove_parents;

		my $project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->create({
	    object_project_id => $parent_id,
	    subject_project_id => $self->folder_id(),
	    type_id => $folder_cvterm_id,
		});
		$project_rel_row->insert();

    $self->project_parent($parent_row);
		
		my $parent_is_child = check_if_folder_is_child_in_tree($self->bcs_schema, $parent_id, $self->children());
		if ($parent_is_child) {
			print STDERR 'Parent '.$parent_id.' is child in tree of folder '.$self->folder_id()."\n";
			my $parent_folder = CXGN::Trial::Folder->new({
				bcs_schema => $self->bcs_schema,
				folder_id => $parent_id
			});
			$parent_folder->remove_parents;			
		}
		
}

sub remove_parents {
	my $self = shift;
	#Remove any previous parents
	my $project_rels = $self->bcs_schema()->resultset('Project::ProjectRelationship')->search({
		subject_project_id => $self->folder_id(),
		type_id => $self->folder_cvterm_id()
	});

	if ($project_rels->count() > 0) {
		while (my $p = $project_rels->next()) {
			print STDERR $p->subject_project_id." : ".$p->object_project_id." : Removing parent folder association...\n";
			$p->delete();
		}
	}
	return;
}

sub check_if_folder_is_child_in_tree {
	my $schema = shift;
	my $folder_id = shift;
	my $children = shift;
	foreach (@$children) {
		my $child_folder_id = $_->folder_id();
		if ($child_folder_id == $folder_id) {
			return 1;
		} else{
			#print STDERR $child_folder_id."\n";
			my $child_folder = CXGN::Trial::Folder->new({
				bcs_schema => $schema,
				folder_id => $child_folder_id
			});
			return check_if_folder_is_child_in_tree($schema, $folder_id, $child_folder->children() );
		}
	}
	
	return;
}

sub associate_breeding_program {
    my $self = shift;
    my $breeding_program_id = shift;

    if (!$breeding_program_id) {
	print STDERR "No breeding_program_id provided. Ignoring association.\n";
	return;
    }

    my $project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->find(
	{ object_project_id => $breeding_program_id,
	  subject_project_id =>  $self->folder_id(),
	});

    if (! $project_rel_row) {
	#print STDERR "Creating folder association with breeding program id= $breeding_program_id, folder_id = ".$self->folder_id().", type_id = ".$self->breeding_program_trial_relationship_id()."\n";
	$project_rel_row = $self->bcs_schema()->resultset('Project::ProjectRelationship')->create(
	    {
		object_project_id => $breeding_program_id,
		subject_project_id => $self->folder_id(),
		type_id => $self->breeding_program_trial_relationship_id(),
	    });

	$project_rel_row->insert();
    }
    else {
	$project_rel_row->object_project_id($breeding_program_id);
	$project_rel_row->update();
    }

    my $row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=> $project_rel_row->object_project_id() });
    $self->breeding_program($row);

}

sub delete_folder {
	my $self = shift;
	my $delete_folder = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->folder_id })->delete();
	return;
}

sub remove_parent {


}


sub remove_child {


}

sub get_jstree_html {
    my $self = shift;
    my $parent_type = shift;

    my $html = "";

    $html .= $self->_jstree_li_html($parent_type, $self->folder_id(), $self->name());
    $html .= "<ul>";
    my $children = $self->children();

    if (@$children > 0) {
	foreach my $child (@$children) {
	    if ($child->is_folder()) {
		$html .= $child->get_jstree_html('folder');
	    }
	    else {
		$html .= $self->_jstree_li_html('trial', $child->folder_id(), $child->name())."</li>";
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

    return "<li data-jstree='{\"type\":\"$type\"}' id=\"$id\">".$name;
}




__PACKAGE__->meta->make_immutable();

1;

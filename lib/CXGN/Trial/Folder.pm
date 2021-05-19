
package CXGN::Trial::Folder;

use CXGN::Chado::Cvterm;
use CXGN::Location;
use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

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
	}
);

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

has 'folder_for_trials' => (isa => 'Bool',
	is => 'rw',
	default => 0,
);

has 'folder_for_crosses' => (isa => 'Bool',
	is => 'rw',
	default => 0,
);

has 'folder_for_genotyping_trials' => (isa => 'Bool',
	is => 'rw',
	default => 0,
);

has 'location_id' => (isa => 'Int',
	is => 'rw',
);

has 'location_name' => (isa => 'Str',
	is => 'rw',
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

has 'additional_info' => (
	is  => 'rw'
);

sub BUILD {
	my $self = shift;

	my $row = $self->bcs_schema()->resultset('Project::Project')->find( { project_id=>$self->folder_id() });

	if (!$row) {
		die "The specified folder with id ".$self->folder_id()." does not exist!";
	}

	$self->name($row->name());

	my $breeding_program_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'breeding_program', 'project_property')->cvterm_id();
	my $folder_for_trials_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'folder_for_trials', 'project_property')->cvterm_id();
	my $folder_for_crosses_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'folder_for_crosses', 'project_property')->cvterm_id();
	my $folder_for_genotyping_trials_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'folder_for_genotyping_trials', 'project_property')->cvterm_id();
	my $folder_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'trial_folder', 'project_property')->cvterm_id();
	my $analyses_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'analysis_metadata_json', 'project_property')->cvterm_id();
	my $breeding_program_trial_relationship_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
	my $additional_info_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'project_additional_info', 'project_property')->cvterm_id();

	$self->breeding_program_cvterm_id($breeding_program_type_id);
	$self->folder_cvterm_id($folder_cvterm_id);
	$self->breeding_program_trial_relationship_id($breeding_program_trial_relationship_id);

	my $folder_type = $self->bcs_schema()->resultset('Project::Projectprop')-> search( { project_id => $self->folder_id() });
	while (my $folder_type_row = $folder_type->next) {
		if ($folder_type_row->type_id() == $self->folder_cvterm_id() ) {
			$self->folder_type("folder");
			$self->is_folder(1);
		} elsif ($folder_type_row->type_id() == $self->breeding_program_cvterm_id()) {
			$self->folder_type("breeding_program");
		} elsif ($folder_type_row->type_id() == $folder_for_trials_cvterm_id) {
			$self->folder_for_trials(1);
		} elsif ($folder_type_row->type_id() == $folder_for_crosses_cvterm_id) {
			$self->folder_for_crosses(1);
		} elsif ($folder_type_row->type_id() == $folder_for_genotyping_trials_cvterm_id) {
			$self->folder_for_genotyping_trials(1);
		} elsif ($folder_type_row->type_id() == $additional_info_cvterm_id) {
			my $additional_info = decode_json($folder_type_row->value);
			$self->additional_info($additional_info);
		}
	}

	if (!$self->folder_type) {
		my $location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project location',  'project_property')->cvterm_id;

		my $trial_type_rs = $self->bcs_schema->resultset("Project::Project")->search({ 'me.project_id' => $self->folder_id })->search_related('projectprops');
		while (my $tt = $trial_type_rs->next()) {
			if ($tt->value eq 'crossing_trial') {
				$self->folder_type("cross");
			} elsif ($tt->value eq 'genotyping_plate') {
				$self->folder_type("genotyping_trial");
            } elsif ($tt->value eq 'sampling_trial') {
				$self->folder_type("sampling_trial");
            } elsif ($tt->type_id == $analyses_cvterm_id) {
				$self->folder_type("analyses");
			} elsif ($tt->type_id == $location_cvterm_id) {
				$self->location_id($tt->value + 0);
                my $location = CXGN::Location->new( { bcs_schema => $self->bcs_schema, nd_geolocation_id => $self->location_id } );
                $self->location_name($location->name());
			}
		}

		if (!$self->folder_type) {
			$self->folder_type("trial");
		}
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
	my $schema = $args->{bcs_schema};
	my $folder_name = $args->{name};
	my $description = $args->{description} || "";
	my $breeding_program_id = $args->{breeding_program_id};
	my $parent_folder_id = $args->{parent_folder_id};
	my $folder_for_trials = $args->{folder_for_trials};
	my $folder_for_crosses = $args->{folder_for_crosses};
	my $folder_for_genotyping_trials = $args->{folder_for_genotyping_trials};
	my $additional_info = $args->{additional_info} || undef;

	# check if name is already taken
	my $check_rs = $schema->resultset('Project::Project')->search( { name => $folder_name } );
	if ($check_rs->count() > 0) {
		die "The name $folder_name cannot be used for a new folder because it already exists.";
	}

	my $folder_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_folder', 'project_property');

	my $project = $schema->resultset('Project::Project')->create({
		name => $folder_name,
		description => $description,
	});
	$project->create_projectprops({ $folder_cvterm->name() => '1' });

	if ($folder_for_trials) {
		my $folder_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'folder_for_trials', 'project_property');
		$project->create_projectprops({ $folder_type_cvterm->name() => '1' });
	}
	if ($folder_for_crosses) {
		my $folder_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'folder_for_crosses', 'project_property');
		$project->create_projectprops({ $folder_type_cvterm->name() => '1' });
	}
    if ($folder_for_genotyping_trials) {
        my $folder_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'folder_for_genotyping_trials', 'project_property');
        $project->create_projectprops({ $folder_type_cvterm->name() => '1' });
    }
	if ($additional_info){
		my $additional_info_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_additional_info', 'project_property');
		$project->create_projectprops({ $additional_info_cvterm->name() => encode_json($additional_info) });
	}

	my $folder = CXGN::Trial::Folder->new({
		bcs_schema => $schema,
		folder_id => $project->project_id()
	});
	$folder->associate_parent($parent_folder_id);
	$folder->associate_breeding_program($breeding_program_id);

	return $folder;
}

#CLASS function
sub list {
	my $class = shift;
	my $args = shift;
	my $schema = $args->{bcs_schema};
	my $breeding_program_id = $args->{breeding_program_id};
	my $folder_for_trials = $args->{folder_for_trials};
	my $folder_for_crosses = $args->{folder_for_crosses};
	my $folder_for_genotyping_trials = $args->{folder_for_genotyping_trials};

	my $folder_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'trial_folder', 'project_property')->cvterm_id();
	my $breeding_program_trial_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema,'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();

	my %object_project_params;
	$object_project_params{'me.type_id'} = $breeding_program_trial_relationship_id;
	if ($breeding_program_id){
		$object_project_params{'me.object_project_id'} = $breeding_program_id;
	}

	my %projectprop_params;
	if (!$folder_for_trials && !$folder_for_crosses && !$folder_for_genotyping_trials){
		$projectprop_params{'projectprops.type_id'} = $folder_cvterm_id;
	} elsif ($folder_for_trials){
		my $folder_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'folder_for_trials', 'project_property')->cvterm_id();
		$projectprop_params{'projectprops.type_id'} = $folder_type_cvterm_id;
	} elsif ($folder_for_crosses){
		my $folder_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'folder_for_crosses', 'project_property')->cvterm_id();
		$projectprop_params{'projectprops.type_id'} = $folder_type_cvterm_id;
    } elsif ($folder_for_genotyping_trials){
        my $folder_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'folder_for_genotyping_trials', 'project_property')->cvterm_id();
        $projectprop_params{'projectprops.type_id'} = $folder_type_cvterm_id;
    }

	my $breeding_program_rel = $schema->resultset('Project::ProjectRelationship')->search(\%object_project_params)->search_related("subject_project")->search_related("projectprops", \%projectprop_params, {'+select'=>'subject_project.name', '+as'=>'name' } );

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

    my $folder_cvterm_id = $self->folder_cvterm_id();
	my $rs = $self->bcs_schema()->resultset("Project::Project")->search_related( 'project_relationship_subject_projects', { object_project_id => $self->folder_id(), type_id => $folder_cvterm_id }, { order_by => 'me.name' });

	@children = map { $_->subject_project_id() } $rs->all();

	my @child_folders;
	foreach my $id (@children) {
		my $folder = CXGN::Trial::Folder->new({
			bcs_schema=> $self->bcs_schema(),
			folder_id=>$id,
		});

		if ($self->folder_type() eq "breeding_program") {
			if ($folder->project_parent()) {
				if ($folder->project_parent()->name() eq $self->name()) {
					#print STDERR "Pushing ".$folder->name().$folder->folder_type."\n";
					push @child_folders, $folder;
				}
			}
		} else {
			#print STDERR "parent is not a breeding program... pushing ".$folder->name().$folder->folder_type."...\n";
			push @child_folders, $folder;
		}
	}

	return \@child_folders;
}

# return a resultset with children of the folder quickly
#
sub fast_children {

	my $self = shift;
    my $schema = shift;
    my $parent_type = shift;
    my (@folder_contents, %children);

    #print STDERR "Running get children for project ".$self->{'name'}." at time ".localtime()."\n";

    if ($parent_type eq 'breeding_program') {
        my $rs = $schema->resultset("Project::Project")->search_related(
            'project_relationship_subject_projects',
            {   'type.name' => 'trial_folder'
            },
            {   join => 'type'
            });
        @folder_contents = map { $_->subject_project_id() } $rs->all();
    }

	my $rs = $schema->resultset("Project::Project")->search_related(
        'project_relationship_subject_projects',
        {   object_project_id => $self->{'id'},
            subject_project_id => { 'not in' => \@folder_contents }
        },
        {   join      => { subject_project => { projectprops => 'type' } },
            '+select' => ['subject_project.name', 'projectprops.value', 'type.name'],
            '+as'     => ['project_name', 'project_value', 'project_type']
        }
     );

    while (my $row = $rs->next) {
        my $name = $row->get_column('project_name');
        $children{$name}{'name'} = $name;
        $children{$name}{'id'} = $row->subject_project_id();
        if ($row->get_column('project_value')){
            $children{$name}{$row->get_column('project_value')} = 1;
        }
        if ($row->get_column('project_type')){
            $children{$name}{$row->get_column('project_type')} = 1;
        }
    }

    #print STDERR "Finished running get children for project ".$self->{'name'}." at time ".localtime()."\n";  #Children are: ".Dumper(%children);
	return %children
}

sub set_folder_content_type {
	my $self = shift;
	my $type = shift; #folder_for_trials or folder_for_crosses
	my $boolean_value = shift; #0 or 1

	my $folder_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $type, 'project_property')->cvterm_id();
	my $prop = $self->bcs_schema->resultset('Project::Projectprop')->find({
		project_id => $self->folder_id,
		type_id => $folder_type_cvterm_id
	});
	if ($boolean_value){
		if (!$prop){
			my $new_prop = $self->bcs_schema->resultset('Project::Projectprop')->create({
				project_id => $self->folder_id,
				type_id => $folder_type_cvterm_id,
				value => '1'
			});
		}
	} else {
		if ($prop){
			$prop->delete();
		}
	}
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

	my $children = $self->children();
	if (scalar(@$children) > 0) {
		return;
	}
	my $delete_folder = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->folder_id })->delete();
	return 1;
}

sub rename_folder {
        my $self = shift;
	my $new_name = shift;
	my $folder_exists = $self->get_folder_by_name($new_name);
	return 0 if $folder_exists;
	my $update_folder = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->folder_id });
	$update_folder->name($new_name );
	$update_folder->update();
	return 1;
}

sub get_folder_by_name { 
    my $self= shift;
    my $name = shift;
    my $exists = $self->bcs_schema->resultset("Project::Project")->search( { name => $name } );
    my $count = $exists->count();
    if ( $exists->count() > 0 ) { return 1 } else { return 0 }
    return;
}

sub remove_parent {


}


sub remove_child {


}

sub get_jstree_html {
    shift;
    my $self = shift;
    my $schema = shift;
    my $parent_type = shift;
    my $project_type_of_interest = shift // 'trial';
    #print STDERR "Running get js tree html on project ".$self->{'name'}." at time ".localtime()."\n";
    my ($folder_type_of_interest, $local_type_of_interest, $html);

    if ($project_type_of_interest eq 'trial') {
        $local_type_of_interest = 'design'; # there is no 'trial' project prop, so using this as a proxy
        $folder_type_of_interest = 'folder_for_trials';
    }
    elsif ($project_type_of_interest eq 'cross') {
        $local_type_of_interest = 'crossing_trial';
        $folder_type_of_interest = 'folder_for_crosses';
    }
    elsif ($project_type_of_interest eq 'genotyping_trial') {
        $local_type_of_interest = 'genotyping_plate'; # in order to match projectprop value
        $folder_type_of_interest = 'folder_for_genotyping_trials';
    }

    $html .= _jstree_li_html($schema, $parent_type, $self->{'id'}, $self->{'name'});
    $html .= "<ul>";

    my %children = fast_children($self, $schema, $parent_type);
    print STDERR Dumper \%children;
    if (%children) {
        foreach my $child (sort keys %children) {
            #print STDERR "Working on child ".$children{$child}->{'name'}."\n";

            if ($project_type_of_interest eq 'trial' && $children{$child}->{'analysis_experiment'}) {
                $html .= _jstree_li_html($schema, 'analyses', $children{$child}->{'id'}, $children{$child}->{'name'})."</li>";
            }
            elsif ($project_type_of_interest eq 'trial' && $children{$child}->{'genotype_data_project'}) {
                $html .= _jstree_li_html($schema, 'genotyping_data_project', $children{$child}->{'id'}, $children{$child}->{'name'})."</li>";
            }
            elsif ($project_type_of_interest eq 'trial' && $children{$child}->{'sampling_trial'}) {
                $html .= _jstree_li_html($schema, 'sampling_trial', $children{$child}->{'id'}, $children{$child}->{'name'})."</li>";
            }
            elsif ($children{$child}->{$folder_type_of_interest}) {
                $html .= get_jstree_html('shift', $children{$child}, $schema, 'folder', $project_type_of_interest);
            }
            elsif (!$children{$child}->{'folder_for_crosses'} && !$children{$child}->{'folder_for_genotyping_trials'} && !$children{$child}->{'folder_for_trials'} && $children{$child}->{'trial_folder'}) {
                $html .= get_jstree_html('shift', $children{$child}, $schema, 'folder', $project_type_of_interest);
            }
            elsif ($local_type_of_interest eq 'design' && $children{$child}->{'genotyping_plate'}){
                next; #skip genotyping plates in field trial tree
            }
            elsif ($children{$child}->{$local_type_of_interest}) { #Only display $project of interest types.
                $html .= _jstree_li_html($schema, $project_type_of_interest, $children{$child}->{'id'}, $children{$child}->{'name'})."</li>";
            }
        }
    }
    $html .= '</ul></li>';
    #print STDERR "Finished, returning with html at time ".localtime()."\n";
    return $html;
}

sub _jstree_li_html {
    my $schema = shift;
    my $type = shift;
    my $id = shift;
    my $name = shift;

    my $url = '#';
    if ($type eq 'trial' || $type eq 'genotyping_trial' || $type eq 'sampling_trial') {
        $url = "/breeders/trial/".$id;
    } elsif ($type eq 'folder') {
        $url = "/folder/".$id;
    } elsif ($type eq 'cross') {
        $url = "/cross/".$id;
    } elsif ($type eq 'analyses') {
        $url = "/analyses/".$id;
    } elsif ($type eq 'breeding_program') {
        $url = "/breeders/program/".$id;
    }

    return "<li data-jstree='{\"type\":\"$type\"}' id=\"$id\"><a href=\"$url\">".$name.'</a>';
}




__PACKAGE__->meta->make_immutable();

1;

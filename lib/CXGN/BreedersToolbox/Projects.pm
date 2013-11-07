
package CXGN::BreedersToolbox::Projects;


use Moose;
use Data::Dumper;

has 'schema' => ( isa => 'Bio::Chado::Schema',
                  is => 'rw');


sub get_breeding_programs { 
    my $self = shift;
    

    my $breeding_program_cvterm_id = $self->schema->resultset('Cv::Cvterm')->find_or_create( { name => 'breeding_program' })->cvterm_id();

    my $rs = $self->schema->resultset('Project::Project')->search( { 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );

    my @projects;
    while (my $row = $rs->next()) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
    }

    return \@projects;
}


sub get_trials_by_breeding_program { 
    my $self = shift;
    my $breeding_project_id = shift;

    my $dbh = $self->schema->storage->dbh();
    my $breeding_program_cvterm_id = $self->schema->resultset('Cv::Cvterm')->find_or_create( { name => 'breeding_program' })->cvterm_id();
        
    my $trials = [];
    my $h;
    if ($breeding_project_id) { 
	# need to convert to dbix class.... good luck!
	my $q = "SELECT trial.project_id, trial.name, trial.description FROM project LEFT join project_relationship ON (project_id=object_project_id) LEFT JOIN project as trial ON (subject_project_id=trial.project_id) WHERE project.project_id=?";
	
	$h = $dbh->prepare($q);
	$h->execute($breeding_project_id);
	
    }
    else { 
	# get trials that are not associated with any project
	my $q = "SELECT project.project_id, project.name, project.description FROM project JOIN projectprop USING(project_id) LEFT JOIN project_relationship ON (subject_project_id=project.project_id) WHERE project_relationship_id IS NULL and projectprop.type_id != ?";
	$h = $dbh->prepare($q);
	$h->execute($breeding_program_cvterm_id);
    }
    while (my ($id, $name, $desc) = $h->fetchrow_array()) { 
	push @$trials, [ $id, $name, $desc ];
    }
    
    print STDERR "TRIAL DATA: ".Data::Dumper::Dumper($trials);
    return $trials;
}


sub get_locations_by_breeding_program { 
    my $self = shift;
    my $breeding_program_id = shift;

    my $h;

    if ($breeding_program_id) { 
	my $q = "SELECT distinct(nd_geolocation_id), nd_geolocation.description FROM project JOIN project_relationship on (project_id=object_project_id) JOIN project as trial ON (subject_project_id=trial.project_id) JOIN nd_experiment_project ON (trial.project_id=nd_experiment_project.project_id) JOIN nd_experiment USING (nd_experiment_id) JOIN nd_geolocation USING (nd_geolocation_id) WHERE project.project_id=?";

	$h = $self->schema()->storage()->dbh()->prepare($q);
	$h->execute($breeding_program_id);

    }
    else { 
	my $q = "SELECT distinct(nd_geolocation_id), nd_geolocation.description FROM nd_geolocation LEFT JOIN nd_experiment USING(nd_geolocation_id) where nd_experiment_id IS NULL";

	$h = $self->schema()->storage()->dbh()->prepare($q);
	$h->execute();
    }

    my @locations;
    while (my ($id, $name) = $h->fetchrow_array()) { 
	push @locations, [ $id, $name ];
    }
    return \@locations;
}

sub get_accessions_by_breeding_program { 


}


sub new_breeding_program { 



}


sub delete_breeding_program { 




}

sub get_breeding_program_with_trial { 
    my $self = shift;
    my $trial_id = shift;

    my $rs = $self->schema->resultset("Project::ProjectRelationship")->search( { subject_project_id => $trial_id });

    my $breeding_projects = [];
    if (my $row = $rs->next()) { 
	my $prs = $self->schema->resultset("Project::Project")->search( { project_id => $row->object_project_id() } );
	while (my $b = $prs->next()) { 
	    push @$breeding_projects, [ $b->project_id(), $b->name(), $b->description() ];
	}
    }
    return $breeding_projects;
}

sub associate_breeding_program_with_trial { 
    my $self = shift;
    my $breeding_project_id = shift;
    my $trial_id = shift;

    my $cv_id = $self->schema->resultset('Cv::Cv')->find( { name => 'local' } )->cv_id();

    my $breeding_trial_cvterm_row = $self->schema->resultset('Cv::Cvterm')->find( { name => 'breeding_program_trial_relationship' });
    
    if (!$breeding_trial_cvterm_row) { 
	my $row = $self->schema->resultset('Cv::Cvterm')->create_with( 
	    { 
		name => 'breeding_program_trial_relationship',
		cv   => 'local',
		db   => 'local',
		dbxref => 'breeding_program_trial_relationship',
	    });
	$breeding_trial_cvterm_row = $row;
    }
    my $breeding_trial_cvterm_id = $breeding_trial_cvterm_row ->cvterm_id();
    
    # to do: check if the two provided IDs are of the proper type

    eval { 
	my $breeding_trial_assoc = $self->schema->resultset("Project::ProjectRelationship")->update_or_new( 
	    { 
		object_project_id => $breeding_project_id,
		subject_project_id => $trial_id,
		type_id => $breeding_trial_cvterm_id,
	    }
	    );
	
	if (! $breeding_trial_assoc->in_storage()) { $breeding_trial_assoc->insert(); }

    };
    if ($@) { 
	print STDERR "ERROR: $@\n";
	return { error => "An error occurred while storing the breeding program - trial relationship." };
    }
    return {};
}

1;

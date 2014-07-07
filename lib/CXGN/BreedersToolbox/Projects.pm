
package CXGN::BreedersToolbox::Projects;


use Moose;
use Data::Dumper;

# has 'schema' => ( isa => 'Bio::Chado::Schema',
#                   is => 'rw');

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		);


sub trial_exists { 
    my $self = shift;
    my $trial_id = shift;
    
    my $rs = $self->schema->resultset('Project::Project')->search( { project_id => $trial_id });
    
    if ($rs->count() == 0) { 
	return 0;
    }
    return 1;
}

sub get_breeding_programs {
    my $self = shift;


    my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id();

    my $rs = $self->schema->resultset('Project::Project')->search( { 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );

    my @projects;
    while (my $row = $rs->next()) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
    }

    return \@projects;
}

sub get_breeding_programs_by_trial {
    my $self = shift;
    my $trial_id = shift;

    my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id();

    my $trial_row = $self->schema->resultset('Project::ProjectRelationship')->find( { 'subject_project_id' => $trial_id } );
    
    my $rs = $self->schema->resultset('Project::Project')->search( { 'me.project_id' => $trial_row->object_project_id(), 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );

    my @projects;
    while (my $row = $rs->next()) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
    }

    return  \@projects;
}



sub get_breeding_program_by_name {
  my $self = shift;
  my $program_name = shift;
  my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id();

  my $rs = $self->schema->resultset('Project::Project')->find( { 'name'=>$program_name, 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );

  if (!$rs) {
    return;
  }

  return $rs;

}

sub _get_all_trials_by_breeding_program {
    my $self = shift;
    my $breeding_project_id = shift;
    my $dbh = $self->schema->storage->dbh();
    my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id();

    my $trials = [];
    my $h;
    if ($breeding_project_id) { 
	# need to convert to dbix class.... good luck!
	#my $q = "SELECT trial.project_id, trial.name, trial.description FROM project LEFT join project_relationship ON (project.project_id=object_project_id) LEFT JOIN project as trial ON (subject_project_id=trial.project_id) LEFT JOIN projectprop ON (trial.project_id=projectprop.project_id) WHERE (project.project_id=? AND (projectprop.type_id IS NULL OR projectprop.type_id != ?))";
	my $q = "SELECT trial.project_id, trial.name, trial.description, projectprop.type_id, projectprop.value FROM project LEFT join project_relationship ON (project.project_id=object_project_id) LEFT JOIN project as trial ON (subject_project_id=trial.project_id) LEFT JOIN projectprop ON (trial.project_id=projectprop.project_id) WHERE (project.project_id = ?)";

	$h = $dbh->prepare($q);
	#$h->execute($breeding_project_id, $cross_cvterm_id);
	$h->execute($breeding_project_id);

    }
    else { 
	# get trials that are not associated with any project
	my $q = "SELECT project.project_id, project.name, project.description n, projectprop.type_id, projectprop.value FROM project JOIN projectprop USING(project_id) LEFT JOIN project_relationship ON (subject_project_id=project.project_id) WHERE project_relationship_id IS NULL and projectprop.type_id != ?";
	$h = $dbh->prepare($q);
	$h->execute($breeding_program_cvterm_id);
    }

    return $h;
}

sub get_trials_by_breeding_program {
    my $self = shift;
    my $breeding_project_id = shift;
    my $trials;
    my $h = $self->_get_all_trials_by_breeding_program($breeding_project_id);
    my $cross_cvterm_id = $self->get_cross_cvterm_id();
    my $project_year_cvterm_id = $self->get_project_year_cvterm_id();

    my %projects_that_are_crosses;
    my %project_year;
    my %project_name;
    my %project_description;

    while (my ($id, $name, $desc, $prop, $propvalue) = $h->fetchrow_array()) {
	#push @$trials, [ $id, $name, $desc ];
      if ($name) {
	$project_name{$id} = $name;
      }
      if ($desc) {
	$project_description{$id} = $desc;
      }
      if ($prop) {
	if ($prop == $cross_cvterm_id) {
	  $projects_that_are_crosses{$id} = 1;
	}
	if ($prop == $project_year_cvterm_id) {
	  $project_year{$id} = $propvalue;
	}
      }

    }

    my @sorted_by_year_keys = sort { $project_year{$a} cmp $project_year{$b} } keys(%project_year);

    foreach my $id_key (@sorted_by_year_keys) {
      if (!$projects_that_are_crosses{$id_key}) {
	push @$trials, [ $id_key, $project_name{$id_key}, $project_description{$id_key}];
      }
    }

    return $trials;
}

sub get_genotyping_trials_by_breeding_program {
    my $self = shift;
    my $breeding_project_id = shift;
    my $trials;
    my $h = $self->_get_all_trials_by_breeding_program($breeding_project_id);
    my $cross_cvterm_id = $self->get_cross_cvterm_id();
    my $project_year_cvterm_id = $self->get_project_year_cvterm_id();
    my $genotyping_trial_cvterm_id = $self->_get_genotyping_trial_cvterm_id();

    my %projects_that_are_crosses;
    my %projects_that_are_genotyping_trials;
    my %project_year;
    my %project_name;
    my %project_description;

    while (my ($id, $name, $desc, $prop, $propvalue) = $h->fetchrow_array()) {
      if ($name) {
	$project_name{$id} = $name;
      }
      if ($desc) {
	$project_description{$id} = $desc;
      }
      if ($prop) {
	if ($prop == $cross_cvterm_id) {
	  $projects_that_are_crosses{$id} = 1;
	}
	if ($prop == $project_year_cvterm_id) {
	  $project_year{$id} = $propvalue;
	}
	if ($prop == $genotyping_trial_cvterm_id) {
	  $projects_that_are_genotyping_trials{$id} = 1;
	}
      }

    }

    my @sorted_by_year_keys = sort { $project_year{$a} cmp $project_year{$b} } keys(%project_year);

    foreach my $id_key (@sorted_by_year_keys) {
      if (!$projects_that_are_crosses{$id_key}) {
	if ($projects_that_are_genotyping_trials{$id_key}) {
	  push @$trials, [ $id_key, $project_name{$id_key}, $project_description{$id_key}];
	}
      }
    }

    return $trials;

}


sub get_locations_by_breeding_program { 
    my $self = shift;
    my $breeding_program_id = shift;

    my $h;

    my $type_id = $self->schema->resultset('Cv::Cvterm')->search( { 'name'=>'plot' })->first->cvterm_id;

    if ($breeding_program_id) {
	my $q = "SELECT distinct(nd_geolocation_id), nd_geolocation.description, count(distinct(stock.stock_id)) FROM project JOIN project_relationship on (project_id=object_project_id) JOIN project as trial ON (subject_project_id=trial.project_id) JOIN nd_experiment_project ON (trial.project_id=nd_experiment_project.project_id) JOIN nd_experiment USING (nd_experiment_id) JOIN nd_experiment_stock ON (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id) JOIN stock ON (nd_experiment_stock.stock_id=stock.stock_id) JOIN nd_geolocation USING (nd_geolocation_id) WHERE project.project_id=? and stock.type_id=? GROUP BY nd_geolocation.nd_geolocation_id, nd_experiment.nd_geolocation_id, nd_geolocation.description";

	$h = $self->schema()->storage()->dbh()->prepare($q);
	$h->execute($breeding_program_id, $type_id);

    }
    else {
	my $q = "SELECT distinct(nd_geolocation_id), nd_geolocation.description FROM nd_geolocation LEFT JOIN nd_experiment USING(nd_geolocation_id) where nd_experiment_id IS NULL";

	$h = $self->schema()->storage()->dbh()->prepare($q);
	$h->execute();
    }

    my @locations;
    while (my ($id, $name, $plot_count) = $h->fetchrow_array()) {
	push @locations, [ $id, $name, $plot_count ];
    }
    return \@locations;
}

sub get_accessions_by_breeding_program {


}


sub new_breeding_program {
    my $self= shift;
    my $name = shift;
    my $description = shift;

    my $type_id = $self->get_breeding_program_cvterm_id();

    my $rs = $self->schema()->resultset("Project::Project")->search(
	{
	    name => $name,
	});
    if ($rs->count() > 0) {
	return "A breeding program with name '$name' already exists.";
    }

    eval { 
	my $row = $self->schema()->resultset("Project::Project")->create(
	    {
		name => $name,
		description => $description,
	    });

	$row->insert();

	my $prop_row = $self->schema()->resultset("Project::Projectprop")->create(
	    {
		type_id => $type_id,
		project_id => $row->project_id(),

	    });
	$prop_row->insert();

    };
    if ($@) {
	return "An error occurred while generating a new breeding program. ($@)";
    }

}


sub delete_breeding_program {
    my $self = shift;
    my $project_id = shift;

    my $type_id = $self->get_breeding_program_cvterm_id();

    # check if this project entry is of type 'breeding program'
    my $prop = $self->schema->resultset("Project::Projectprop")->search(
	type_id => $type_id,
	project_id => $project_id,
	);

    if ($prop->count() == 0) {
	return 0; # wrong type, return 0.
    }

    $prop->delete();

    my $rs = $self->schema->resultset("Project::Project")->search(
	project_id => $project_id,
	);

    if ($rs->count() > 0) {
	my $pprs = $self->schema->resultset("Project::ProjectRelationship")->search(
	    object_project_id => $project_id,
	    );

	if ($pprs->count()>0) {
	    $pprs->delete();
	}
	$rs->delete();
	return 1;
    }
    return 0;
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

    my $breeding_trial_cvterm_id = $self->get_breeding_trial_cvterm_id();

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

sub remove_breeding_program_from_trial { 
    my $self = shift;
    my $breeding_program_id = shift;
    my $trial_id = shift;

    my $breeding_trial_cvterm_id = $self->get_breeding_trial_cvterm_id();

    eval {
	my $breeding_trial_assoc_rs = $self->schema->resultset("Project::ProjectRelationship")->search(
	    {
		object_project_id => $breeding_program_id,
		subject_project_id => $trial_id,
		type_id => $breeding_trial_cvterm_id,
	    }
	    );
	if (my $row = $breeding_trial_assoc_rs->first()) {
	    $row->delete();
	}
    };

    if ($@) { 
	return { error => "An error occurred while deleting a breeding program - trial association. $@" };
    }
    return {};
}


sub get_breeding_program_cvterm_id {
    my $self = shift;

    my $breeding_program_cvterm_rs = $self->schema->resultset('Cv::Cvterm')->search( { name => 'breeding_program' });

    my $row;

    if ($breeding_program_cvterm_rs->count() == 0) {
	$row = $self->schema->resultset('Cv::Cvterm')->create_with(
	    {
		name => 'breeding_program',
		cv   => 'local',
		db   => 'local',
		dbxref => 'breeding_program',
	    });

    }
    else {
	$row = $breeding_program_cvterm_rs->first();
    }

    return $row->cvterm_id();
}

sub get_breeding_trial_cvterm_id {
    my $self = shift;

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
    return $breeding_trial_cvterm_row->cvterm_id();
}

sub get_cross_cvterm_id {
    my $self = shift;
    my $cv_id = $self->schema->resultset('Cv::Cv')->find( { name => 'stock type' } )->cv_id();
    my $cross_cvterm_row = $self->schema->resultset('Cv::Cvterm')->find( { name => 'cross', cv_id=> $cv_id });
    if ($cross_cvterm_row) {
      return $cross_cvterm_row->cvterm_id();
    }
    my $cross_cvterm = $self->schema->resultset("Cv::Cvterm")
      ->create_with( { name   => 'cross',
		       cv     => 'stock type',
		     });
    return $cross_cvterm->cvterm_id();
}

sub _get_genotyping_trial_cvterm_id {
    my $self = shift;
     my $cvterm = $self->schema->resultset("Cv::Cvterm")
      ->create_with({
		     name   => 'genotyping trial',
		     cv     => 'trial type',
		     db     => 'null',
		     dbxref => 'genotyping trial',
		    });
    return $cvterm->cvterm_id();
}

sub get_project_year_cvterm_id {
    my $self = shift;
    my $year_cvterm_row = $self->schema->resultset('Cv::Cvterm')->find( { name => 'project year' });
    return $year_cvterm_row->cvterm_id();
}


1;


=head1 NAME

CXGN::Trial - helper class for trials

=head1 SYNOPSYS

 my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
 $trial->set_description("yield trial with promising varieties");
 etc.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::Trial;

use Moose;
use Data::Dumper;
use Try::Tiny;
use Data::Dumper;
use CXGN::Trial::Folder;
use CXGN::Trial::TrialLayout;
use SGN::Model::Cvterm;
use Time::Piece;
use Time::Seconds;
use CXGN::Calendar;


=head2 accessor bcs_schema()

accessor for bcs_schema. Needs to be set when calling the constructor.

=cut

has 'bcs_schema' => ( isa => "Ref",
		      is => 'rw',
		      required => 1,
    );



sub BUILD {
    my $self = shift;

    my $row = $self->bcs_schema->resultset("Project::Project")->find( { project_id => $self->get_trial_id() });

    if ($row){
	#print STDERR "Found row for ".$self->get_trial_id()." ".$row->name()."\n";
    }

    if (!$row) {
	die "The trial ".$self->get_trial_id()." does not exist";
    }
}

=head2 accessors get_trial_id()

 Desc: get the trial id

=cut

has 'trial_id' => (isa => 'Int',
		   is => 'rw',
		   reader => 'get_trial_id',
		   writer => 'set_trial_id',
    );

=head2 accessors get_layout(), set_layout()

 Desc: set the layout object for this trial (CXGN::Trial::TrialLayout)
 (This is populated automatically by the constructor)

=cut

has 'layout' => (isa => 'CXGN::Trial::TrialLayout',
		 is => 'rw',
		 reader => 'get_layout',
		 writer => 'set_layout',
		 predicate => 'has_layout',
		 lazy => 1,
		 default => sub { my $self = shift; $self->_get_layout(); }
    );

sub _get_layout { 
    my $self = shift;
    print STDERR "RETRIEVING LAYOUT...\n";
    my $layout = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $self->get_trial_id() });
    $self->set_layout($layout);
}
    

=head2 accessors get_year(), set_year()

getter/setter for the year property. The setter modifies the database.

=cut

sub get_year {
    my $self = shift;

    my $type_id = $self->get_year_type_id();

    my $rs = $self->bcs_schema->resultset('Project::Project')->search( { 'me.project_id' => $self->get_trial_id() })->search_related('projectprops', { type_id => $type_id } );

    if ($rs->count() == 0) {
	return undef;
    }
    else {
	return $rs->first()->value();
    }
}

sub set_year {
    my $self = shift;
    my $year = shift;

    my $type_id = $self->get_year_type_id();

    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find( { project_id => $self->get_trial_id(), type_id => $type_id  });

    if ($row) {
	$row->value($year);
	$row->update();
    }
    else {
	$row = $self->bcs_schema->resultset('Project::Projectprop')->create(
	    { 
		type_id => $type_id,
		value => $year,
		project_id =>  $self->get_trial_id()
	    } );
    }
}

=head2 accessors get_description(), set_description()

getter/setter for the description

=cut

sub get_description {
    my $self = shift;

    my $rs = $self->bcs_schema->resultset('Project::Project')->search( { project_id => $self->get_trial_id() });

    return $rs->first()->description();

}


sub set_description {
    my $self = shift;
    my $description = shift;

    my $row = $self->bcs_schema->resultset('Project::Project')->find( { project_id => $self->get_trial_id() });

    #print STDERR "Setting new description $description for trial ".$self->get_trial_id()."\n";

    $row->description($description);

    $row->update();

}


=head2 function get_location()

 Usage:        my $location = $trial->get_location();
 Desc:
 Ret:          [ location_id, 'location description' ]
 Args:
 Side Effects:
 Example:

=cut

sub get_location {
    my $self = shift;

    if ($self->get_location_type_id()) {
	my $row = $self->bcs_schema->resultset('Project::Projectprop')->find( { project_id => $self->get_trial_id() , type_id=> $self->get_location_type_id() });

	if ($row) {
	    my $loc = $self->bcs_schema->resultset('NaturalDiversity::NdGeolocation')->find( { nd_geolocation_id => $row->value() });

	    return [ $row->value(), $loc->description() ];
	}
	else {
	    return [];
	}
    }
}

=head2 function set_location()

 Usage:        $trial->set_location($location_id);
 Desc:
 Ret:          nothing
 Args:
 Side Effects: database access
 Example:

=cut

sub set_location {
    my $self = shift;
    my $location_id = shift;
		my $project_id = $self->get_trial_id();
		my $type_id = $self->get_location_type_id();

    my $row = $self->bcs_schema()->resultset('Project::Projectprop')->find({
	    project_id => $project_id,
	    type_id => $type_id,
		});

		if ($row) {
			$row->value($location_id);
			$row->update();
		}
		else {
			$row = $self->bcs_schema()->resultset('Project::Projectprop')->create({
				project_id => $project_id,
				type_id => $type_id,
				value => $location_id,
			});
		}
}

# CLASS METHOD!

=head2 class method get_all_locations()

 Usage:        my $locations = CXGN::Trial::get_all_locations($schema)
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_all_locations {
    my $schema = shift;
    my @locations;

    my $loc = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { }, {order_by => { -asc => 'nd_geolocation_id' }} );
    while (my $s = $loc->next()) {
        my $loc_props = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search( { nd_geolocation_id => $s->nd_geolocation_id() }, {join=>'type', '+select'=>['me.value', 'type.name'], '+as'=>['value', 'cvterm_name'] } );
        my @attributes;

        my %attr = ('geodetic datum' => $s->geodetic_datum() );
        push @attributes, \%attr;

        my $country = '';
        my $country_code = '';

        while (my $sp = $loc_props->next()) {
            if ($sp->get_column('cvterm_name') eq 'Country') {
                $country = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'Country Code') {
                $country_code = $sp->get_column('value');
            } else {
                my %attr = ( $sp->get_column('cvterm_name') => $sp->get_column('value') );
                push @attributes, \%attr;
            }
        }

        push @locations, [$s->nd_geolocation_id(), $s->description(), $s->latitude(), $s->longitude(), $s->altitude(), $country, $country_code, \@attributes],
    }

    return \@locations;
}


=head2 function get_breeding_programs()

 Usage:
 Desc:         return associated breeding program info
 Ret:          returns a listref to [ id, name, desc ] listrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_breeding_programs {
    my $self = shift;

    my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search( { 'subject_project_id' => $self->get_trial_id() } );

    my $trial_row = $trial_rs -> first();
    my $rs;
    my @projects;

    if ($trial_row) {
	$rs = $self->bcs_schema->resultset('Project::Project')->search( { 'me.project_id' => $trial_row->object_project_id(), 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );

	while (my $row = $rs->next()) {
	    push @projects, [ $row->project_id, $row->name, $row->description ];
	}
    }
    return  \@projects;
}

=head2 function get_project_type()

 Usage:        [ $project_type_cvterm_id, $project_type_name ] = $t -> get_project_type();
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_project_type {
    my $self = shift;

    my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());

    my @ids = map { $_->[0] } @project_type_ids;
    my $rs = $self->bcs_schema()->resultset('Project::Projectprop')->search(
	{
	    type_id => { -in => [ @ids ] },
	    project_id => $self->get_trial_id()
	});

    if ($rs->count() > 0) {
	my $type_id = $rs->first()->type_id();
	foreach my $pt (@project_type_ids) {
	    if ($type_id == $pt->[0]) {
		#print STDERR "[get_project_type] ".$pt->[0]." ".$pt->[1]."\n";
		return $pt;
	    }
	}
    }
    return undef;

}

=head2 function set_project_type()

 Usage: $t -> set_project_type($type);
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_project_type {
    my $self = shift;
    my $type_id = shift;
		my $project_id = $self->get_trial_id();
		my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());
		my $type;

		foreach my $pt (@project_type_ids) {
			if ($pt->[0] eq $type_id) {
				$type = $pt->[1];
			}
    }

		my @ids = map { $_->[0] } @project_type_ids;
    my $rs = $self->bcs_schema()->resultset('Project::Projectprop')->search({
			type_id => { -in => [ @ids ] },
			project_id => $project_id
		});
    if (my $row = $rs->next()) {
			$row->delete();
    }

		my $row = $self->bcs_schema()->resultset('Project::Projectprop')->create({
				project_id => $project_id,
				type_id => $type_id,
				value => $type,
		});
}


sub set_design_type { 
    my $self = shift;
    my $design_type = shift;
    
    my $design_cv_type = $self->bcs_schema->resultset('Cv::Cvterm')->find( { name => 'design' });
    if (!$design_cv_type) { 
	print STDERR "Design CV term not found. Cannot set design type.\n";
	return;
    }
    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find_or_create( 
	{ 
	    project_id => $self->get_trial_id(), 
	    type_id => $design_cv_type->cvterm_id(),
	});
    $row->value($design_type);
    $row->update();
}

=head2 accessors get_breeding_program(), set_breeding_program()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_breeding_program { 

    my $self = shift;

    my $rs = $self->bcs_schema()->resultset("Project::ProjectRelationship")->search({
			subject_project_id => $self->get_trial_id(),
	    type_id => $self->get_breeding_program_trial_relationship_cvterm_id(),
		});
    if ($rs->count() == 0) {
			return undef;
    }

    my $bp_rs = $self->bcs_schema()->resultset("Project::Project")->search({
			project_id => $rs->first()->object_project_id()
		});
    if ($bp_rs->count > 0) {
			return $bp_rs->first()->name();
    }

    return undef;
}

sub set_breeding_program {
	my $self = shift;
	my $breeding_program_id = shift;
	my $trial_id = $self->get_trial_id();
	my $type_id = $self->get_breeding_program_trial_relationship_cvterm_id();

	eval {
		my $row = $self->bcs_schema->resultset("Project::ProjectRelationship")->find ({
			subject_project_id => $trial_id,
			type_id => $type_id,
		});

		if ($row) {
			$row->object_project_id($breeding_program_id);
			$row->update();
		}
		else {
			$row = $self->bcs_schema->resultset("Project::ProjectRelationship")->create ({
				object_project_id => $breeding_program_id,
				subject_project_id => $trial_id,
				type_id => $type_id,
			});
			$row->insert();
		}
	};

	if ($@) {
		print STDERR "ERROR: $@\n";
		return { error => "An error occurred while setting the trial's breeding program." };
	}
	return {};
}

# CLASS METHOD!

=head2 class method get_all_project_types()

 Usage:        my @cvterm_ids = CXGN::Trial::get_all_project_types($schema)
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_all_project_types {
    ##my $class = shift;
    my $schema = shift;
    my $project_type_cv_id = $schema->resultset('Cv::Cv')->find( { name => 'project_type' } )->cv_id();
    my $rs = $schema->resultset('Cv::Cvterm')->search( { cv_id=> $project_type_cv_id });
    my @cvterm_ids;
    if ($rs->count() > 0) {
	@cvterm_ids = map { [ $_->cvterm_id(), $_->name() ] } ($rs->all());
    }
    return @cvterm_ids;
}

=head2 accessors get_name(), set_name()

 Usage:
 Desc:         retrieve and store project name from/to database
 Ret:
 Args:
 Side Effects: setter modifies the database
 Example:

=cut

sub get_name {
    my $self = shift;
    my $row = $self->bcs_schema->resultset('Project::Project')->find( { project_id => $self->get_trial_id() });

    if ($row) {
	return $row->name();
    }
}

sub set_name {
    my $self = shift;
    my $name = shift;
    my $row = $self->bcs_schema->resultset('Project::Project')->find( { project_id => $self->get_trial_id() });
    if ($row) {
	$row->name($name);
	$row->update();
    }
}

=head2 accessors get_harvest_date(), set_harvest_date()

 Usage:         $t->set_harvest_date("2016/09/17");
 Desc:          sets the projects harvest_date property.
                The date format in the setter has to be
                YYYY/MM/DD
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_harvest_date { 
    my $self = shift;

    my $harvest_date_cvterm_id = $self->get_harvest_date_cvterm_id();
    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find(
	{
	    project_id => $self->get_trial_id(),
	    type_id => $harvest_date_cvterm_id,
	});

    my $calendar_funcs = CXGN::Calendar->new({});

    if ($row) {
        my $harvest_date = $calendar_funcs->display_start_date($row->value());
        return $harvest_date;
    } else {
        return;
    }
}

sub set_harvest_date {
    my $self = shift;
    my $harvest_date = shift;

    my $calendar_funcs = CXGN::Calendar->new({});

    if (my $harvest_event = $calendar_funcs->check_value_format($harvest_date) ) {

        my $harvest_date_cvterm_id = $self->get_harvest_date_cvterm_id();

        my $row = $self->bcs_schema->resultset('Project::Projectprop')->find_or_create(
        {
            project_id => $self->get_trial_id(),
            type_id => $harvest_date_cvterm_id,
        });

        $row->value($harvest_event);
        $row->update();
    } else {
			print STDERR "date format did not pass check while preparing to set harvest date: $harvest_date  \n";
		}
}

sub remove_harvest_date {
    my $self = shift;
		my $harvest_date = shift;

		my $calendar_funcs = CXGN::Calendar->new({});
    if (my $harvest_event = $calendar_funcs->check_value_format($harvest_date) ) {

			my $harvest_date_cvterm_id = $self->get_harvest_date_cvterm_id();

			my $row = $self->bcs_schema->resultset('Project::Projectprop')->find_or_create(
				{
					project_id => $self->get_trial_id(),
					type_id => $harvest_date_cvterm_id,
					value => $harvest_event,
				});

    	if ($row) {
				print STDERR "Removing harvest date $harvest_event from trial ".$self->get_trial_id()."\n";
				$row->delete();
    	}
		} else {
			print STDERR "date format did not pass check while preparing to delete harvest date: $harvest_date  \n";
		}
}


=head2 accessors get_planting_date(), set_planting_date()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_planting_date { 
    my $self = shift;

    my $planting_date_cvterm_id = $self->get_planting_date_cvterm_id();
    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find(
	{
	    project_id => $self->get_trial_id(),
	    type_id => $planting_date_cvterm_id,
	});

    my $calendar_funcs = CXGN::Calendar->new({});

    if ($row) {
        my $harvest_date = $calendar_funcs->display_start_date($row->value());
        return $harvest_date;
    } else {
        return;
    }
}

sub set_planting_date {
    my $self = shift;
    my $planting_date = shift;

    my $calendar_funcs = CXGN::Calendar->new({});

    if (my $planting_event = $calendar_funcs->check_value_format($planting_date) ) {

	    my $planting_date_cvterm_id = $self->get_planting_date_cvterm_id();

	    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find_or_create(
		{
		    project_id => $self->get_trial_id(),
		    type_id => $planting_date_cvterm_id,
		});

	    $row->value($planting_event);
	    $row->update();
    } else {
			print STDERR "date format did not pass check while preparing to set planting date: $planting_date \n";
		}
}

sub remove_planting_date {
    my $self = shift;
		my $planting_date = shift;

		my $calendar_funcs = CXGN::Calendar->new({});
    if (my $planting_event = $calendar_funcs->check_value_format($planting_date) ) {

			my $planting_date_cvterm_id = $self->get_planting_date_cvterm_id();

			my $row = $self->bcs_schema->resultset('Project::Projectprop')->find_or_create(
				{
					project_id => $self->get_trial_id(),
					type_id => $planting_date_cvterm_id,
					value => $planting_event,
				});

    	if ($row) {
				print STDERR "Removing planting date $planting_event from trial ".$self->get_trial_id()."\n";
				$row->delete();
    	}
		} else {
			print STDERR "date format did not pass check while preparing to delete planting date: $planting_date  \n";
		}
}


=head2 function delete_phenotype_data()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

# note: you may need to delete the metadata before deleting the phenotype data (see function).
# this function has a test!
#
sub delete_phenotype_data {
    my $self = shift;

    my $trial_id = $self->get_trial_id();

    eval {
	$self->bcs_schema->txn_do(
	    sub {
		#print STDERR "\n\nDELETING PHENOTYPES...\n\n";

		# delete phenotype data associated with trial
		#
		#my $trial = $self->bcs_schema()->resultset("Project::Project")->search( { project_id => $trial_id });

		my $q = "SELECT nd_experiment_id FROM nd_experiment_project JOIN nd_experiment_phenotype USING(nd_experiment_id) WHERE project_id =?";

		my $h = $self->bcs_schema()->storage()->dbh()->prepare($q);

		$h->execute($trial_id);
		my @nd_experiment_ids = ();
		while (my ($id) = $h->fetchrow_array()) {
		    push @nd_experiment_ids, $id;
		}
		print STDERR "GOING TO REMOVE ".scalar(@nd_experiment_ids)." EXPERIMENTS...\n";
		$self->_delete_phenotype_experiments(@nd_experiment_ids);
	    });
    };



    if ($@) {
	print STDERR "ERROR DELETING PHENOTYPE DATA $@\n";
	return "Error deleting phenotype data for trial $trial_id. $@\n";
    }
    return '';

}


=head2 function delete_field_layout()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut


# this function has a test!
#
sub delete_field_layout {
    my $self = shift;

    my $trial_id = $self->get_trial_id();

    # Note: metadata entries need to be deleted separately using delete_metadata()
    #
    my $error = '';
    eval {
	$self->bcs_schema()->txn_do(
	    sub {
		#print STDERR "DELETING FIELD LAYOUT FOR TRIAL $trial_id...\n";

		my $trial = $self->bcs_schema()->resultset("Project::Project")->search( { project_id => $trial_id });

		my $nd_experiment_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProject")->search( { project_id => $trial_id });
		my @nd_experiment_ids = map { $_->nd_experiment_id } $nd_experiment_rs->all();

		$self->_delete_field_layout_experiment();
	    }
	    );
    };
    if ($@) {
	print STDERR "ERROR $@\n";
	return "An error occurred: $@\n";
    }

    return '';
}

=head2 function delete_phenotype_metadata()

 Usage:        $trial->delete_metadata($metadata_schema, $phenome_schema);
 Desc:         obsoletes the metadata entries for this trial.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_phenotype_metadata {
    my $self = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;

    if (!$metadata_schema || !$phenome_schema) { die "Need metadata schema parameter\n"; }

    my $trial_id = $self->get_trial_id();

    #print STDERR "Deleting metadata for trial $trial_id...\n";

    # first, deal with entries in the md_metadata table, which may reference nd_experiment (through linking table)
    #
    my $q = "SELECT distinct(metadata_id) FROM nd_experiment_project JOIN nd_experiment_phenotype USING(nd_experiment_id) LEFT JOIN phenome.nd_experiment_md_files ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_md_files.nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
    my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($trial_id);

    while (my ($md_id) = $h->fetchrow_array()) {
	#print STDERR "Associated metadata id: $md_id\n";
	my $mdmd_row = $metadata_schema->resultset("MdMetadata")->find( { metadata_id => $md_id } );
	if ($mdmd_row) {
	    #print STDERR "Obsoleting $md_id...\n";

	    $mdmd_row -> update( { obsolete => 1 });
	}
    }

    #print STDERR "Deleting the entries in the linking table...\n";

    # delete the entries from the linking table...
    $q = "SELECT distinct(file_id) FROM nd_experiment_project JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenome.nd_experiment_md_files ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_md_files.nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
    $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($trial_id);

    while (my ($file_id) = $h->fetchrow_array()) {
	print STDERR "trying to delete association for file with id $file_id...\n";
	my $ndemdf_rs = $phenome_schema->resultset("NdExperimentMdFiles")->search( { file_id=>$file_id });
	print STDERR "Deleting md_files linking table entries...\n";
	foreach my $row ($ndemdf_rs->all()) {
	    print STDERR "DELETING !!!!\n";
	    $row->delete();
	}
    }
}



=head2 function delete_metadata()

 Usage:        $trial->delete_metadata($metadata_schema, $phenome_schema);
 Desc:         obsoletes the metadata entries for this trial.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_metadata {
    my $self = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;

    if (!$metadata_schema || !$phenome_schema) { die "Need metadata schema parameter\n"; }

    my $trial_id = $self->get_trial_id();

    #print STDERR "Deleting metadata for trial $trial_id...\n";

    # first, deal with entries in the md_metadata table, which may reference nd_experiment (through linking table)
    #
    my $q = "SELECT distinct(metadata_id) FROM nd_experiment_project JOIN phenome.nd_experiment_md_files using(nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
    my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($trial_id);

    while (my ($md_id) = $h->fetchrow_array()) {
	#print STDERR "Associated metadata id: $md_id\n";
	my $mdmd_row = $metadata_schema->resultset("MdMetadata")->find( { metadata_id => $md_id } );
	if ($mdmd_row) {
	    #print STDERR "Obsoleting $md_id...\n";

	    $mdmd_row -> update( { obsolete => 1 });
	}
    }

    #print STDERR "Deleting the entries in the linking table...\n";

    # delete the entries from the linking table... (left joins are due to sometimes missing md_file entries)
    $q = "SELECT distinct(file_id) FROM nd_experiment_project LEFT JOIN phenome.nd_experiment_md_files using(nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
    $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($trial_id);

    while (my ($file_id) = $h->fetchrow_array()) {
	print STDERR "trying to delete association for file with id $file_id...\n";
	my $ndemdf_rs = $phenome_schema->resultset("NdExperimentMdFiles")->search( { file_id=>$file_id });
	print STDERR "Deleting md_files linking table entries...\n";
	foreach my $row ($ndemdf_rs->all()) {
	    print STDERR "DELETING !!!!\n";
	    $row->delete();
	}
    }
}


sub _delete_phenotype_experiments {
    my $self = shift;
    my @nd_experiment_ids = @_;

    # retrieve the associated phenotype ids (they won't be deleted by the cascade)
    #
    my $phenotypes_deleted = 0;
    my $nd_experiments_deleted = 0;

    foreach my $nde_id (@nd_experiment_ids) {
	my $nd_exp_phenotype_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentPhenotype")->search( { nd_experiment_id => $nde_id }, { join => 'phenotype' });
	if ($nd_exp_phenotype_rs->count() > 0) {
	    print STDERR "Deleting experiments ... \n";
	    while (my $pep = $nd_exp_phenotype_rs->next()) {
		my $phenotype_rs = $self->bcs_schema()->resultset("Phenotype::Phenotype")->search( { phenotype_id => $pep->phenotype_id() } );
		print STDERR "DELETING ".$phenotype_rs->count(). " phenotypes\n";
		$phenotype_rs->delete_all();
		$phenotypes_deleted++;
	    }
	}
	print STDERR "Deleting linking table entries...\n";
	$nd_exp_phenotype_rs->delete_all();
    }


    # delete the experiments
    #
    #print STDERR "Deleting experiments...\n";
    foreach my $nde_id (@nd_experiment_ids) {
	my $delete_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->search({ nd_experiment_id => $nde_id });

	$nd_experiments_deleted++;

	$delete_rs->delete_all();
    }
    return { phenotypes_deleted => $phenotypes_deleted,
	     nd_experiments_deleted => $nd_experiments_deleted
    };
}

sub _delete_field_layout_experiment {
    my $self = shift;

    my $trial_id = $self->get_trial_id();

    print STDERR "_delete_field_layout_experiment...\n";

    # check if there are still associated phenotypes...
    #
    if ($self->phenotype_count() > 0) {
	print STDERR "Attempt to delete field layout that still has associated phenotype data.\n";
	die "cannot delete because of associated phenotypes\n";
	return { error => "Trial still has associated phenotyping experiment, cannot delete." };
    }

    my $field_layout_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => "field_layout" })->cvterm_id();

    my $genotyping_layout_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'genotyping_layout' }) ->cvterm_id();

    print STDERR "Genotyping layout type id = $field_layout_type_id\n";

    my $plot_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'plot' })->cvterm_id();
    #print STDERR "Plot type id = $plot_type_id\n";
    my $genotype_plot = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'tissue_sample' });

    my $genotype_plot_id;
    if ($genotype_plot) {
	$genotype_plot_id = $genotype_plot->cvterm_id();
    }

    print STDERR "Genotype plot id = $genotype_plot_id\n";

    my $q = "SELECT stock_id FROM nd_experiment_project JOIN nd_experiment USING (nd_experiment_id) JOIN nd_experiment_stock ON (nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id) JOIN stock USING(stock_id) WHERE nd_experiment.type_id in (?, ?) AND project_id=? AND stock.type_id IN (?, ?)";
    my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($field_layout_type_id, $genotyping_layout_type_id, $trial_id, $plot_type_id, $genotype_plot_id);

	my $has_plants = $self->has_plant_entries();
	my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plant_of', 'stock_relationship')->cvterm_id();
	my $plots_deleted = 0;
	while (my ($plot_id) = $h->fetchrow_array()) {
		my $plot = $self->bcs_schema()->resultset("Stock::Stock")->find( { stock_id => $plot_id });

		if ($has_plants) {
			my $plant_rs = $plot->search_related('stock_relationship_subjects', {type_id=>$plot_of_cvterm_id});
			while (my $plant_rel = $plant_rs->next()) {
				my $plant = $plant_rel->object();
				print STDERR "Deleting associated plant ".$plant->name(). " (".$plant->stock_id().") \n";
				$plant->delete();
				$plant_rel->delete();
			}
		}

		print STDERR "Deleting associated plot ".$plot->name()." (".$plot->stock_id().") \n";

		$plots_deleted++;
		$plot->delete();
	}
	if ($has_plants) {
		my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project_has_plant_entries', 'project_property' );
		my $has_plants_prop = $self->bcs_schema->resultset("Project::Projectprop")->find({ type_id => $has_plants_cvterm->cvterm_id(), project_id => $trial_id });
		$has_plants_prop->delete();
	}

    $q = "SELECT nd_experiment_id FROM nd_experiment JOIN nd_experiment_project USING(nd_experiment_id) WHERE nd_experiment.type_id in (?,?) AND project_id=?";
    $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($field_layout_type_id, $genotyping_layout_type_id, $trial_id);

    my ($nd_experiment_id) = $h->fetchrow_array();
    if ($nd_experiment_id) {
	#print STDERR "Delete corresponding nd_experiment entry  ($nd_experiment_id)...\n";
	my $nde = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->find( { nd_experiment_id => $nd_experiment_id });
	$nde->delete();
    }


    #return { success => $plots_deleted };
    return { success => 1 };
}

=head2 function delete_project_entry()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_project_entry {
    my $self = shift;

    if ($self->phenotype_count() > 0) {
	print STDERR "Cannot delete trial with associated phenotypes.\n";
	return;
    }
    if (my $count = $self->get_experiment_count() > 0) {
	print STDERR "Cannot delete trial with associated experiments ($count)\n";
	return "Cannot delete entry because of associated experiments";
    }

    eval {
	my $row = $self->bcs_schema->resultset("Project::Project")->find( { project_id=> $self->get_trial_id() });
	$row->delete();
    };
    if ($@) {
	print STDERR "An error occurred during deletion: $@\n";
	return $@;
    }
}

=head2 function phenotype_count()

 Usage:
 Desc:         The number of phenotype measurements associated with this trial
 Ret:
 Args:
 Side Effects:
 Example:

=cut


sub phenotype_count {
    my $self = shift;

    my $phenotyping_experiment_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'phenotyping_experiment' })->cvterm_id();

    my $phenotype_experiment_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProject")->search(
    	{
    	    project_id => $self->get_trial_id(), 'nd_experiment.type_id' => $phenotyping_experiment_type_id},
    	{
    	    join => 'nd_experiment'
    	}
    	);

     return $phenotype_experiment_rs->count();
}


=head2 function total_phenotypes()

 Usage:
 Desc:         returns the total number of phenotype measurements
               associated with the trial
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub total_phenotypes {
    my $self = shift;

    my $pt_rs = $self->bcs_schema()->resultset("Phenotype::Phenotype")->search( { });
    return $pt_rs->count();
}

=head2 function get_phenotypes_for_trait($trait_id)

 Usage:
 Desc:         returns the measurements for the given trait in this trial as an array of values, e.g. [2.1, 2, 50]
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_phenotypes_for_trait {
    my $self = shift;
    my $trait_id = shift;
    my @data;
    my $dbh = $self->bcs_schema->storage()->dbh();

    my $h = $dbh->prepare("SELECT phenotype.value::real FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? and cvterm.cvterm_id = ? and phenotype.value~?;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($self->get_trial_id(), $trait_id, $numeric_regex );
    while (my ($value) = $h->fetchrow_array()) {
	   push @data, $value + 0;
    }
    return @data;
}

=head2 function get_plot_phenotypes_for_trait($trait_id)

 Usage:
 Desc:         returns all plot_id, plot_name, pheno_uniquename, uploader_id, value for the given trait in this trial
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_plot_phenotypes_for_trait {
    my $self = shift;
    my $trait_id = shift;
    my @data;
    my $dbh = $self->bcs_schema->storage()->dbh();

    my $phenotyping_experiment_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

    my $h = $dbh->prepare("SELECT stock.stock_id, stock.uniquename, phenotype.uniquename, phenotype.sp_person_id, phenotype.value::real FROM cvterm as a JOIN phenotype ON (a.cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN cvterm as b ON (b.cvterm_id=nd_experiment_stock.type_id) JOIN stock USING(stock_id) WHERE project_id=? and a.cvterm_id = ? and b.cvterm_id = ? and phenotype.value~? ORDER BY stock.stock_id;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($self->get_trial_id(), $trait_id, $phenotyping_experiment_cvterm, $numeric_regex );
    while (my ($plot_id, $plot_name, $pheno_uniquename, $uploader_id, $value) = $h->fetchrow_array()) {
        push @data, [$plot_id, $plot_name, $pheno_uniquename, $uploader_id, $value + 0];
    }
    return \@data;
}

=head2 function get_traits_assayed()

 Usage:
 Desc:         returns the cvterm_id and name for traits assayed
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_traits_assayed {
    my $self = shift;
    my $dbh = $self->bcs_schema->storage()->dbh();

    my @traits_assayed;
    my $traits_assayed_q = $dbh->prepare("SELECT cvterm.name, cvterm.cvterm_id, count(phenotype.value) FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? and phenotype.value~? GROUP BY cvterm.name, cvterm.cvterm_id ORDER BY cvterm.name;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $traits_assayed_q->execute($self->get_trial_id(), $numeric_regex );
    while (my ($trait_name, $trait_id, $count) = $traits_assayed_q->fetchrow_array()) {
	push @traits_assayed, [$trait_id, ucfirst($trait_name)];
    }
    return \@traits_assayed;
}

=head2 function get_experiment_count()

 Usage:
 Desc:         return the total number of experiments associated
               with the trial.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_experiment_count {
    my $self = shift;

    my $rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search( { project_id => $self->get_trial_id() });
    return $rs->count();
}

sub get_location_type_id {
    my $self = shift;
    my $rs = $self->bcs_schema->resultset('Cv::Cvterm')->search( { name => 'project location' });

    if ($rs->count() > 0) {
	return $rs->first()->cvterm_id();
    }

}

sub get_year_type_id {
    my $self = shift;

    my $rs = $self->bcs_schema->resultset('Cv::Cvterm')->search( { name => 'project year' });

    return $rs->first()->cvterm_id();
}

sub get_breeding_program_trial_relationship_cvterm_id {
    my $self = shift;

    my $breeding_program_trial_relationship_cvterm_id;
    my $breeding_program_trial_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'breeding_program_trial_relationship', 'project_relationship');
    if ($breeding_program_trial_relationship_cvterm) {
        $breeding_program_trial_relationship_cvterm_id = $breeding_program_trial_relationship_cvterm->cvterm_id();
    }

    return $breeding_program_trial_relationship_cvterm_id;
}

sub get_breeding_program_cvterm_id {
    my $self = shift;

    my $breeding_program_cvterm_id;
    my $breeding_program_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'breeding_program', 'project_property');
    if ($breeding_program_cvterm) {
        $breeding_program_cvterm_id = $breeding_program_cvterm->cvterm_id();
    }

    return $breeding_program_cvterm_id;
}

sub get_folder {
    my $self = shift;

    my $f = CXGN::Trial::Folder->new( { bcs_schema => $self->bcs_schema(), folder_id => $self->get_trial_id() });

    my $parent_folder_data = $f->project_parent();

    if ($parent_folder_data) {
	return $parent_folder_data;
    }
    else {
	return;
    }
}

sub get_harvest_date_cvterm_id {
    my $self = shift;

    my $harvest_date_cvterm_id;
    my $harvest_date_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'harvest_date', 'project_property');
    if ($harvest_date_cvterm) {
        $harvest_date_cvterm_id = $harvest_date_cvterm->cvterm_id();
    }

    return $harvest_date_cvterm_id;
}


=head2 function create_plant_entries()

 Usage:        $trial->create_plant_entries($plants_per_plot);
 Desc:         Some trials require plant-level data. This function will
               add an additional layer of plant entries for each plot.
 Ret:          
 Args:         the number of plants per plot to add.
 Side Effects:
 Example:

=cut

sub create_plant_entities { 
	my $self = shift;
	my $plants_per_plot = shift || 30;

	my $create_plant_entities_txn = sub {
		my $chado_schema = $self->bcs_schema();
		my $layout = CXGN::Trial::TrialLayout->new( { schema => $chado_schema, trial_id => $self->get_trial_id() });
		my $design = $layout->get_design();

		my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
		my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
		my $plant_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship')->cvterm_id();
		my $plant_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_index_number', 'stock_property')->cvterm_id();
		my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property')->cvterm_id();

		my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
			type_id => $has_plants_cvterm,
			value => $plants_per_plot,
			project_id => $self->get_trial_id(),
		});

		my $field_layout_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id;

		foreach my $plot (keys %$design) {
			print STDERR " ... creating plants for plot $plot...\n";
			my $plot_row = $chado_schema->resultset("Stock::Stock")->find( { uniquename => $design->{$plot}->{plot_name}, type_id=>$plot_cvterm });

			if (! $plot_row) {
				print STDERR "The plot $plot is not found in the database\n";
				return "The plot $plot is not yet in the database. Cannot create plant entries.";
			}

			my $parent_plot = $plot_row->stock_id();
			my $parent_plot_name = $plot_row->uniquename();
			my $parent_plot_organism = $plot_row->organism_id();

			foreach my $number (1..$plants_per_plot) {
				my $plant_name = $parent_plot_name."_plant_$number";
				#print STDERR "... ... creating plant $plant_name...\n";

				my $plant = $chado_schema->resultset("Stock::Stock")->find_or_create({
					organism_id => $parent_plot_organism,
					name       => $plant_name,
					uniquename => $plant_name,
					type_id => $plant_cvterm,
				});

				my $plantprop = $chado_schema->resultset("Stock::Stockprop")->find_or_create( {
					stock_id => $plant->stock_id(),
					type_id => $plant_index_number_cvterm,
					value => $number,
				});

				my $stock_relationship = $self->bcs_schema()->resultset("Stock::StockRelationship")->create({
					subject_id => $parent_plot,
					object_id => $plant->stock_id(),
					type_id => $plant_relationship_cvterm,
				});
			}
		}
	};

     eval { 
	 $self->bcs_schema()->txn_do($create_plant_entities_txn);
     };
     if ($@) { 
	 print STDERR "An error occurred creating the plant entities. $@\n";
	 return 0;
     }

     print STDERR "Plant entities created.\n";
     return 1;

 }
 
=head2 function has_plant_entries()

	Usage:        $trial->has_plant_entries();
	Desc:         Some trials require plant-level data. This function will determine if a trial has plants associated with it.
	Ret:          Returns 1 if trial has plants, 0 if the trial does not.
	Args:
	Side Effects:
	Example:

=cut

sub has_plant_entries { 
	my $self = shift;
	my $chado_schema = $self->bcs_schema();
	my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property' );
	
	my $rs = $chado_schema->resultset("Project::Projectprop")->find({ 
		type_id => $has_plants_cvterm->cvterm_id(),
		project_id => $self->get_trial_id(),
	});
	
	if ($rs) {
		return 1;
	} else {
		return 0;
	}
	
}

 sub get_planting_date_cvterm_id {
     my $self = shift;
     my $planting_date =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'planting_date', 'project_property');

     return $planting_date->cvterm_id();

 }

=head2 accessors set_design_type(), get_design_type()

  Usage:        $trial->set_design_type("RCBD");
  Desc:
  Ret:
  Args:
  Side Effects:
  Example:

=cut

sub get_design_type {
     my $self = shift;
     my $design_prop;
     my $design_type;

     my $project = $self->bcs_schema->resultset("Project::Project")->find( { project_id => $self->get_trial_id() });

     $design_prop =  $project->projectprops->find(
	 { 'type.name' => 'design' },
	 { join => 'type'}
	 ); #there should be only one design prop.
     if (!$design_prop) {
	 return;
     }
     $design_type = $design_prop->value;
     if (!$design_type) {
	 return;
     }
     return $design_type;
}



sub duplicate { 
}

sub get_accessions {
	my $self = shift;
	my @accessions;

	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type' )->cvterm_id();
	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "genotyping_layout", "experiment_type")->cvterm_id();
	my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plot_of", "stock_relationship")->cvterm_id();
	my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "tissue_sample_of", "stock_relationship")->cvterm_id();

	my $trial_accession_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), "project.type_id" => [$field_trial_cvterm_id, $genotyping_trial_cvterm_id] })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock")->search_related("stock_relationship_subjects", { 'stock_relationship_subjects.type_id' => [$plot_of_cvterm_id, $tissue_sample_of_cvterm_id] } );

	my %unique_accessions;
	while(my $rs = $trial_accession_rs->next()) {
		my $r = $rs->object;
		if ($r->type_id == $accession_cvterm_id) {
			$unique_accessions{$r->uniquename} = $r->stock_id;
		}
	}
	foreach (keys %unique_accessions) {
		push @accessions, {accession_name=>$_, stock_id=>$unique_accessions{$_} };
	}

	return \@accessions;
}

sub get_plants {
	my $self = shift;
	my @plants;

	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "genotyping_layout", "experiment_type")->cvterm_id();
	my $plant_rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plant_of', 'stock_relationship' )->cvterm_id();
	my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plant', 'stock_type' )->cvterm_id();
	my $trial_plant_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), "project.type_id" => [$field_trial_cvterm_id, $genotyping_trial_cvterm_id] })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock")->search_related("stock_relationship_subjects", { 'stock_relationship_subjects.type_id' => $plant_rel_cvterm_id } );

	my %unique_plants;
	while(my $rs = $trial_plant_rs->next()) {
		my $r = $rs->object;
		#print STDERR $r->uniquename."\n";
		if ($r->type_id == $plant_cvterm_id) {
			$unique_plants{$r->uniquename} = $r->stock_id;
		}
	}
	foreach (keys %unique_plants) {
		push @plants, {plant_name=>$_, stock_id=>$unique_plants{$_} };
	}

	return \@plants;
}

sub get_plots {
	my $self = shift;
	my @plots;

	my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot', 'stock_type' )->cvterm_id();
	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "genotyping_layout", "experiment_type")->cvterm_id();

	my $trial_plot_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), "project.type_id" => [$field_trial_cvterm_id, $genotyping_trial_cvterm_id] })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock", {'stock.type_id'=>$plot_cvterm_id});

	my %unique_plots;
	while(my $rs = $trial_plot_rs->next()) {
		$unique_plots{$rs->uniquename} = $rs->stock_id;
	}
	foreach (keys %unique_plots) {
		#push @plots, {plot_name=> $_, plot_id=>$unique_plots{$_} } ; 
		my $combine = [$unique_plots{$_}, $_ ];
		push @plots, $combine;
	}
	
	return \@plots;
	 
}

sub get_controls {
	my $self = shift;
	my @controls;

	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type' )->cvterm_id();
	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "genotyping_layout", "experiment_type")->cvterm_id();
	my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plot_of", "stock_relationship")->cvterm_id();
	my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "tissue_sample_of", "stock_relationship")->cvterm_id();

	my $trial_plot_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), "project.type_id" => [$field_trial_cvterm_id, $genotyping_trial_cvterm_id] })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks");

	my %unique_controls;
	while(my $rs = $trial_plot_rs->next()) {
		my $r = $rs->stock()->stockprops->find( { 'type.name' => 'is a control' }, { join => 'type'} );

		my $is_a_control;
		if ($r) {
			$is_a_control = $r->value();
		}
		if ($is_a_control) {
			my $accession = $rs->search_related("stock")->search_related('stock_relationship_subjects')->find({ 'type_id' => [$plot_of_cvterm_id, $tissue_sample_of_cvterm_id ]})->object;
			if ($accession->type_id == $accession_cvterm_id) {
				$unique_controls{$accession->uniquename}=$accession->stock_id;
			}
		}
	}
	foreach (keys %unique_controls) {
		push @controls, {accession_name=> $_, stock_id=>$unique_controls{$_} } ;
	}

	return \@controls;
}

1;


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
use JSON;
use File::Basename qw | basename dirname|;

=head2 accessor bcs_schema()

accessor for bcs_schema. Needs to be set when calling the constructor.

=cut

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
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
    my $layout = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $self->get_trial_id(), experiment_type=>'field_layout' });
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


=head2 function get_nd_experiment_id()

 Usage:        my $location = $trial->get_nd_experiment_id();
 Desc:          Every trial should have only a single nd_experiment entry of type 'field_layout'. This returns this nd_experiment_id for the trial.
 Ret:          $nd_experiment_id
 Args:
 Side Effects:
 Example:

=cut

sub get_nd_experiment_id {
    my $self = shift;
    my $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $nd_experiment_rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
        { 'me.type_id' => $nd_experiment_type_id, 'project.project_id' => $self->get_trial_id },
        { 'join' => {'nd_experiment_projects'=>'project'}}
    );
    if ($nd_experiment_rs->count > 1){
        return {error => "A trial cannot have more than one nd_experiment entry of type field_layout. Please contact us."};
    }
    if ($nd_experiment_rs == 1){
        return {success => 1, nd_experiment_id => $nd_experiment_rs->first->nd_experiment_id};
    } else {
        return {error => "This trial does not have an nd_experiment entry of type field_layout. Please contact us."}
    }
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
	my $location_id = shift;
    my @locations;

	my %search_params;
	if ($location_id){
		$search_params{'nd_geolocation_id'} = $location_id;
	}

    my $loc = $schema->resultset('NaturalDiversity::NdGeolocation')->search( \%search_params, {order_by => { -asc => 'nd_geolocation_id' }} );
    while (my $s = $loc->next()) {
        my $loc_props = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search( { nd_geolocation_id => $s->nd_geolocation_id() }, {join=>'type', '+select'=>['me.value', 'type.name'], '+as'=>['value', 'cvterm_name'] } );

		my %attr;
        $attr{'geodetic datum'} = $s->geodetic_datum();

        my $country = '';
        my $country_code = '';
        my $location_type = '';
        my $abbreviation = '';

        while (my $sp = $loc_props->next()) {
            if ($sp->get_column('cvterm_name') eq 'country_name') {
                $country = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'country_code') {
                $country_code = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'location_type') {
                $location_type = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'abbreviation') {
                $abbreviation = $sp->get_column('value');
            } else {
                $attr{$sp->get_column('cvterm_name')} = $sp->get_column('value') ;
            }
        }

        push @locations, [$s->nd_geolocation_id(), $s->description(), $s->latitude(), $s->longitude(), $s->altitude(), $country, $country_code, \%attr, $location_type, $abbreviation],
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

=head2 function set_field_trials_source_field_trials()

 Usage:
 Desc:         sets associated source field trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:         an arrayref [source_trial_id1, source_trial_id2]
 Side Effects:
 Example:

=cut

sub set_field_trials_source_field_trials {
    my $self = shift;
    my $source_field_trial_ids = shift;
    my $schema = $self->bcs_schema;
    my $field_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_from_field_trial', 'project_relationship')->cvterm_id();

    foreach (@$source_field_trial_ids){
        if ($_){
            my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->create({
                'subject_project_id' => $self->get_trial_id(),
                'object_project_id' => $_,
                'type_id' => $field_trial_from_field_trial_cvterm_id
            });
        }
    }
    my $projects = $self->get_field_trials_source_field_trials();
    return $projects;
}

=head2 function get_field_trials_source_field_trials()

 Usage:
 Desc:         return associated source field trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_source_field_trials {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $field_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.subject_project_id' => $self->get_trial_id(),
        'me.type_id' => $field_trial_from_field_trial_cvterm_id
    }, {
        join => 'object_project', '+select' => ['object_project.name'], '+as' => ['source_trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->object_project_id, $r->get_column('source_trial_name') ];
    }
    return  \@projects;
}

=head2 function get_field_trials_sourced_from_field_trials()

 Usage:
 Desc:         return associated source field trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_sourced_from_field_trials {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $field_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.object_project_id' => $self->get_trial_id(),
        'me.type_id' => $field_trial_from_field_trial_cvterm_id
    }, {
        join => 'subject_project', '+select' => ['subject_project.name'], '+as' => ['trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->subject_project_id, $r->get_column('trial_name') ];
    }
    return  \@projects;
}

=head2 function set_genotyping_trials_from_field_trial()

 Usage:
 Desc:         sets associated genotyping trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:         an arrayref [genotyping_trial_id1, genotyping_trial_id2]
 Side Effects:
 Example:

=cut

sub set_genotyping_trials_from_field_trial {
    my $self = shift;
    my $source_field_trial_ids = shift;
    my $schema = $self->bcs_schema;
    my $genotyping_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_trial_from_field_trial', 'project_relationship')->cvterm_id();

    foreach (@$source_field_trial_ids){
        if ($_){
            my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->create({
                'subject_project_id' => $self->get_trial_id(),
                'object_project_id' => $_,
                'type_id' => $genotyping_trial_from_field_trial_cvterm_id
            });
        }
    }
    my $projects = $self->get_genotyping_trials_from_field_trial();
    return $projects;
}

=head2 function get_genotyping_trials_from_field_trial()

 Usage:
 Desc:         return associated genotyping trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_genotyping_trials_from_field_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $genotyping_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.subject_project_id' => $self->get_trial_id(),
        'me.type_id' => $genotyping_trial_from_field_trial_cvterm_id
    }, {
        join => 'object_project', '+select' => ['object_project.name'], '+as' => ['source_trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->object_project_id, $r->get_column('source_trial_name') ];
    }
    return  \@projects;
}

=head2 function set_source_field_trials_for_genotyping_trial()

 Usage:
 Desc:         sets associated field trials for the current genotyping trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:         an arrayref [field_trial_id1, field_trial_id2]
 Side Effects:
 Example:

=cut

sub set_source_field_trials_for_genotyping_trial {
    my $self = shift;
    my $source_field_trial_ids = shift;
    my $schema = $self->bcs_schema;
    my $genotyping_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_trial_from_field_trial', 'project_relationship')->cvterm_id();

    foreach (@$source_field_trial_ids){
        if ($_){
            my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->create({
                'object_project_id' => $self->get_trial_id(),
                'subject_project_id' => $_,
                'type_id' => $genotyping_trial_from_field_trial_cvterm_id
            });
        }
    }
    my $projects = $self->get_field_trials_source_of_genotyping_trial();
    return $projects;
}

=head2 function get_field_trials_source_of_genotyping_trial()

 Usage:
 Desc:         return associated field trials for current genotying trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_source_of_genotyping_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $genotyping_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.object_project_id' => $self->get_trial_id(),
        'me.type_id' => $genotyping_trial_from_field_trial_cvterm_id
    }, {
        join => 'subject_project', '+select' => ['subject_project.name'], '+as' => ['source_trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->subject_project_id, $r->get_column('source_trial_name') ];
    }
    return  \@projects;
}


=head2 function set_crossing_trials_from_field_trial()

 Usage:
 Desc:         sets associated crossing trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:         an arrayref [crossing_trial_id1, crossing_trial_id2]
 Side Effects:
 Example:

=cut

sub set_crossing_trials_from_field_trial {
    my $self = shift;
    my $source_field_trial_ids = shift;
    my $schema = $self->bcs_schema;
    my $genotyping_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial_from_field_trial', 'project_relationship')->cvterm_id();

    foreach (@$source_field_trial_ids){
        if ($_){
            my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->create({
                'subject_project_id' => $self->get_trial_id(),
                'object_project_id' => $_,
                'type_id' => $genotyping_trial_from_field_trial_cvterm_id
            });
        }
    }
    my $projects = $self->get_crossing_trials_from_field_trial();
    return $projects;
}

=head2 function get_crossing_trials_from_field_trial()

 Usage:
 Desc:         return associated crossing trials for athe current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_crossing_trials_from_field_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $genotyping_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.subject_project_id' => $self->get_trial_id(),
        'me.type_id' => $genotyping_trial_from_field_trial_cvterm_id
    }, {
        join => 'object_project', '+select' => ['object_project.name'], '+as' => ['source_trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->object_project_id, $r->get_column('source_trial_name') ];
    }
    return  \@projects;
}

=head2 function get_field_trials_source_of_crossing_trial()

 Usage:
 Desc:         return associated crossing trials for athe current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_source_of_crossing_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $genotyping_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.object_project_id' => $self->get_trial_id(),
        'me.type_id' => $genotyping_trial_from_field_trial_cvterm_id
    }, {
        join => 'subject_project', '+select' => ['subject_project.name'], '+as' => ['source_trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->subject_project_id, $r->get_column('source_trial_name') ];
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
    my $rs = $schema->resultset('Cv::Cvterm')->search( { cv_id=> $project_type_cv_id }, {order_by=>'me.cvterm_id'} );
    my @cvterm_ids;
    if ($rs->count() > 0) {
	@cvterm_ids = map { [ $_->cvterm_id(), $_->name(), $_->definition ] } ($rs->all());
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

=head2 accessors get_phenotypes_fully_uploaded(), set_phenotypes_fully_uploaded()

 Usage: When a trial's phenotypes have been fully upload, the user can set a projectprop called 'phenotypes_fully_uploaded' with a value of 1
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_phenotypes_fully_uploaded {
    my $self = shift;
    return $self->_get_projectprop('phenotypes_fully_uploaded');
}

sub set_phenotypes_fully_uploaded {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('phenotypes_fully_uploaded', $value);
}


=head2 accessors get_genotyping_facility(), set_genotyping_facility()

 Usage: For genotyping trials, a genotyping facility can be set as a projectprop value e.g. 'igd'
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_genotyping_facility {
    my $self = shift;
    return $self->_get_projectprop('genotyping_facility');
}

sub set_genotyping_facility {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('genotyping_facility', $value);
}

=head2 accessors get_genotyping_facility_submitted(), set_genotyping_facility_submitted()

 Usage: For genotyping trials, if a genotyping plate has been submitted to genotyping facility and the plate is stored in out system, this stockprop can be set to 'yes'
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_genotyping_facility_submitted {
    my $self = shift;
    return $self->_get_projectprop('genotyping_facility_submitted');
}

sub set_genotyping_facility_submitted {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('genotyping_facility_submitted', $value);
}

=head2 accessors get_genotyping_facility_status(), set_genotyping_facility_status()

 Usage: For genotyping trials, if a genotyping plate has been submitted to genotyping facility, the status of that plate can be set here
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_genotyping_facility_status {
    my $self = shift;
    return $self->_get_projectprop('genotyping_facility_status');
}

sub set_genotyping_facility_status {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('genotyping_facility_status', $value);
}

=head2 accessors get_genotyping_plate_format(), set_genotyping_plate_format()

 Usage: For genotyping trials, this records if it is 96 wells or 384 or other
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_genotyping_plate_format {
    my $self = shift;
    return $self->_get_projectprop('genotyping_plate_format');
}

sub set_genotyping_plate_format {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('genotyping_plate_format', $value);
}

=head2 accessors get_genotyping_plate_sample_type(), set_genotyping_plate_sample_type()

 Usage: For genotyping trials, this records sample type of plate e.g. DNA
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_genotyping_plate_sample_type {
    my $self = shift;
    return $self->_get_projectprop('genotyping_plate_sample_type');
}

sub set_genotyping_plate_sample_type {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('genotyping_plate_sample_type', $value);
}

=head2 accessors get_plot_width(), set_plot_width()

 Usage: For field trials, this records plot width in meters
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_plot_width {
    my $self = shift;
    return $self->_get_projectprop('plot_width');
}

sub set_plot_width {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('plot_width', $value);
}

=head2 accessors get_plot_length(), set_plot_length()

 Usage: For field trials, this records plot length in meters
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_plot_length {
    my $self = shift;
    return $self->_get_projectprop('plot_length');
}

sub set_plot_length {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('plot_length', $value);
}

=head2 accessors get_field_size(), set_field_size()

 Usage: For field trials, this recordsfield size in hectares
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_field_size {
    my $self = shift;
    return $self->_get_projectprop('field_size');
}

sub set_field_size {
    my $self = shift;
    my $value = shift;
    $self->_set_projectprop('field_size', $value);
}


sub _get_projectprop {
    my $self = shift;
    my $term = shift;
    my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $term, 'project_property')->cvterm_id;
    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find({
        project_id => $self->get_trial_id(),
        type_id => $cvterm_id,
    });

    if ($row) {
        return $row->value;
    } else {
        return;
    }
}

sub _set_projectprop {
    my $self = shift;
    my $term = shift;
    my $value = shift;
    my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $term, 'project_property')->cvterm_id;
    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find_or_create({
        project_id => $self->get_trial_id(),
        type_id => $cvterm_id,
    });
    $row->value($value);
    $row->update();
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
                $self->_delete_field_layout_experiment();
                #print STDERR "DELETE MANAGEMENT FACTORS FOR TRIAL $trial_id...\n";
                $self->_delete_management_factors_experiments();
            }
        );
    };
    if ($@) {
        print STDERR "ERROR $@\n";
        return "An error occurred: $@\n";
    }

    return '';
}

=head2 function get_phenotype_metadata()

 Usage:        $trial->get_phenotype_metadata();
 Desc:         retrieves metadata.md_file entries for this trial. These entries are created during StorePhenotypes
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_phenotype_metadata {
	my $self = shift;
	my $trial_id = $self->get_trial_id();
	my @file_array;
	my %file_info;
	my $q = "SELECT file_id, m.create_date, p.sp_person_id, p.username, basename, dirname, filetype FROM nd_experiment_project JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenome.nd_experiment_md_files ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_md_files.nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata as m using(metadata_id) LEFT JOIN sgn_people.sp_person as p ON (p.sp_person_id=m.create_person_id) WHERE project_id=? and m.obsolete = 0 and NOT (metadata.md_files.filetype='generated from plot from plant phenotypes') and NOT (metadata.md_files.filetype='direct phenotyping') ORDER BY file_id ASC";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($trial_id);

	while (my ($file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype) = $h->fetchrow_array()) {
		$file_info{$file_id} = [$file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype];
	}
	foreach (keys %file_info){
		push @file_array, $file_info{$_};
	}
	return \@file_array;
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
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema = $self->phenome_schema;

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

    my $field_layout_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $genotyping_layout_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'genotyping_layout', 'experiment_type')->cvterm_id();

    my $layout_design = $self->get_layout->get_design;
    my @all_stock_ids;
    while( my($plot_num, $design_info) = each %$layout_design){
        my $plot_id = $design_info->{plot_id}; #this includes the "tissue_sample" in "genotyping_layout"
        my @plant_ids = $design_info->{plant_ids} ? @{$design_info->{plant_ids}} : ();
        my @subplot_ids = $design_info->{subplot_ids} ? @{$design_info->{subplot_ids}} : ();
        my @tissue_sample_ids = $design_info->{tissue_sample_ids} ? @{$design_info->{tissue_sample_ids}} : ();
        push @all_stock_ids, $plot_id;
        push @all_stock_ids, @plant_ids;
        push @all_stock_ids, @subplot_ids;
        push @all_stock_ids, @tissue_sample_ids;
    }

    #print STDERR Dumper \@all_stock_ids;
    my $stock_delete_rs = $self->bcs_schema->resultset('Stock::Stock')->search({stock_id=>{'-in'=>\@all_stock_ids}});
    while (my $r = $stock_delete_rs->next){
        print STDERR "Deleting associated ".$r->uniquename." (".$r->stock_id.")\n";
        $r->delete;
    }

    my $has_plants = $self->has_plant_entries();
    my $has_subplots = $self->has_subplot_entries();
    my $has_tissues = $self->has_tissue_sample_entries();

    if ($has_plants) {
        my $has_plants_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project_has_plant_entries', 'project_property' )->cvterm_id();
        my $has_plants_prop = $self->bcs_schema->resultset("Project::Projectprop")->find({ type_id => $has_plants_cvterm_id, project_id => $trial_id });
        $has_plants_prop->delete();
    }
    if ($has_subplots) {
        my $has_subplots_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project_has_subplot_entries', 'project_property' )->cvterm_id();
        my $has_subplots_prop = $self->bcs_schema->resultset("Project::Projectprop")->find({ type_id => $has_subplots_cvterm_id, project_id => $trial_id });
        $has_subplots_prop->delete();
    }
    if ($has_tissues) {
        my $has_tissues_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project_has_tissue_sample_entries', 'project_property' )->cvterm_id();
        my $has_tissues_prop = $self->bcs_schema->resultset("Project::Projectprop")->find({ type_id => $has_tissues_cvterm_id, project_id => $trial_id });
        $has_tissues_prop->delete();
    }

    my $trial_layout_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'trial_layout_json', 'project_property')->cvterm_id();
    my $has_cached_layout_prop = $self->bcs_schema->resultset("Project::Projectprop")->find({ type_id => $trial_layout_json_cvterm_id, project_id => $trial_id });
    if ($has_cached_layout_prop){
        $has_cached_layout_prop->delete();
    }

    my $nde_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->search({ 'me.type_id'=>[$field_layout_type_id, $genotyping_layout_type_id], 'project.project_id'=>$trial_id }, {'join'=>{'nd_experiment_projects'=>'project'}});
    if ($nde_rs->count != 1){
        die "Trial $trial_id does not have exactly one ndexperiment of type field_layout or genotyping_layout!"
    }
    while( my $r = $nde_rs->next){
        $r->delete();
    }

    #return { success => $plots_deleted };
    return { success => 1 };
}

sub _delete_management_factors_experiments {
    my $self = shift;
    my $management_factor_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'treatment_experiment', 'experiment_type')->cvterm_id();
    my $management_factors = $self->get_treatments;
    foreach (@$management_factors){
        my $m = CXGN::Trial->new({
            bcs_schema => $self->bcs_schema,
            metadata_schema => $self->metadata_schema,
            phenome_schema => $self->phenome_schema,
            trial_id => $_->[0]
        });
        my $nde_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->search({ 'me.type_id'=>$management_factor_type_id, 'project.project_id'=>$m->get_trial_id }, {'join'=>{'nd_experiment_projects'=>'project'}});
        if ($nde_rs->count != 1){
            die "Management factor ".$m->get_name." does not have exactly one ndexperiment of type treatment_experiment!"
        }
        while( my $r = $nde_rs->next){
            $r->delete();
        }
        $m->delete_project_entry;
    }
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
    print STDERR "deleted project ".$self->get_trial_id."\n";
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

=head2 function add_additional_uploaded_file()

 Usage:        $trial->add_additional_uploaded_file();
 Desc:         adds metadata.md_file entry for additional_files_uploaded to trial
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_additional_uploaded_file {
    my $self = shift;
    my $user_id = shift;
    my $archived_filename_with_path = shift;
    my $md5checksum = shift;
    my $result = $self->get_nd_experiment_id();
    if ($result->{error}){
        return {error => $result->{error} };
    }
    my $nd_experiment_id = $result->{nd_experiment_id};

    my $md_row = $self->metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
    $md_row->insert();
    my $file_row = $self->metadata_schema->resultset("MdFiles")
        ->create({
            basename => basename($archived_filename_with_path),
            dirname => dirname($archived_filename_with_path),
            filetype => 'trial_additional_file_upload',
            md5checksum => $md5checksum,
            metadata_id => $md_row->metadata_id(),
        });
    my $file_id = $file_row->file_id();
    my $experiment_file = $self->phenome_schema->resultset("NdExperimentMdFiles")
        ->create({
            nd_experiment_id => $nd_experiment_id,
            file_id => $file_id,
        });

    return {success => 1, file_id=>$file_id};
}

=head2 function get_additional_uploaded_files()

 Usage:        $trial->get_additional_uploaded_files();
 Desc:         retrieves metadata.md_file entries for additional_files_uploaded to trial. these entries are created from add_additional_uploaded_file
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_additional_uploaded_files {
    my $self = shift;
    my $trial_id = $self->get_trial_id();
    my @file_array;
    my %file_info;
    my $q = "SELECT file_id, m.create_date, p.sp_person_id, p.username, basename, dirname, filetype FROM project JOIN nd_experiment_project USING(project_id) JOIN phenome.nd_experiment_md_files ON (nd_experiment_project.nd_experiment_id=nd_experiment_md_files.nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata as m using(metadata_id) LEFT JOIN sgn_people.sp_person as p ON (p.sp_person_id=m.create_person_id) WHERE project_id=? and m.obsolete = 0 and metadata.md_files.filetype='trial_additional_file_upload' ORDER BY file_id ASC";
    my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($trial_id);

    while (my ($file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype) = $h->fetchrow_array()) {
        $file_info{$file_id} = [$file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype];
    }
    foreach (keys %file_info){
        push @file_array, $file_info{$_};
    }
    return \@file_array;
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
    my $stock_type = shift;
    my @data;
    my $dbh = $self->bcs_schema->storage()->dbh();
	#my $schema = $self->bcs_schema();

	my $h;
	my $join_string = '';
	my $where_string = '';
	if ($stock_type) {
		my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $stock_type, 'stock_type')->cvterm_id();
		$join_string = 'JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id)';
		$where_string = "stock.type_id=$stock_type_id and";
	}
	my $q = "SELECT phenotype.value::real FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) $join_string WHERE $where_string project_id=? and cvterm.cvterm_id = ? and phenotype.value~? ORDER BY phenotype_id ASC;";
	$h = $dbh->prepare($q);

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($self->get_trial_id(), $trait_id, $numeric_regex );
    while (my ($value) = $h->fetchrow_array()) {
	   push @data, $value + 0;
    }
    return @data;
}

=head2 function get_stock_phenotypes_for_traits(\@trait_id, 'all', ['plot_of','plant_of'], 'accession', 'subject')

 Usage:
 Desc:         returns all observations for the given traits in this trial
 Ret:			arrayref of [[ $stock_id, $stock_name, $trait_id, $trait_name, $phenotype_id, $pheno_uniquename, $uploader_id, $value, $rel_stock_id, $rel_stock_name ], [], ...]
 Args:			trait_ids : arrayref of cvterm_ids
 				stock_type: the stock type that the phenotype is associated to. 'plot', or 'plant', or 'all'
				stock_relationships: for fetching stock_relationships of the phenotyped stock. arrayref of relationships. e.g. ['plot_of', 'plant_of'].
				relationship_stock_type: the associated stock_type from the stock_relationship. 'plot', or 'plant'
				subject_or_object: whether the stock_relationship join should be done from the subject or object side. 'subject', or 'object'
 Side Effects:
 Example:

=cut

sub get_stock_phenotypes_for_traits {
    my $self = shift;
    my $trait_ids = shift;
    my $stock_type = shift; #plot, plant, all
    my $stock_relationships = shift; #arrayref. plot_of, plant_of
    my $relationship_stock_type = shift; #plot, plant
	my $subject_or_object = shift;
    my @data;
	#$self->bcs_schema->storage->debug(1);
    my $dbh = $self->bcs_schema->storage()->dbh();
	my $where_clause = "WHERE project_id=? and b.cvterm_id = ? and phenotype.value~? ";
	my $phenotyping_experiment_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

	if (scalar(@$trait_ids)>0){
		my $sql_trait_ids = join ("," , @$trait_ids);
		$where_clause .= "and a.cvterm_id IN ($sql_trait_ids) ";
	}

	my $relationship_join = '';
	if ($subject_or_object eq 'object') {
		$relationship_join = 'JOIN stock_relationship on (stock.stock_id=stock_relationship.object_id) JOIN stock as rel_stock on (stock_relationship.subject_id=rel_stock.stock_id) ';
	} elsif ($subject_or_object eq 'subject') {
		$relationship_join = 'JOIN stock_relationship on (stock.stock_id=stock_relationship.subject_id) JOIN stock as rel_stock on (stock_relationship.object_id=rel_stock.stock_id) ';
	}
	if ($stock_type ne 'all') {
		my $stock_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), $stock_type, 'stock_type')->cvterm_id();
		$where_clause .= "and stock.type_id=$stock_type_cvterm_id ";
	}
	my @stock_rel_or;
	foreach (@$stock_relationships) {
		my $stock_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), $_, 'stock_relationship')->cvterm_id();
		push @stock_rel_or, "stock_relationship.type_id=$stock_relationship_cvterm_id";
	}
	my $stock_rel_or_sql = join (" OR " , @stock_rel_or);
	if ($stock_rel_or_sql) {
		$where_clause .= "and ($stock_rel_or_sql) ";
	}
	my $rel_stock_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), $relationship_stock_type, 'stock_type')->cvterm_id();
	$where_clause .= "and rel_stock.type_id=$rel_stock_type_cvterm_id ";

	my $q = "SELECT stock.stock_id, stock.uniquename, a.cvterm_id, a.name || '|' || db.name ||  ':' || dbxref.accession, phenotype.phenotype_id, phenotype.uniquename, phenotype.sp_person_id, phenotype.value::real, rel_stock.stock_id, rel_stock.uniquename, stock_type.name
		FROM cvterm as a
		JOIN dbxref ON (a.dbxref_id = dbxref.dbxref_id)
		JOIN db USING(db_id)
		JOIN phenotype ON (a.cvterm_id=cvalue_id)
		JOIN nd_experiment_phenotype USING(phenotype_id)
		JOIN nd_experiment_project USING(nd_experiment_id)
		JOIN nd_experiment_stock USING(nd_experiment_id)
		JOIN cvterm as b ON (b.cvterm_id=nd_experiment_stock.type_id)
		JOIN stock USING(stock_id)
		JOIN cvterm as stock_type ON (stock_type.cvterm_id=stock.type_id)
		$relationship_join
		$where_clause
		ORDER BY stock.stock_id;";
    my $h = $dbh->prepare($q);

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($self->get_trial_id(), $phenotyping_experiment_cvterm, $numeric_regex );
    while (my ($stock_id, $stock_name, $trait_id, $trait_name, $phenotype_id, $pheno_uniquename, $uploader_id, $value, $rel_stock_id, $rel_stock_name, $stock_type) = $h->fetchrow_array()) {
        push @data, [$stock_id, $stock_name, $trait_id, $trait_name, $phenotype_id, $pheno_uniquename, $uploader_id, $value + 0, $rel_stock_id, $rel_stock_name, $stock_type];
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
	my $stock_type = shift;
    my $dbh = $self->bcs_schema->storage()->dbh();

    my @traits_assayed;

	my $q;
	if ($stock_type) {
		my $stock_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), $stock_type, 'stock_type')->cvterm_id();
		$q = "SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait, cvterm.cvterm_id, count(phenotype.value) FROM cvterm JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock on (stock.stock_id = nd_experiment_stock.stock_id) WHERE stock.type_id=$stock_type_cvterm_id and project_id=? and phenotype.value~? GROUP BY trait, cvterm.cvterm_id ORDER BY trait;";
	} else {
		$q = "SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait, cvterm.cvterm_id, count(phenotype.value) FROM cvterm JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? and phenotype.value~? GROUP BY trait, cvterm.cvterm_id ORDER BY trait;";
	}

    my $traits_assayed_q = $dbh->prepare($q);

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $traits_assayed_q->execute($self->get_trial_id(), $numeric_regex );
    while (my ($trait_name, $trait_id, $count) = $traits_assayed_q->fetchrow_array()) {
	push @traits_assayed, [$trait_id, $trait_name];
    }
    return \@traits_assayed;
}

=head2 function get_trait_components_assayed()

 Usage:
 Desc:         returns the cvterm_id and name for trait components assayed
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_trait_components_assayed {
    my $self = shift;
    my $stock_type = shift;
    my $composable_cvterm_format = shift;
    my $dbh = $self->bcs_schema->storage()->dbh();
    my $traits_assayed = $self->get_traits_assayed($stock_type);

    my %unique_components;
    my @trait_components_assayed;
    foreach (@$traits_assayed){
        my $trait_components = SGN::Model::Cvterm->get_components_from_trait($self->bcs_schema, $_->[0]);
        foreach (@$trait_components){
            if (!exists($unique_components{$_})){
                my $component_cvterm = SGN::Model::Cvterm::get_trait_from_cvterm_id($self->bcs_schema, $_, $composable_cvterm_format);
                push @trait_components_assayed, [$_, $component_cvterm];
                $unique_components{$_}++;
            }
        }
    }
    return \@trait_components_assayed;
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
    my $harvest_date_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project_harvest_date', 'project_property');
    if ($harvest_date_cvterm) {
        $harvest_date_cvterm_id = $harvest_date_cvterm->cvterm_id();
    }

    return $harvest_date_cvterm_id;
}


=head2 function create_plant_entities()

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
    my $inherits_plot_treatments = shift;

    my $create_plant_entities_txn = sub {
        my $chado_schema = $self->bcs_schema();
        my $layout = CXGN::Trial::TrialLayout->new( { schema => $chado_schema, trial_id => $self->get_trial_id(), experiment_type=>'field_layout' });
        my $design = $layout->get_design();

        my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type')->cvterm_id();
        my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
        my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
        my $plot_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
        my $plant_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $plant_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_index_number', 'stock_property')->cvterm_id();
        my $block_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'block', 'stock_property')->cvterm_id();
        my $plot_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot number', 'stock_property')->cvterm_id();
        my $replicate_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'replicate', 'stock_property')->cvterm_id();
        my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property')->cvterm_id();
        my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
        my $treatment_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'treatment_experiment', 'experiment_type')->cvterm_id();
        #my $plants_per_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plants_per_plot', 'project_property')->cvterm_id();

        my $treatments;
        my %treatment_experiments;
        my %treatment_plots;
        if ($inherits_plot_treatments){
            $treatments = $self->get_treatments();
            foreach (@$treatments){

                my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
                    type_id => $has_plants_cvterm,
                    value => $plants_per_plot,
                    project_id => $_->[0],
                });

                my $treatment_nd_experiment = $chado_schema->resultset("Project::Project")->search( { 'me.project_id' => $_->[0] }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $treatment_cvterm })->single();
                $treatment_experiments{$_->[0]} = $treatment_nd_experiment->nd_experiment_id();

                my $treatment_trial = CXGN::Trial->new({ bcs_schema => $chado_schema, trial_id => $_->[0]});
                my $plots = $treatment_trial->get_plots();
                foreach my $plot (@$plots){
                    $treatment_plots{$_->[0]}->{$plot->[0]} = 1;
                }
            }
        }

        my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
            type_id => $has_plants_cvterm,
            value => $plants_per_plot,
            project_id => $self->get_trial_id(),
        });

        my $field_layout_experiment = $chado_schema->resultset("Project::Project")->search( { 'me.project_id' => $self->get_trial_id() }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $field_layout_cvterm })->single();

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

            foreach my $plant_index_number (1..$plants_per_plot) {
                my $plant_name = $parent_plot_name."_plant_$plant_index_number";
                #print STDERR "... ... creating plant $plant_name...\n";

                $self->_save_plant_entry($chado_schema, $accession_cvterm, $parent_plot_organism, $parent_plot_name, $parent_plot, $plant_name, $plant_cvterm, $plant_index_number, $plant_index_number_cvterm, $block_cvterm, $plot_number_cvterm, $replicate_cvterm, $plant_relationship_cvterm, $field_layout_experiment, $field_layout_cvterm, $inherits_plot_treatments, $treatments, $plot_relationship_cvterm, \%treatment_plots, \%treatment_experiments, $treatment_cvterm);
            }
        }

        $layout->generate_and_cache_layout();
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

=head2 function save_plant_entries()

 Usage:        $trial->save_plant_entries(\%data, $plants_per_plot, $inherits_plot_treatments);
 Desc:         Some trials require plant-level data. It is possible to upload
                plant_names to save.
 Ret:
 Args:         Requires $plants_per_plot and \%data which is a hashref of the data parsed from the
                uploaded file.
                example: { 'myplotname1' => { 'plot_stock_id'=>123, 'plant_names'=>['plot1_plant1', 'plot1_plant2'] }, ... }
 Side Effects:
 Example:

=cut

sub save_plant_entries {
    my $self = shift;
    my $parsed_data = shift;
    my $plants_per_plot = shift;
    my $inherits_plot_treatments = shift;

    my $create_plant_entities_txn = sub {
        my $chado_schema = $self->bcs_schema();
        my $layout = CXGN::Trial::TrialLayout->new( { schema => $chado_schema, trial_id => $self->get_trial_id(), experiment_type=>'field_layout' });
        my $design = $layout->get_design();

        my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type')->cvterm_id();
        my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
        my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
        my $plot_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
        my $plant_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $plant_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_index_number', 'stock_property')->cvterm_id();
        my $block_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'block', 'stock_property')->cvterm_id();
        my $plot_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot number', 'stock_property')->cvterm_id();
        my $replicate_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'replicate', 'stock_property')->cvterm_id();
        my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property')->cvterm_id();
        my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
        my $treatment_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'treatment_experiment', 'experiment_type')->cvterm_id();
        #my $plants_per_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plants_per_plot', 'project_property')->cvterm_id();

        my $treatments;
        my %treatment_experiments;
        my %treatment_plots;
        if ($inherits_plot_treatments){
            $treatments = $self->get_treatments();
            foreach (@$treatments){

                my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
                    type_id => $has_plants_cvterm,
                    value => $plants_per_plot,
                    project_id => $_->[0],
                });

                my $treatment_nd_experiment = $chado_schema->resultset("Project::Project")->search( { 'me.project_id' => $_->[0] }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $treatment_cvterm })->single();
                $treatment_experiments{$_->[0]} = $treatment_nd_experiment->nd_experiment_id();

                my $treatment_trial = CXGN::Trial->new({ bcs_schema => $chado_schema, trial_id => $_->[0]});
                my $plots = $treatment_trial->get_plots();
                foreach my $plot (@$plots){
                    $treatment_plots{$_->[0]}->{$plot->[0]} = 1;
                }
            }
        }

        my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
            type_id => $has_plants_cvterm,
            value => $plants_per_plot,
            project_id => $self->get_trial_id(),
        });


        my $field_layout_experiment = $chado_schema->resultset("Project::Project")->search( { 'me.project_id' => $self->get_trial_id() }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $field_layout_cvterm })->single();

        while( my ($key, $val) = each %$parsed_data){
            my $plot_stock_id = $key;
            my $plot_name = $val->{plot_name};
            print STDERR " ... creating plants for plot $plot_name...\n";
            my $plot_row = $chado_schema->resultset("Stock::Stock")->find( { stock_id=>$plot_stock_id });

            if (!$plot_row) {
                print STDERR "The plot $plot_name is not found in the database\n";
                return "The plot $plot_name is not yet in the database. Cannot create plant entries.";
            }

            my $parent_plot = $plot_row->stock_id();
            my $parent_plot_name = $plot_row->uniquename();
            my $parent_plot_organism = $plot_row->organism_id();

            my $plant_index_number = 1;
            foreach my $plant_name (@{$val->{plant_names}}) {
                $self->_save_plant_entry($chado_schema, $accession_cvterm, $parent_plot_organism, $parent_plot_name, $parent_plot, $plant_name, $plant_cvterm, $plant_index_number, $plant_index_number_cvterm, $block_cvterm, $plot_number_cvterm, $replicate_cvterm, $plant_relationship_cvterm, $field_layout_experiment, $field_layout_cvterm, $inherits_plot_treatments, $treatments, $plot_relationship_cvterm, \%treatment_plots, \%treatment_experiments, $treatment_cvterm);
                $plant_index_number++;
            }
        }

        $layout->generate_and_cache_layout();
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

sub _save_plant_entry {
    my $self = shift;
    my $chado_schema = shift;
    my $accession_cvterm = shift;
    my $parent_plot_organism = shift;
    my $parent_plot_name = shift;
    my $parent_plot = shift;
    my $plant_name = shift;
    my $plant_cvterm = shift;
    my $plant_index_number = shift;
    my $plant_index_number_cvterm = shift;
    my $block_cvterm = shift;
    my $plot_number_cvterm = shift;
    my $replicate_cvterm = shift;
    my $plant_relationship_cvterm = shift;
    my $field_layout_experiment = shift;
    my $field_layout_cvterm = shift;
    my $inherits_plot_treatments = shift;
    my $treatments = shift;
    my $plot_relationship_cvterm = shift;
    my $treatment_plots_ref = shift;
    my $treatment_experiments_ref = shift;
    my $treatment_cvterm = shift;
    my %treatment_plots = %$treatment_plots_ref;
    my %treatment_experiments = %$treatment_experiments_ref;

    my $plant = $chado_schema->resultset("Stock::Stock")->create({
        organism_id => $parent_plot_organism,
        name       => $plant_name,
        uniquename => $plant_name,
        type_id => $plant_cvterm,
    });

    my $plantprop = $chado_schema->resultset("Stock::Stockprop")->create( {
        stock_id => $plant->stock_id(),
        type_id => $plant_index_number_cvterm,
        value => $plant_index_number,
    });

    #The plant inherits the properties of the plot.
    my $plot_props = $chado_schema->resultset("Stock::Stockprop")->search({ stock_id => $parent_plot, type_id => [$block_cvterm, $plot_number_cvterm, $replicate_cvterm] });
    while (my $prop = $plot_props->next() ) {
        #print STDERR $plant->uniquename()." ".$prop->type_id()."\n";
        $plantprop = $chado_schema->resultset("Stock::Stockprop")->create( {
            stock_id => $plant->stock_id(),
            type_id => $prop->type_id(),
            value => $prop->value(),
        });
    }

    #the plant has a relationship to the plot
    my $stock_relationship = $self->bcs_schema()->resultset("Stock::StockRelationship")->create({
        subject_id => $parent_plot,
        object_id => $plant->stock_id(),
        type_id => $plant_relationship_cvterm,
    });

    #the plant has a relationship to the accession
    my $plot_accession_rs = $self->bcs_schema()->resultset("Stock::StockRelationship")->search({'me.subject_id'=>$parent_plot, 'me.type_id'=>$plot_relationship_cvterm, 'object.type_id'=>$accession_cvterm }, {'join'=>'object'});
    if ($plot_accession_rs->count != 1){
        die "There is not 1 stock_relationship of type plot_of between the plot $parent_plot and an accession.";
    }
    $stock_relationship = $self->bcs_schema()->resultset("Stock::StockRelationship")->create({
        subject_id => $plant->stock_id(),
        object_id => $plot_accession_rs->first->object_id,
        type_id => $plant_relationship_cvterm,
    });

    #link plant to project through nd_experiment. also add nd_genolocation_id of plot to nd_experiment for the plant
    my $plant_nd_experiment_stock = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
        nd_experiment_id => $field_layout_experiment->nd_experiment_id(),
        type_id => $field_layout_cvterm,
        stock_id => $plant->stock_id(),
    });

    if ($inherits_plot_treatments){
        if($treatments){
            foreach (@$treatments){
                my $plots = $treatment_plots{$_->[0]};
                if (exists($plots->{$parent_plot})){
                    my $plant_nd_experiment_stock = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
                        nd_experiment_id => $treatment_experiments{$_->[0]},
                        type_id => $treatment_cvterm,
                        stock_id => $plant->stock_id(),
                    });
                }
            }
        }
    }
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

=head2 function create_tissue_samples()

 Usage:        $trial->create_tissue_samples(\@tissue_names, $inherits_plot_treatments);
 Desc:         Some trials require tissue_sample-level data. This function will
               add an additional layer of tissue samples for each plant.
 Ret:
 Args:         an arrayref of tissue names to add to sample name e.g. ['leaf','root']
 Side Effects:
 Example:

=cut

sub create_tissue_samples {
    my $self = shift;
    my $tissue_names = shift;
    my $inherits_plot_treatments = shift;

    my $create_tissue_sample_entries_txn = sub {
        my $chado_schema = $self->bcs_schema();
        my $layout = CXGN::Trial::TrialLayout->new( { schema => $chado_schema, trial_id => $self->get_trial_id(), experiment_type=>'field_layout' });
        my $design = $layout->get_design();

        my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type')->cvterm_id();
        my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
        my $subplot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot', 'stock_type')->cvterm_id();
        my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
        my $tissue_sample_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
        my $plot_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
        my $plant_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $tissue_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
        my $plant_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_index_number', 'stock_property')->cvterm_id();
        my $tissue_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_index_number', 'stock_property')->cvterm_id();
        my $has_tissues_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_tissue_sample_entries', 'project_property')->cvterm_id();
        my $block_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'block', 'stock_property')->cvterm_id();
        my $plot_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot number', 'stock_property')->cvterm_id();
        my $replicate_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'replicate', 'stock_property')->cvterm_id();
        my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
        my $treatment_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'treatment_experiment', 'experiment_type')->cvterm_id();

        my $treatments;
        my %treatment_experiments;
        my %treatment_plots;
        my %treatment_subplots;
        if ($inherits_plot_treatments){
            $treatments = $self->get_treatments();
            foreach (@$treatments){

                my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
                    type_id => $has_tissues_cvterm,
                    value => scalar(@$tissue_names),
                    project_id => $_->[0],
                });

                my $treatment_nd_experiment = $chado_schema->resultset("Project::Project")->search( { 'me.project_id' => $_->[0] }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $treatment_cvterm })->single();
                $treatment_experiments{$_->[0]} = $treatment_nd_experiment->nd_experiment_id();

                my $treatment_trial = CXGN::Trial->new({ bcs_schema => $chado_schema, trial_id => $_->[0]});
                my $plots = $treatment_trial->get_plots();
                foreach my $plot (@$plots){
                    $treatment_plots{$_->[0]}->{$plot->[0]} = 1;
                }
                my $subplots = $treatment_trial->get_subplots();
                foreach my $subplot (@$subplots){
                    $treatment_subplots{$_->[0]}->{$subplot->[0]} = 1;
                }
            }
        }

        my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
            type_id => $has_tissues_cvterm,
            value => scalar(@$tissue_names),
            project_id => $self->get_trial_id(),
        });

        my $field_layout_experiment = $chado_schema->resultset("Project::Project")->search( { 'me.project_id' => $self->get_trial_id() }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $field_layout_cvterm })->single();

        foreach my $plot (keys %$design) {
            my $plant_names = $design->{$plot}->{plant_names};
            my $subplot_names = $design->{$plot}->{subplot_names};
            my $subplots_plant_names = $design->{$plot}->{subplots_plant_names};
            my %plant_tissue_hash;
            foreach my $plant_name (@$plant_names){
                my $parent_plot_id = $design->{$plot}->{plot_id};
                my $parent_plot_name = $design->{$plot}->{plot_name};
                my $plant_row = $chado_schema->resultset("Stock::Stock")->find( { uniquename => $plant_name, type_id=>$plant_cvterm });

                if (! $plant_row) {
                    print STDERR "The plant $plant_name is not found in the database\n";
                    return "The plant $plant_name is not yet in the database. Cannot create tissue entries.";
                }

                my $parent_plant = $plant_row->stock_id();
                my $parent_plant_name = $plant_row->uniquename();
                my $parent_plant_organism = $plant_row->organism_id();

                my $tissue_index_number = 1;
                foreach my $tissue_name (@$tissue_names){
                    my $tissue_name = $parent_plant_name."_".$tissue_name.$tissue_index_number;
                    print STDERR "... ... creating tissue $tissue_name...\n";
                    $tissue_index_number++;

                    my $tissue = $chado_schema->resultset("Stock::Stock")->create({
                        organism_id => $parent_plant_organism,
                        name       => $tissue_name,
                        uniquename => $tissue_name,
                        type_id => $tissue_sample_cvterm,
                    });

                    my $tissueprop = $chado_schema->resultset("Stock::Stockprop")->create( {
                        stock_id => $tissue->stock_id(),
                        type_id => $tissue_index_number_cvterm,
                        value => $tissue_index_number,
                    });

                    #the tissue has a relationship to the plant
                    my $stock_relationship = $self->bcs_schema()->resultset("Stock::StockRelationship")->create({
                        object_id => $parent_plant,
                        subject_id => $tissue->stock_id(),
                        type_id => $tissue_relationship_cvterm,
                    });

                    #the tissue has a relationship to the plot
                    $stock_relationship = $self->bcs_schema()->resultset("Stock::StockRelationship")->create({
                        object_id => $parent_plot_id,
                        subject_id => $tissue->stock_id(),
                        type_id => $tissue_relationship_cvterm,
                    });

                    #the tissue has a relationship to the accession
                    my $plant_accession_rs = $self->bcs_schema()->resultset("Stock::StockRelationship")->search({'me.subject_id'=>$parent_plant, 'me.type_id'=>$plant_relationship_cvterm, 'object.type_id'=>$accession_cvterm }, {'join'=>'object'});
                    if ($plant_accession_rs->count != 1){
                        die "There is not 1 stock_relationship of type plant_of between the plant $parent_plant and an accession.";
                    }
                    $stock_relationship = $self->bcs_schema()->resultset("Stock::StockRelationship")->create({
                        object_id => $plant_accession_rs->first->object_id,
                        subject_id => $tissue->stock_id(),
                        type_id => $tissue_relationship_cvterm,
                    });

                    #link tissue to project through nd_experiment.
                    my $plant_nd_experiment_stock = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
                        nd_experiment_id => $field_layout_experiment->nd_experiment_id(),
                        type_id => $field_layout_cvterm,
                        stock_id => $tissue->stock_id(),
                    });

                    if ($inherits_plot_treatments){
                        if($treatments){
                            foreach (@$treatments){
                                my $plots = $treatment_plots{$_->[0]};
                                if (exists($plots->{$parent_plot_id})){
                                    my $plant_nd_experiment_stock = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
                                        nd_experiment_id => $treatment_experiments{$_->[0]},
                                        type_id => $treatment_cvterm,
                                        stock_id => $tissue->stock_id(),
                                    });
                                }
                            }
                        }
                    }

                    push @{$plant_tissue_hash{$plant_name}}, $tissue->stock_id;

                }
            }

            foreach my $subplot_name (%$subplots_plant_names){
                my $subplot_row = $chado_schema->resultset("Stock::Stock")->find({ uniquename => $subplot_name, type_id=>$subplot_cvterm });
                foreach my $plant (@{$subplots_plant_names->{$subplot_name}}){
                    foreach my $t (@{$plant_tissue_hash{$plant}}){
                        #the tissue has a relationship to the subplot
                        my $stock_relationship = $self->bcs_schema()->resultset("Stock::StockRelationship")->create({
                            object_id => $subplot_row->stock_id(),
                            subject_id => $t,
                            type_id => $tissue_relationship_cvterm,
                        });

                        if ($inherits_plot_treatments){
                            if($treatments){
                                foreach (@$treatments){
                                    my $subplots = $treatment_subplots{$_->[0]};
                                    if (exists($subplots->{$subplot_row->stock_id})){
                                        my $plant_nd_experiment_stock = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
                                            nd_experiment_id => $treatment_experiments{$_->[0]},
                                            type_id => $treatment_cvterm,
                                            stock_id => $t,
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        $layout->generate_and_cache_layout();
    };

    eval {
        $self->bcs_schema()->txn_do($create_tissue_sample_entries_txn);
    };
    if ($@) {
        print STDERR "An error occurred creating the tissue sample entities. $@\n";
        return 0;
    }

    print STDERR "Tissue sample entities created.\n";
    return 1;
}

=head2 function has_col_and_row_numbers()

	Usage:        $trial->has_col_and_row_numbers();
	Desc:         Some trials require tissue_samples from plants. This function will determine if a trial has row and column numbers for fieldMap spreadsheet download.
	Ret:          Returns 1 if trial has row and column numbers, 0 if the trial does not.
	Args:
	Side Effects:
	Example:

=cut

sub has_col_and_row_numbers {
	my $self = shift;
	my $chado_schema = $self->bcs_schema();
    my $layout = CXGN::Trial::TrialLayout->new( { schema => $chado_schema, trial_id => $self->get_trial_id(), experiment_type=>'field_layout' });
    my $design = $layout->get_design();
    
    my (@row_numbers, @col_numbers);
    foreach my $plot (keys %$design) {
        my $row_number = $design->{$plot}->{row_number};
        my $col_number = $design->{$plot}->{col_number};
        if ($row_number){
            push @row_numbers, $row_number;
        }
        if ($col_number){
            push @col_numbers, $col_number;
        }
    }
    
    if (scalar(@row_numbers) ne '0' && scalar(@col_numbers) ne '0'){
		return 1;
	} else {
		return 0;
	}

}

=head2 function has_tissue_sample_entries()

	Usage:        $trial->has_tissue_sample_entries();
	Desc:         Some trials require tissue_samples from plants. This function will determine if a trial has tissue_samples associated with it.
	Ret:          Returns 1 if trial has tissue_samples, 0 if the trial does not.
	Args:
	Side Effects:
	Example:

=cut

sub has_tissue_sample_entries {
	my $self = shift;
	my $chado_schema = $self->bcs_schema();
	my $has_tissues_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_tissue_sample_entries', 'project_property' );

	my $rs = $chado_schema->resultset("Project::Projectprop")->find({
		type_id => $has_tissues_cvterm->cvterm_id(),
		project_id => $self->get_trial_id(),
	});

	if ($rs) {
		return 1;
	} else {
		return 0;
	}

}


=head2 function has_subplot_entries()

	Usage:        $trial->has_subplot_entries();
	Desc:         Some trials require subplot-level data (splitplot designs). This function will determine if a trial has subplots associated with it.
	Ret:          Returns 1 if trial has subplots, 0 if the trial does not.
	Args:
	Side Effects:
	Example:

=cut

sub has_subplot_entries {
	my $self = shift;
	my $chado_schema = $self->bcs_schema();
	my $has_subplots_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_subplot_entries', 'project_property' );

	my $rs = $chado_schema->resultset("Project::Projectprop")->find({
		type_id => $has_subplots_cvterm->cvterm_id(),
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
     my $planting_date =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project_planting_date', 'project_property');

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

=head2 get_accessions

 Usage:        my $accessions = $t->get_accessions();
 Desc:         retrieves the accessions used in this trial.
 Ret:          an arrayref of { accession_name => acc_name, stock_id => stock_id }
 Args:         none
 Side Effects:
 Example:

=cut

sub get_accessions {
	my $self = shift;
	my @accessions;

	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type' )->cvterm_id();
	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plot_of", "stock_relationship")->cvterm_id();
	my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plant_of", "stock_relationship")->cvterm_id();
	my $subplot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "subplot_of", "stock_relationship")->cvterm_id();
	my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "tissue_sample_of", "stock_relationship")->cvterm_id();

	my $q = "SELECT DISTINCT(accession.stock_id), accession.uniquename
		FROM stock as accession
		JOIN stock_relationship on (accession.stock_id = stock_relationship.object_id)
		JOIN stock as plot on (plot.stock_id = stock_relationship.subject_id)
		JOIN nd_experiment_stock on (plot.stock_id=nd_experiment_stock.stock_id)
		JOIN nd_experiment using(nd_experiment_id)
		JOIN nd_experiment_project using(nd_experiment_id)
		JOIN project using(project_id)
		WHERE accession.type_id = $accession_cvterm_id
		AND stock_relationship.type_id IN ($plot_of_cvterm_id, $tissue_sample_of_cvterm_id, $plant_of_cvterm_id, $subplot_of_cvterm_id)
		AND project.project_id = ?
		GROUP BY accession.stock_id
		ORDER BY accession.stock_id;";

	my $h = $self->bcs_schema->storage->dbh()->prepare($q);
	$h->execute($self->get_trial_id());
	while (my ($stock_id, $uniquename) = $h->fetchrow_array()) {
		push @accessions, {accession_name=>$uniquename, stock_id=>$stock_id };
	}

	return \@accessions;
}

=head2 get_tissue_sources

    Usage:        my $tissue_sources = $t->get_tissue_sources();
    Desc:         retrieves the sources for the tisue_samples in a trial. in field_layout trials this can only be plants. In genotyping_layout trials the source of a tissue_sample can be tissue_samples, plants, plots, or accessions
    Ret:          an arrayref of { uniquename => acc_name, type=>'plant', stock_id => stock_id }
    Args:         none
    Side Effects:
    Example:

=cut

sub get_tissue_sources {
    my $self = shift;
    my @tissue_samples;
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample', 'stock_type' )->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "tissue_sample_of", "stock_relationship")->cvterm_id();
    my $q = "SELECT DISTINCT(stock.stock_id), stock.uniquename, cvterm.name
        FROM stock
        JOIN cvterm on (stock.type_id = cvterm.cvterm_id)
        JOIN stock_relationship on (stock.stock_id = stock_relationship.object_id)
        JOIN stock as tissue_sample on (tissue_sample.stock_id = stock_relationship.subject_id)
        JOIN nd_experiment_stock on (tissue_sample.stock_id=nd_experiment_stock.stock_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN nd_experiment_project using(nd_experiment_id)
        JOIN project using(project_id)
        WHERE tissue_sample.type_id = $tissue_sample_cvterm_id
        AND stock_relationship.type_id = $tissue_sample_of_cvterm_id
        AND project.project_id = ?
        GROUP BY (stock.stock_id, cvterm.name)
        ORDER BY (stock.stock_id);";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($self->get_trial_id());
    while (my ($stock_id, $uniquename, $type) = $h->fetchrow_array()) {
        push @tissue_samples, {uniquename=>$uniquename, type=>$type, stock_id=>$stock_id };
    }
    return \@tissue_samples;
}

=head2 get_plants

 Usage:        $plants = $t->get_plants();
 Desc:         retrieves that plants that are part of the design for this trial.
 Ret:          an array ref containing [ plant_name, plant_stock_id ]
 Args:
 Side Effects:
 Example:

=cut

sub get_plants {
	my $self = shift;
	my @plants;

	my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plant', 'stock_type' )->cvterm_id();
	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "genotyping_layout", "experiment_type")->cvterm_id();

	my $trial_plant_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock", {'stock.type_id'=>$plant_cvterm_id}, {order_by=>{'-asc'=>'uniquename'}});

	# removed "project.type_id" => [$field_trial_cvterm_id, $genotyping_trial_cvterm_id]

	my %unique_plants;
	while(my $rs = $trial_plant_rs->next()) {
		$unique_plants{$rs->uniquename} = $rs->stock_id;
	}
	foreach (keys %unique_plants) {
		my $combine = [$unique_plants{$_}, $_ ];
		push @plants, $combine;
	}

	return \@plants;
}

=head2 get_plants_per_accession

 Usage:        $plants = $t->get_plants_per_accession();
 Desc:         retrieves that plants that are part of the design for this trial grouping them by accession.
 Ret:          a hash ref containing { $accession_stock_id1 => [ [ plant_name1, plant_stock_id1 ], [ plant_name2, plant_stock_id2 ] ], ... }
 Args:
 Side Effects:
 Example:

=cut

sub get_plants_per_accession {
    my $self = shift;
    my %return;

    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plant', 'stock_type' )->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type' )->cvterm_id();

    my $trial_plant_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock", {'stock.type_id'=>$plant_cvterm_id, 'object.type_id'=>$accession_cvterm_id}, {join=>{'stock_relationship_subjects'=>'object'}, '+select'=>['stock_relationship_subjects.object_id'], '+as'=>['accession_stock_id']});

    my %unique_plants;
    while(my $rs = $trial_plant_rs->next()) {
        $unique_plants{$rs->uniquename} = [$rs->stock_id, $rs->get_column('accession_stock_id')];
    }
    while (my ($key, $value) = each %unique_plants) {
        push @{$return{$value->[1]}}, [$value->[0], $key];
    }
    #print STDERR Dumper \%return;
    return \%return;
}

=head2 get_seedlots

 Usage:         my $seedlots = $trial->get_seedlots();
 Desc:          returns a list of seedlots that are defined for the trial.
 Ret:           an array ref of elements that contain
                [ seedlot_name, seedlot_stock_id ]
 Args:          none
 Side Effects:  db access
 Example:

=cut

sub get_seedlots {
	my $self = shift;
	my @seedlots;

	my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'seedlot', 'stock_type' )->cvterm_id();
	my $seed_transaction_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "seed transaction", "stock_relationship")->cvterm_id();

	my $q = "SELECT DISTINCT(accession.stock_id), accession.uniquename
		FROM stock as accession
		JOIN stock_relationship on (accession.stock_id = stock_relationship.object_id)
		JOIN stock as plot on (plot.stock_id = stock_relationship.subject_id)
		JOIN nd_experiment_stock on (plot.stock_id=nd_experiment_stock.stock_id)
		JOIN nd_experiment using(nd_experiment_id)
		JOIN nd_experiment_project using(nd_experiment_id)
		JOIN project using(project_id)
		WHERE accession.type_id = $seedlot_cvterm_id
		AND stock_relationship.type_id IN ($seed_transaction_cvterm_id)
		AND project.project_id = ?
		GROUP BY accession.stock_id
		ORDER BY accession.stock_id;";

	#Removed nd_experiment.type_id IN ($field_trial_cvterm_id, $genotyping_trial_cvterm_id) AND

	my $h = $self->bcs_schema->storage->dbh()->prepare($q);
	$h->execute($self->get_trial_id());
	while (my ($stock_id, $uniquename) = $h->fetchrow_array()) {
		push @seedlots, [$stock_id, $uniquename];
	}

	return \@seedlots;
}

=head2 get_plots

 Usage:         my $plots = $trial->get_plots();
 Desc:          returns a list of plots that are defined for the trial.
 Ret:           an array ref of elements that contain
                [ plot_name, plot_stock_id ]
 Args:          none
 Side Effects:  db access
 Example:

=cut

sub get_plots {
	my $self = shift;
	my @plots;

	my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot', 'stock_type' )->cvterm_id();

	my $trial_plot_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock", {'stock.type_id'=>$plot_cvterm_id});

	my %unique_plots;
	while(my $rs = $trial_plot_rs->next()) {
		$unique_plots{$rs->uniquename} = $rs->stock_id;
	}
	foreach (sort keys %unique_plots) {
		#push @plots, {plot_name=> $_, plot_id=>$unique_plots{$_} } ;
		my $combine = [$unique_plots{$_}, $_ ];
		push @plots, $combine;
	}

	return \@plots;

}

=head2 get_plots_per_accession

 Usage:        $plots = $t->get_plots_per_accession();
 Desc:         retrieves that plots that are part of the design for this trial grouping them by accession.
 Ret:          a hash ref containing { $accession_stock_id1 => [ [ plot_name1, plot_stock_id1 ], [ plot_name2, plot_stock_id2 ] ], ... }
 Args:
 Side Effects:
 Example:

=cut

sub get_plots_per_accession {
    my $self = shift;
    my %return;

    # note: this function also retrieves stocks of type tissue_sample (for genotyping trials).
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot', 'stock_type' )->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type' )->cvterm_id();
    my $tissue_sample_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample', 'stock_type');
    my $tissue_sample_cvterm_id = $tissue_sample_cvterm ? $tissue_sample_cvterm->cvterm_id() : '';

    my @type_ids;
    push @type_ids, $plot_cvterm_id if $plot_cvterm_id;
    push @type_ids, $tissue_sample_cvterm_id if $tissue_sample_cvterm_id;

    print STDERR "TYPE IDS: ".join(", ", @type_ids);
    my $trial_plot_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock", {'stock.type_id'=> { in => [@type_ids] }, 'object.type_id'=>$accession_cvterm_id }, {join=>{'stock_relationship_subjects'=>'object'}, '+select'=>['stock_relationship_subjects.object_id'], '+as'=>['accession_stock_id']});

    my %unique_plots;
    while(my $rs = $trial_plot_rs->next()) {
        $unique_plots{$rs->uniquename} = [$rs->stock_id, $rs->get_column('accession_stock_id')];
    }
    while (my ($key, $value) = each %unique_plots) {
        push @{$return{$value->[1]}}, [$value->[0], $key];
    }
    #print STDERR Dumper \%return;
    return \%return;
}

=head2 get_subplots

 Usage:         my $subplots = $trial->get_subplots();
 Desc:          returns a list of subplots that are defined for the trial.
 Ret:           an array ref of elements that contain
                [ subplot_name, subplot_stock_id ]
 Args:          none
 Side Effects:  db access
 Example:

=cut

sub get_subplots {
	my $self = shift;
	my @plots;

	my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'subplot', 'stock_type' )->cvterm_id();

	my $trial_plot_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock", {'stock.type_id'=>$subplot_cvterm_id});

	my %unique_plots;
	while(my $rs = $trial_plot_rs->next()) {
		$unique_plots{$rs->uniquename} = $rs->stock_id;
	}
	foreach (sort keys %unique_plots) {
		#push @plots, {plot_name=> $_, plot_id=>$unique_plots{$_} } ;
		my $combine = [$unique_plots{$_}, $_ ];
		push @plots, $combine;
	}

	return \@plots;

}

=head2 get_tissue_samples

 Usage:        $tissues = $t->get_tissue_samples();
 Desc:         retrieves the tissue samples that are linked to plants for this trial.
 Ret:          an array ref containing [ tissue_sample_name, tissue_sample_stock_id ]
 Args:
 Side Effects:
 Example:

=cut

sub get_tissue_samples {
    my $self = shift;
    my @tissues;

    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample', 'stock_type')->cvterm_id;

    my $trial_tissues_rs = $self->bcs_schema->resultset("Project::Project")->find({ project_id => $self->get_trial_id(), })->search_related("nd_experiment_projects")->search_related("nd_experiment")->search_related("nd_experiment_stocks")->search_related("stock", {'stock.type_id'=>$tissue_sample_cvterm_id});

    my %unique_t;
    while(my $rs = $trial_tissues_rs->next()) {
        $unique_t{$rs->uniquename} = $rs->stock_id;
    }
    foreach (sort keys %unique_t) {
        my $combine = [$unique_t{$_}, $_ ];
        push @tissues, $combine;
    }
    return \@tissues;
}

=head2 get_controls

 Usage:        my $controls = $t->get_controls();
 Desc:         Returns the accessions that were used as controls in the design
 Ret:          an arrayref containing
               { accession_name => control_name, stock_id => control_stock_id }
 Args:         none
 Side Effects:
 Example:

=cut

sub get_controls {
	my $self = shift;
	my @controls;

	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type' )->cvterm_id();
	my $field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "field_layout", "experiment_type")->cvterm_id();
	my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "genotyping_layout", "experiment_type")->cvterm_id();
	my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plot_of", "stock_relationship")->cvterm_id();
	my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "plant_of", "stock_relationship")->cvterm_id();
	my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "tissue_sample_of", "stock_relationship")->cvterm_id();
	my $control_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "is a control", 'stock_property')->cvterm_id();

	my $q = "SELECT DISTINCT(accession.stock_id), accession.uniquename
		FROM stock as accession
		JOIN stock_relationship on (accession.stock_id = stock_relationship.object_id)
		JOIN stock as plot on (plot.stock_id = stock_relationship.subject_id)
		JOIN stockprop as control on (plot.stock_id=control.stock_id)
		JOIN nd_experiment_stock on (plot.stock_id=nd_experiment_stock.stock_id)
		JOIN nd_experiment using(nd_experiment_id)
		JOIN nd_experiment_project using(nd_experiment_id)
		JOIN project using(project_id)
		WHERE accession.type_id = $accession_cvterm_id
		AND stock_relationship.type_id IN ($plot_of_cvterm_id, $tissue_sample_of_cvterm_id, $plant_of_cvterm_id)
		AND project.project_id = ?
		AND control.type_id = $control_type_id
		GROUP BY accession.stock_id
		ORDER BY accession.stock_id;";

	#removed nd_experiment.type_id IN ($field_trial_cvterm_id, $genotyping_trial_cvterm_id) AND

	my $h = $self->bcs_schema->storage->dbh()->prepare($q);
	$h->execute($self->get_trial_id());
	while (my ($stock_id, $uniquename) = $h->fetchrow_array()) {
		push @controls, {accession_name=> $uniquename, stock_id=>$stock_id } ;
	}

	return \@controls;
}

=head2 get_controls_by_plot

 Usage:        my $controls = $t->get_controls_by_plot(\@plot_ids);
 Desc:         Returns the accessions that were used as controls in a trial from a list of trial plot ids. Improves on speed of get_controls by avoiding a join through nd_experiment_stock
 Ret:          an arrayref containing
               { accession_name => control_name, stock_id => control_stock_id }
 Args:         none
 Side Effects:
 Example:

=cut

sub get_controls_by_plot {
	my $self = shift;
	my $plot_ids = shift;
	my @ids = @$plot_ids;
	my @controls;

	my $accession_rs = $self->bcs_schema->resultset('Stock::Stock')->search(
		{ 'subject.stock_id' => { 'in' => \@ids} , 'type.name' => 'is a control' },
		{ join => { stock_relationship_objects => { subject => { stockprops => 'type' }}}, group_by => 'me.stock_id',},
  );

	while(my $accession = $accession_rs->next()) {
		push @controls, { accession_name => $accession->uniquename, stock_id => $accession->stock_id };
	}

	return \@controls;
}

=head2 get_treatments

 Usage:        $plants = $t->get_treatments();
 Desc:         retrieves the treatments that are part of this trial
 Ret:          an array ref containing from project table [ treatment_name, treatment_id ]
 Args:
 Side Effects:
 Example:

=cut

sub get_treatments {
    my $self = shift;
    my @plants;
    my $treatment_rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "trial_treatment_relationship", "project_relationship")->cvterm_id();

    my $treatment_rs = $self->bcs_schema->resultset("Project::ProjectRelationship")->search({type_id=>$treatment_rel_cvterm_id, object_project_id=>$self->get_trial_id()})->search_related('subject_project');

    my @treatments;
    while(my $rs = $treatment_rs->next()) {
        push @treatments, [$rs->project_id, $rs->name];
    }
    return \@treatments;
}

=head2 get_trial_contacts

 Usage:        my $contacts = $t->get_trial_contacts();
 Desc:         Returns an arrayref of hashrefs that contain all sp_person info fpr sp_person_ids saved as projectprops to this trial
 Ret:          an arrayref containing
               { sp_person_id => 1, salutation => 'Mr.', first_name => 'joe', last_name => 'doe', email => 'j@d.com' }
 Args:         none
 Side Effects:
 Example:

=cut

sub get_trial_contacts {
	my $self = shift;
	my @contacts;

	my $sp_person_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'sp_person_id','local')->cvterm_id;
	my $prop_rs = $self->bcs_schema->resultset('Project::Projectprop')->search(
		{ 'project_id' => $self->get_trial_id, 'type_id'=>$sp_person_id_cvterm_id }
	);

	while(my $prop = $prop_rs->next()) {
		my $q = "SELECT sp_person_id, username, salutation, first_name, last_name, contact_email, user_type, phone_number FROM sgn_people.sp_person WHERE sp_person_id=?;";
		my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
		$h->execute($prop->value);
		while (my ($sp_person_id, $username, $salutation, $first_name, $last_name, $email, $user_type, $phone) = $h->fetchrow_array()){
			push @contacts, {
				sp_person_id => $sp_person_id,
				salutation => $salutation,
				first_name => $first_name,
				last_name => $last_name,
				username => $username,
				email => $email,
				type => $user_type,
				phone_number => $phone
			};
		}
	}

	return \@contacts;
}

=head2 suppress_plot_phenotype

 Usage:        	my $suppress_return_error = $trial->suppress_plot_phenotype($trait_id, $plot_name, $plot_pheno_value, $phenotype_id);
				 if ($suppress_return_error) {
				   $c->stash->{rest} = { error => $suppress_return_error };
				   return;
				 }
 
 Desc:         Suppresses plot phenotype
 Ret:          
 Args:
 Side Effects:
 Example:

=cut

sub suppress_plot_phenotype {
	my $self = shift;
    my $trait_id = shift;
    my $plot_name = shift;
    my $phenotype_value = shift;
	my $phenotype_id = shift;
	my $username = shift;
	my $timestamp = shift;
	my $schema = $self->bcs_schema;
    my $trial_id = $self->get_trial_id();
	my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
	my $phenotype_outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
	my $error;
	my $json_string = { value => 1, username=>$username, timestamp=>$timestamp };
	
	my $prop_rs = $self->bcs_schema->resultset('Phenotype::Phenotypeprop')->search(
		{ 'phenotype_id' => $phenotype_id, 'type_id'=>$phenotype_outlier_type_id }
	);
	
	if ($prop_rs->count == 0) {
		my $suppress_plot_pheno = $schema->resultset("Phenotype::Phenotypeprop")->create({
			phenotype_id => $phenotype_id,
			type_id       => $phenotype_outlier_type_id,
			value => encode_json $json_string,
		});
	} 
	else {
		$error = "This plot phenotype has already been suppressed.";
	}
	
	return $error;
	
}

=head2 delete_assayed_trait

 Usage:        	my $delete_trait_return_error = $trial->delete_assayed_trait($phenotypes_ids, [] );
 				if ($delete_trait_return_error) {
   					$c->stash->{rest} = { error => $delete_trait_return_error };
   					return;
 				}
 
 Desc:         Delete Assayed Traits
 Ret:          
 Args:
 Side Effects:
 Example:

=cut

sub delete_assayed_trait {
	my $self = shift;
	my $pheno_ids = shift;
	my $trait_ids = shift;
    my $trial_id = $self->get_trial_id();
	my $schema = $self->bcs_schema;
	my $phenome_schema = $self->phenome_schema;
	my ($error, @nd_expt_ids);
	my $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

	my $search_params = { 'nd_experiment.type_id' => $nd_experiment_type_id, 'nd_experiment_projects.project_id' => $trial_id };
	if (scalar(@$trait_ids) > 0){
		$search_params->{'me.observable_id'} = { '-in' => $trait_ids };
	}
	if (scalar(@$pheno_ids) > 0){
		$search_params->{'me.phenotype_id'} = { '-in' => $pheno_ids };
	}
	#$schema->storage->debug(1);
	if (scalar(@$pheno_ids) > 0 || scalar(@$trait_ids) > 0 ){
		my $delete_pheno_id_rs = $schema->resultset("Phenotype::Phenotype")->search(
		$search_params,
		{
			join => { 'nd_experiment_phenotypes' => {'nd_experiment' => 'nd_experiment_projects'} },
			'+select' => ['nd_experiment.nd_experiment_id'],
			'+as' => ['nd_expt_id'],
		});
		while ( my $res = $delete_pheno_id_rs->next()){
			#print STDERR $res->phenotype_id." : ".$res->observable_id."\n";
			my $nd_expt_id = $res->get_column('nd_expt_id');
			push @nd_expt_ids, $nd_expt_id;
			$res->delete;
		}
        #print STDERR Dumper(\@nd_expt_ids);
		my $delete_nd_expt_md_files_id_rs = $phenome_schema->resultset("NdExperimentMdFiles")->search({
			nd_experiment_id => { '-in' => \@nd_expt_ids },
		});
		while (my $res = $delete_nd_expt_md_files_id_rs->next()){
			$res->delete;
		}
		
		my $delete_nd_expt_id_rs = $schema->resultset("NaturalDiversity::NdExperiment")->search({
			nd_experiment_id => { '-in' => \@nd_expt_ids },
		});
		while (my $res = $delete_nd_expt_id_rs->next()){
			$res->delete;
		}			
	}
	else {
		$error = "List of trait or phenotype ids was not provided for deletion.";
	}
	
	return $error;
	
}

1;


=head1 NAME

CXGN::Trial - helper class for trials

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::Trial;

use Moose;
use Try::Tiny;

=head2 bcs_schema()

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
	print STDERR "Found row for ".$self->get_trial_id()." ".$row->name()."\n";
    }

    if (!$row) { 
	die "The trial ".$self->get_trial_id()." does not exist";
    }
}


=head2 trial_id()

accessor for the trial_id. Needs to be set when calling the constructor.

=cut

has 'trial_id' => (isa => 'Int',
		   is => 'rw',
		   reader => 'get_trial_id',
		   writer => 'set_trial_id',
    );


has 'layout' => (isa => 'CXGN::Trial::TrialLayout',
		 is => 'rw',
		 reader => 'get_layout',
		 writer => 'set_layout',
		 predicate => 'has_layout',
		 

    );


=head2 get_year()

getter for the year property.

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

=head2 set_year()

setter for the year property.

=cut

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
	    { type_id => $type_id,
	    value => $year,
	    } );
    }
}

=head2 get_description()

getter for the description

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

    print STDERR "Setting new description $description for trial ".$self->get_trial_id()."\n";

    $row->description($description);

    $row->update();

}


=head2 get_location()

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

=head2 add_location

 Usage:        $trial->add_location($location_id);
 Desc:
 Ret:          nothing
 Args:
 Side Effects: database access
 Example:

=cut

sub add_location { 
    my $self = shift;
    my $location_id = shift;

    my $row = $self->bcs_schema()->resultset('Project::Projectprop')->create( 
	{ 
	    project_id => $self->get_trial_id(),
	    type_id => $self->get_location_type_id(),
	    value => $location_id,
	});    
}

=head2 remove_location

 Usage:        $trial->remove_location($location_id)
 Desc:         disociates the location with nd_geolocation_id of $location_id
               from the trial.
 Ret:
 Args:
 Side Effects: database access
 Example:

=cut

sub remove_location { 
    my $self = shift;
    my $location_id = shift;
    
    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find( 
	{ 
	    project_id => $self->get_trial_id(),
	    type_id => $self->get_location_type_id(),
	    value => $location_id,
	});
    if ($row) { 
	print STDERR "Removing location $location_id from trail ".$self->get_trial_id()."\n";
	$row->delete();
    }

}


=head2 associate_project_type

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub associate_project_type { 
    my $self = shift;
    my $type = shift;
    
    print STDERR "\n\nAssociate type $type...\n";
    # check if there is already a type associated with the project
    #
    my $cv_id = $self->bcs_schema->resultset('Cv::Cv')->find( { name => 'project_type' } )->cv_id();
    my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());
    my @ids = map { $_->[0] } @project_type_ids;
    my $has_project_type_rs = $self->bcs_schema->resultset('Project::Projectprop')->search( 
	{ 
	    project_id => $self->get_trial_id(),
	    type_id => { -in => [ @ids ] }
	});

    if ($has_project_type_rs->count() > 0) { 
	print STDERR "PROJECT ALREADY HAS ASSOCIATED PROJEC TYPE\n";
	return "Project already has an associated project type - bailing out.\n";
    }
    
    # get the id for the right cvterm...
    #
    my $type_id = 0;
    foreach my $pt (@project_type_ids) { 
	if ($pt->[1] eq $type) { 
	    $type_id = $pt->[0];
	}
    }
	    
    my $row = $self->bcs_schema->resultset('Project::Projectprop')->create( 
	{ 
	    value => 1,
	    type_id => $type_id,
	    project_id => $self->get_trial_id(),
	}
	);
    $row->insert();
    return undef;
}

=head2 function dissociate_project_type()

 Usage:        $t->dissociate_project_type();
 Desc:         removes the association of the trial with any trial type
 Ret:          
 Args:         none
 Side Effects: modifies the database
 Example:

=cut

sub dissociate_project_type { 
    my $self = shift;
    

    my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());

    my @ids = map { $_->[0] } @project_type_ids;
    my $rs = $self->bcs_schema()->resultset('Project::Projectprop')->search( { type_id => { -in => [ @ids ] }, project_id => $self->get_trial_id() });
    if (my $row = $rs->next()) { 
	$row->delete();
    }
    return undef;
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
		print STDERR "[get_project_type] ".$pt->[0]." ".$pt->[1]."\n";
		return $pt;
	    }
	}
    }
    return undef;

}

# CLASS METHOD!

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

# note: you may need to delete the metadata before deleting the phenotype data (see function).
# this function has a test!
#
sub delete_phenotype_data { 
    my $self = shift;

    my $trial_id = $self->get_trial_id();

    eval { 
	$self->bcs_schema->txn_do( 
	    sub { 
		print STDERR "\n\nDELETING PHENOTYPES...\n\n";
		
		# delete phenotype data associated with trial
		#
		my $trial = $self->bcs_schema()->resultset("Project::Project")->search( { project_id => $trial_id });

		my $q = "SELECT nd_experiment_id FROM nd_experiment_project JOIN nd_experiment_phenotype USING(nd_experiment_id) WHERE project_id =?";
	#	my $nd_experiment_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProject")->search( { project_id => $trial_id }, { join => 'nd_experiment_phenotype' });

	#	print STDERR "\n\nexperiment_count: ".$nd_experiment_rs->count()."\n\n";

	#	my @nd_experiment_ids = map { $_->nd_experiment_id } $nd_experiment_rs->all();
	
		

		my $h = $self->bcs_schema()->storage()->dbh()->prepare($q);

		$h->execute($trial_id);
		my @nd_experiment_ids = ();
		while (my ($id) = $h->fetchrow_array()) { 
		    push @nd_experiment_ids, $id;
		}
		$self->_delete_phenotype_experiments(@nd_experiment_ids);
	    });
    };
    if ($@) { 
	print STDERR "ERROR DELETING PHENOTYPE DATA $@\n";
	return "Error deleting phenotype data for trial $trial_id. $@\n";
    }
    return '';
    
}
    
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
		print STDERR "DELETING FIELD LAYOUT FOR TRIAL $trial_id...\n";

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

sub delete_metadata { 
    my $self = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;

    if (!$metadata_schema || !$phenome_schema) { die "Need metadata schema parameter\n"; }

    my $trial_id = $self->get_trial_id();

    print STDERR "Deleting metadata for trial $trial_id...\n";

    # first, deal with entries in the md_metadata table, which may reference nd_experiment (through linking table)
    #
    my $q = "SELECT distinct(metadata_id) FROM nd_experiment_project JOIN phenome.nd_experiment_md_files using(nd_experiment_id) JOIN metadata.md_files using(file_id) JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
    my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($trial_id);

    while (my ($md_id) = $h->fetchrow_array()) { 
	print STDERR "Associated metadata id: $md_id\n";
	my $mdmd_row = $metadata_schema->resultset("MdMetadata")->find( { metadata_id => $md_id } );
	if ($mdmd_row) { 
	    print STDERR "Obsoleting $md_id...\n";

	    $mdmd_row -> update( { obsolete => 1 });
	}
    }

    print STDERR "Deleting the entries in the linking table...\n";

    # delete the entries from the linking table...
    $q = "SELECT distinct(file_id) FROM nd_experiment_project JOIN phenome.nd_experiment_md_files using(nd_experiment_id) JOIN metadata.md_files using(file_id) JOIN metadata.md_metadata using(metadata_id) WHERE project_id=?";
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
    
    my $nd_exp_phenotype_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentPhenotype")->search( { nd_experiment_id=> { -in => [ @nd_experiment_ids ] }}, { join => 'phenotype' });
    if ($nd_exp_phenotype_rs->count() > 0) { 
	print STDERR "Deleting experiments ... \n";
	while (my $pep = $nd_exp_phenotype_rs->next()) { 
	    my $phenotype_rs = $self->bcs_schema()->resultset("Phenotype::Phenotype")->search( { phenotype_id => $pep->phenotype_id() } );
	    print STDERR "DELETING ".$phenotype_rs->count(). " phenotypes\n";
	    $phenotype_rs->delete_all();
	    $phenotypes_deleted++;
	}

    }
    $nd_exp_phenotype_rs->delete_all();
    
    # delete the experiments
    #
    my $delete_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->search({ nd_experiment_id => { -in => [ @nd_experiment_ids] }});

    $nd_experiments_deleted = $delete_rs->count();
    
    $delete_rs->delete_all();

    return { phenotypes_deleted => $phenotypes_deleted, 
	     nd_experiments_deleted => $nd_experiments_deleted
    };
}

=head2 _delete_field_layout_experiment

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

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

    my $field_layout_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => "field layout" })->cvterm_id();
    #print STDERR "Field layout type id = $field_layout_type_id\n";

    my $plot_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'plot' })->cvterm_id();
    #print STDERR "Plot type id = $plot_type_id\n";

    my $q = "SELECT stock_id FROM nd_experiment_project JOIN nd_experiment USING (nd_experiment_id) JOIN nd_experiment_stock ON (nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id) JOIN stock USING(stock_id) WHERE nd_experiment.type_id=? AND project_id=? AND stock.type_id=?";
    my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($field_layout_type_id, $trial_id, $plot_type_id);

    my $plots_deleted = 0;
    while (my ($plot_id) = $h->fetchrow_array()) { 
	my $plot = $self->bcs_schema()->resultset("Stock::Stock")->find( { stock_id => $plot_id });
	print STDERR "Deleting associated plot ".$plot->name()." (".$plot->stock_id().") \n";
	$plots_deleted++;
	$plot->delete();
    }

    $q = "SELECT nd_experiment_id FROM nd_experiment JOIN nd_experiment_project USING(nd_experiment_id) WHERE nd_experiment.type_id=? AND project_id=?";
    $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($field_layout_type_id, $trial_id);
    
    my ($nd_experiment_id) = $h->fetchrow_array();
    if ($nd_experiment_id) { 
	print STDERR "Delete corresponding nd_experiment entry  ($nd_experiment_id)...\n";
	my $nde = $self->bcs_schema()->resultset("NaturalDiversity::NdExperiment")->find( { nd_experiment_id => $nd_experiment_id });
	$nde->delete();
    }


    #return { success => $plots_deleted };
    return { success => 1 };
}

sub delete_project_entry { 
    my $self = shift;
    
    if ($self->phenotype_count() > 0) {
	print STDERR "Cannot delete trial with associated phenotypes.\n";
	return;
    }
    if ($self->get_layout()) { 
	print STDERR "Cannot delete trial with associated layout\n";
	return;
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

sub phenotype_count { 
    my $self = shift;

    my $phenotyping_experiment_type_id = $self->bcs_schema->resultset("Cv::Cvterm")->find( { name => 'phenotyping experiment' })->cvterm_id();
    
    my $phenotype_experiment_rs = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentProject")->search( 
    	{ 
    	    project_id => $self->get_trial_id(), 'nd_experiment.type_id' => $phenotyping_experiment_type_id}, 
    	{ 
    	    join => 'nd_experiment'  
    	}
    	);
    
     return $phenotype_experiment_rs->count();
}

sub total_phenotypes { 
    my $self = shift;
    
    my $pt_rs = $self->bcs_schema()->resultset("Phenotype::Phenotype")->search( { });
    return $pt_rs->count();
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






1;

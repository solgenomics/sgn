
=head1 NAME

CXGN::Trial - helper class for trials

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::Trial;


use Moose;

=head2 bcs_schema()

accessor for bcs_schema. Needs to be set when calling the constructor.

=cut

has 'bcs_schema' => ( isa => "Ref",
		      is => 'rw',
		      required => 1,
    );


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

    print STDERR "TRIAL ID: ".$self->get_trial_id()."\n";

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


sub add_location { 
    my $self = shift;
    my $location_id = shift;

    my $row = $self->bcs_schema->resultset('Project::Projectprop')->create( 
	{ 
	    project_id => $self->get_trial_id(),
	    type_id => $self->get_location_type_id(),
	    value => $location_id,
	});
    
    
}

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

# sub get_project_type { 
#     my $self = shift;
#     my $row = $self->bcs_schema->resulset('Project::Projectprop')->find( { project_id => $self->get_trial_id() , type_id=> $self->get_location_type_id() });
    
#     return $row->value();
    

# }


sub set_project_type { 
    

}

sub get_project_type { 
    my $self = shift;
    my $row = $self->bcs_schema->resultset('Cv::Cv')->find( { name => 'project_types' } );

    my @types;
    if ($row) { 
	my $rs = $self->bcs_schema->resultset('Project::Projectprop')->search( { project_id => $self->get_trial_id() })->search_related('type', { cv_id => $row->cv_id() });
	foreach my $r ($rs->next()) { 
	    push @types, [ $r->cvterm_id(), $r->name() ];
	}
	
	return @types;
    }
	
    return ();

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

sub get_name { 
    my $self = shift;
    my $row = $self->bcs_schema->resultset('Project::Project')->find( { project_id => $self->get_trial_id() });
    
    if ($row) { 
	return $row->name();
    }
}
 
sub set_name { 

}   


1;


package CXGN::DbStats;

use Moose;

has 'dbh' => (isa => 'Ref', is => 'rw');

# retrieve all trials grouped by trial type
#
sub trial_types { 
    my $self = shift;
    my $q = "SELECT cvterm.name, count(*) from projectprop join cvterm on(type_id=cvterm_id) JOIN cv USING (cv_id) WHERE cv_id=(SELECT cv_id FROM cv WHERE name='project_type') GROUP BY cvterm.name ORDER BY count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    return $h->fetchall_arrayref();
}

# retrieve all trials grouped by breeding programs
#
sub trials_by_breeding_program { 
    my $self = shift;
    my $q = "select project.name, count(*) from project join project_relationship on (project.project_id=project_relationship.object_project_id) join project as trial on(subject_project_id=trial.project_id) join projectprop on(project.project_id = projectprop.project_id) join cvterm on (projectprop.type_id=cvterm.cvterm_id) join projectprop as trialprop on(trial.project_id = trialprop.project_id) join cvterm as trialcvterm on(trialprop.type_id=trialcvterm.cvterm_id) where cvterm.name='breeding_program' and trialcvterm.name in (SELECT cvterm.name FROM cvterm join cv using(cv_id) WHERE cv.name='project_type') group by project.name order by count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    return $h->fetchall_arrayref();
}

# retrieve all the traits measured with counts
#
sub traits { 
    my $self = shift;
    my $q = "select cvterm.name, count(*) from phenotype join cvterm on (observable_id=cvterm_id)  group by cvterm.name order by count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    return $h->fetchall_arrayref();
}

sub stocks { 
    my $self = shift;
    my $q = "SELECT cvterm.name, count(*) FROM stock join cvterm on(type_id=cvterm_id) GROUP BY cvterm.name ORDER BY count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    return $h->fetchall_arrayref();
}

sub basic { 
    my $self = shift;
    my $q = "select count(*) from ";
}

sub activity { 
    my $self = shift;

    my @counts;
    my @weeks;
    foreach my $week (0..51) { 
	my $days = $week * 7;
	my $previous_days = ($week + 1) * 7;
	my $q = "SELECT count(*) FROM nd_experiment WHERE create_date > (now() - INTERVAL 'DAY $previous_days') and create_date < (now() - INTERVAL 'DAY $days')"; 
	my $h = $self->dbh()->prepare($q);
	$h->execute();
	my ($count) = $h->fetchrow_array();

	print STDERR "Activity in week $week = $count\n";
	
	push @counts, { letter => $week, frequency => rand() * 10 };
	#push @weeks, $week;
    }    
    return \@counts;
}
    


1;

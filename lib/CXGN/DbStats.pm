
package CXGN::DbStats;

use Moose;
use Data::Dumper;

has 'dbh' => (isa => 'Ref', is => 'rw');
has 'start_date' => ( is => 'rw', isa => 'Str', default => '1900-01-01' );
has 'end_date' => ( is => 'rw', isa => 'Str', default => '2100-12-31' );
has 'include_dateless_items' => (is => 'rw', isa => 'Bool', default => 1 );

# retrieve all trials grouped by trial type
#
sub trial_types {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }
    my $datelessq = "";

    if ($include_dateless_items == 1) {
	$datelessq = " project.create_date IS NULL OR ";
    }

    my $q = "SELECT cvterm.name, count(*) from project join projectprop using(project_id) join cvterm on(projectprop.type_id=cvterm_id) JOIN cv USING (cv_id) WHERE ( $datelessq (project.create_date > ? and project.create_date < ?) ) and cv_id=(SELECT cv_id FROM cv WHERE name='project_type') GROUP BY cvterm.name ORDER BY count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute($start_date, $end_date);
    return $h->fetchall_arrayref();
}

# retrieve all trials grouped by breeding programs
#
sub trial_count_by_breeding_program {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq = "";
    if ($include_dateless_items == 1) {
	$datelessq = " trial.create_date IS NULL OR ";
    }
    my $q = "select project.name, count(*) from project join project_relationship on (project.project_id=project_relationship.object_project_id) join project as trial on(subject_project_id=trial.project_id) join projectprop on(project.project_id = projectprop.project_id) join cvterm on (projectprop.type_id=cvterm.cvterm_id) join projectprop as trialprop on(trial.project_id = trialprop.project_id) join cvterm as trialcvterm on(trialprop.type_id=trialcvterm.cvterm_id) where ( $datelessq ( trial.create_date > ? and trial.create_date < ?)) and cvterm.name='breeding_program' and trialcvterm.name in (SELECT cvterm.name FROM cvterm join cv using(cv_id) WHERE cv.name='project_type') group by project.name order by count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute($start_date, $end_date);
    return $h->fetchall_arrayref();
}


sub phenotype_count_by_breeding_program {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq = "";
    if ($include_dateless_items == 1) {
	$datelessq = " trial.create_date IS NULL OR ";
    }

    my $q = "select project.name, count(*) from project join project_relationship on (project.project_id=project_relationship.object_project_id) join project as trial on(subject_project_id=trial.project_id) join projectprop on(project.project_id = projectprop.project_id) join cvterm on (projectprop.type_id=cvterm.cvterm_id) join projectprop as trialprop on(trial.project_id = trialprop.project_id) join cvterm as trialcvterm on(trialprop.type_id=trialcvterm.cvterm_id) join nd_experiment_project on(trial.project_id=nd_experiment_project.project_id) join nd_experiment_phenotype using(nd_experiment_id) where ( $datelessq ( trial.create_date > ? and trial.create_date < ?)) and cvterm.name='breeding_program' and trialcvterm.name in (SELECT cvterm.name FROM cvterm join cv using(cv_id) WHERE cv.name='project_type') group by project.name order by count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute($start_date, $end_date);
    return $h->fetchall_arrayref();

}


sub phenotype_completeness_by_breeding_program_and_trial {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift || $self->include_dateless_items();
    my $list_individual_traits = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq = "";
    if ($include_dateless_items == 1) {
	$datelessq = " trial.create_date IS NULL OR ";
    }

    print STDERR "GET PLOTS PER TRIAL...\n";
    # get number of plots per trial
    #
    my $q1 = "select project.name, trial.name, count(distinct(stock.stock_id)) from project join project_relationship on (project.project_id=project_relationship.object_project_id) join project as trial on(subject_project_id=trial.project_id) join projectprop on(project.project_id = projectprop.project_id) join cvterm on (projectprop.type_id=cvterm.cvterm_id) join projectprop as trialprop on(trial.project_id = trialprop.project_id) join cvterm as trialcvterm on(trialprop.type_id=trialcvterm.cvterm_id) join nd_experiment_project on(trial.project_id=nd_experiment_project.project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) where  ( $datelessq ( trial.create_date > ? and trial.create_date < ?)) and stock.type_id=(select cvterm_id from cvterm where name='plot') and cvterm.name='breeding_program' and trialcvterm.name not in ('genotyping_trial', 'genotyping_experiment') and length(trialprop.value)<100 and trialcvterm.cv_id=(select cv_id from cv where name='project_type') group by project.name, trial.name";

    print STDERR "GET PHENOTYPES PER TRIAL...\n";
    # get number of phenotypes per trial
    my $q2 = "select project.name, trial.name, count(*) from project join project_relationship on (project.project_id=project_relationship.object_project_id) join project as trial on(subject_project_id=trial.project_id) join projectprop on(project.project_id = projectprop.project_id) join cvterm on (projectprop.type_id=cvterm.cvterm_id) join projectprop as trialprop on(trial.project_id = trialprop.project_id) join cvterm as trialcvterm on(trialprop.type_id=trialcvterm.cvterm_id) join nd_experiment_project on(trial.project_id=nd_experiment_project.project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) join nd_experiment_phenotype on (nd_experiment_project.nd_experiment_id=nd_experiment_phenotype.nd_experiment_id) join phenotype using(phenotype_id) where  ( $datelessq ( trial.create_date > ? and trial.create_date < ?)) and stock.type_id=(select cvterm_id from cvterm where name='plot') and cvterm.name='breeding_program' and trialcvterm.name not in ('genotyping_trial', 'genotyping_experiment') and trialcvterm.cv_id=(select cv_id from cv where name='project_type') group by project.name, trial.name";

    print STDERR "GET TRAITS PER TRIAL...\n";
    # get the number of distinct traits measured per trial
    #
    my $q3 = "select project.name, trial.name, count(distinct(cvalue_id)) from project join project_relationship on (project.project_id=project_relationship.object_project_id) join project as trial on(subject_project_id=trial.project_id) join projectprop on(project.project_id = projectprop.project_id) join cvterm on (projectprop.type_id=cvterm.cvterm_id) join projectprop as trialprop on(trial.project_id = trialprop.project_id) join cvterm as trialcvterm on(trialprop.type_id=trialcvterm.cvterm_id) join nd_experiment_project on(trial.project_id=nd_experiment_project.project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) join nd_experiment_phenotype on (nd_experiment_project.nd_experiment_id=nd_experiment_phenotype.nd_experiment_id) join phenotype using(phenotype_id) where  ( $datelessq ( trial.create_date > ? and trial.create_date < ?)) and stock.type_id=(select cvterm_id from cvterm where name='plot') and cvterm.name='breeding_program' and trialcvterm.name not in ('genotyping_trial', 'genotyping_experiment') and trialcvterm.cv_id=(select cv_id from cv where name='project_type') group by project.name, trial.name";

    print STDERR "GET NUMBER OF PHENOTYPES MEASURED PER TRAIT AND TRIAL...\n";
    # get the number of phenotypes measured per trait and trial
        my $q4 = "select project.name, trial.name, trait.name, count(*) from project join project_relationship on (project.project_id=project_relationship.object_project_id) join project as trial on(subject_project_id=trial.project_id) join projectprop on(project.project_id = projectprop.project_id) join cvterm on (projectprop.type_id=cvterm.cvterm_id) join projectprop as trialprop on(trial.project_id = trialprop.project_id) join cvterm as trialcvterm on(trialprop.type_id=trialcvterm.cvterm_id) join nd_experiment_project on(trial.project_id=nd_experiment_project.project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) join nd_experiment_phenotype on (nd_experiment_project.nd_experiment_id=nd_experiment_phenotype.nd_experiment_id) join phenotype using(phenotype_id) join cvterm as trait on(phenotype.cvalue_id=trait.cvterm_id) where  ( $datelessq ( trial.create_date > ? and trial.create_date < ?)) and stock.type_id=(select cvterm_id from cvterm where name='plot') and cvterm.name='breeding_program' and trialcvterm.name not in ('genotyping_trial', 'genotyping_experiment') and trialcvterm.cv_id=(select cv_id from cv where name='project_type') group by project.name, trial.name, trait.name";

    my $h1 = $self->dbh->prepare($q1);
    $h1->execute($start_date, $end_date);
    my $plots = $h1->fetchall_arrayref();

    my %data;

    print Dumper($plots);
    foreach my $trial (@$plots) {
	$data{$trial->[0]}->{$trial->[1]}->{plots}=$trial->[2];
    }


    my $h2 = $self->dbh->prepare($q2);
    $h2->execute($start_date, $end_date);
    my $phenotypes = $h2->fetchall_arrayref();
    foreach my $trial (@$phenotypes) {
	$data{$trial->[0]}->{$trial->[1]}->{phenotypes} = $trial->[2];
    }

    my $h3 = $self->dbh->prepare($q3);
    $h3->execute($start_date, $end_date);
    my $traits = $h3->fetchall_arrayref();
    foreach my $trial (@$traits) {
	$data{$trial->[0]}->{$trial->[1]}->{traits} = $trial->[2];
    }

    my $h4 = $self->dbh->prepare($q4);
    $h4->execute($start_date, $end_date);
    my $per_trait = $h4->fetchall_arrayref();
    foreach my $trial (@$per_trait) {
	print STDERR "BP: $trial->[0] TRIAL: $trial->[1] TRAIT: $trial->[2] COUNT: $trial->[3]\n";
	$data{$trial->[0]}->{$trial->[1]}->{per_trait}->{$trial->[2]} = $trial->[3];
    }

    #output stats

    foreach my $bp (keys(%data)) {
	foreach my $t (keys(%{$data{$bp}})) {
	    my $completeness;
	    my $plotsxtraits = ($data{$bp}->{$t}->{plots} || 0) * ($data{$bp}->{$t}->{traits} || 0);
	    if ($plotsxtraits == 0) {
		$completeness = 'NA';
	    }
	    else {
		$completeness =  $data{$bp}->{$t}->{phenotypes} / $plotsxtraits;
	    }

	    print join("\t", $bp, $t, $data{$bp}->{$t}->{plots} || 0, $data{$bp}->{$t}->{phenotypes} || 0, $data{$bp}->{$t}->{traits} || 0, $completeness)."\n";

	    if ($list_individual_traits) {
		my $completeness_per_trait;
		foreach my $pt (keys(%{$data{$bp}->{$t}->{per_trait}})) {
		    my $per_trait =  $data{$bp}->{$t}->{per_trait}->{$pt};
		    my $plots = $data{$bp}->{$t}->{plots};
		    my $completeness = $per_trait / $plots;
		    print join("\t", "...", $pt,  $plots, $per_trait, $completeness)."\n";
		}
	    }

	}
    }
}

# retrieve all the traits measured with counts
#
sub traits {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " phenotype.create_date IS NULL OR ";
    }

    my $q = "select cvterm.name, count(*) from phenotype join cvterm on (observable_id=cvterm_id) where ( $datelessq ( phenotype.create_date > ? and phenotype.create_date < ? )) group by cvterm.name order by count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute($start_date, $end_date);
    return $h->fetchall_arrayref();
}

sub stocks {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " stock.create_date IS NULL OR ";
    }

    my $q = "SELECT cvterm.name, count(*) FROM stock join cvterm on(type_id=cvterm_id)  WHERE ( $datelessq ( stock.create_date > ? and stock.create_date < ? )) GROUP BY cvterm.name ORDER BY count(*) desc";
    my $h = $self->dbh->prepare($q);
    $h->execute($start_date, $end_date);
    return $h->fetchall_arrayref();
}

sub projects {
    my $self = shift;

    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " project.create_date IS NULL OR ";
    }

    my $q = "SELECT project.project_id, project.name FROM project join projectprop using(project_id) where ( $datelessq ( project.create_date > ? and project.create_date < ? )) group by project.project_id, project.name";

    my $h = $self->dbh->prepare($q);

    $h->execute($start_date, $end_date);

}



sub activity {
    my $self = shift;

    my @counts;
    my @weeks;
    foreach my $week (0..51) {
	my $days = $week * 7;
	my $previous_days = ($week + 1) * 7;
	my $q = "SELECT count(*) FROM nd_experiment WHERE create_date > (now() - INTERVAL '$previous_days DAYS') and create_date < (now() - INTERVAL '$days DAYS')";
	my $h = $self->dbh()->prepare($q);
	$h->execute();
	my ($count) = $h->fetchrow_array();

	print STDERR "Activity in week $week = $count\n";

	push @counts, { letter => $week, frequency => $count };
	#push @weeks, $week;
    }
    return \@counts;
}



sub stock_stats {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " create_date IS NULL OR ";
    }

    my $dbh = $self->dbh();

    my $query = "SELECT distinct(cvterm.name), count(*) FROM stock join cvterm on(type_id=cvterm_id) WHERE ( $datelessq ( create_date > ? and create_date < ? )) group by cvterm.name";

    my $h = $dbh->prepare($query);
    $h->execute($start_date, $end_date);

    my @data;
    while (my ($stock_type, $count) = $h->fetchrow_array()) {
	push @data, [ $stock_type, $count ];
    }

    return \@data;
}


sub accession_count_by_breeding_program {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    my $dbh = $self->dbh();

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq;
    if ($include_dateless_items == 1 ) {
	$datelessq = " accession.create_date IS NULL OR ";
    }
    my $query = "select breeding_program.name, count(*) from project as breeding_program join project_relationship on(breeding_program.project_id=project_relationship.object_project_id) join project as trial on(project_relationship.subject_project_id=trial.project_id) join projectprop on (breeding_program.project_id=projectprop.project_id) join nd_experiment_project on (trial.project_id=nd_experiment_project.project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) join stock_relationship on (stock.stock_id=stock_relationship.object_id) join stock as accession on (accession.stock_id=stock_relationship.subject_id) where ( $datelessq ( accession.create_date > ? and accession.create_date < ? ) ) and accession.type_id = (select cvterm_id from cvterm where name='accession') and projectprop.type_id = (select cvterm_id from cvterm where name='breeding_program') group by breeding_program.name order by count(*) desc";

    my $h = $dbh->prepare($query);
    $h->execute($start_date, $end_date);

    my @data;
    while (my ($bp, $count) = $h-> fetchrow_array()) {
	push @data, [ $bp, $count ];
    }
    return \@data;
}

sub accession_count_by_breeding_program_without_trials {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    my $dbh = $self->dbh();

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $datelessq;
    if ($include_dateless_items == 1 ) {
	$datelessq = " stock.create_date IS NULL OR ";
    }
    my $query = "select distinct(value), count(*) from stock join stockprop using(stock_id) join cvterm on (stockprop.type_id=cvterm.cvterm_id) where cvterm.name = 'organization' and ( $datelessq ( stock.create_date > ? and stock.create_date < ? ))  group by value;";

    my $h = $dbh->prepare($query);
    $h->execute($start_date, $end_date);

    my @data;
    while (my ($bp, $count) = $h-> fetchrow_array()) {
	push @data, [ $bp, $count ];
    }
    return \@data;
}

sub plot_count_by_breeding_program {
    my $self = shift;
    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $dbh = $self->dbh();

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " stock.create_date IS NULL OR ";
    }
    my $query = "select breeding_program.name, count(*) from project as breeding_program join project_relationship on(breeding_program.project_id=project_relationship.object_project_id) join project as trial on(project_relationship.subject_project_id=trial.project_id) join projectprop on (breeding_program.project_id=projectprop.project_id) join nd_experiment_project on (trial.project_id=nd_experiment_project.project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) where ( $datelessq ( stock.create_date > ? and stock.create_date < ? ) ) and stock.type_id = (select cvterm_id from cvterm where name='plot') and projectprop.type_id = (select cvterm_id from cvterm where name='breeding_program') group by breeding_program.name order by count(*) desc";

    my $h = $dbh->prepare($query);
    $h->execute($start_date, $end_date);

    my @data;
    while (my ($bp, $count) = $h-> fetchrow_array()) {
	push @data, [ $bp, $count ];
    }
    return \@data;
}

sub germplasm_count_with_pedigree {
    my $self = shift;

    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $dbh = $self->dbh();

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " stock.create_date IS NULL OR ";
    }


    my $query = "SELECT count(*) FROM stock join cvterm on(type_id=cvterm_id) join stock_relationship on(stock_id=object_id) WHERE stock_relationship.type_id in (select cvterm_id FROM cvterm where name='female_parent' or name='male_parent') and cvterm.name='accession' and ( $datelessq ( stock.create_date > ? and stock.create_date < ? )) group by cvterm.name";

    my $h = $dbh->prepare($query);
    $h->execute($start_date, $end_date);

    my @data;
    while (my ($stock_type, $count) = $h->fetchrow_array()) {
	push @data, [ 'accessions with pedigree', $count ];
    }

    return \@data;
}

sub germplasm_count_with_phenotypes {
    my $self = shift;

    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $dbh = $self->dbh();

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " stock.create_date IS NULL OR ";
    }

    my $query = "SELECT count(*) FROM stock join cvterm on(type_id=cvterm_id) join stock_relationship on (stock.stock_id=object_id) join stock as plot on (stock_relationship.subject_id=plot.stock_id) join nd_experiment_stock on(plot.stock_id=nd_experiment_stock.stock_id) join nd_experiment_phenotype on(nd_experiment_stock.nd_experiment_id=nd_experiment_phenotype.nd_experiment_id) WHERE cvterm.name='accession' and ( $datelessq ( stock.create_date > ? and stock.create_date < ? )) group by cvterm.name";

    my $h = $dbh->prepare($query);
    $h->execute($start_date, $end_date);

    my @data;
    while (my ($stock_type, $count) = $h->fetchrow_array()) {
	push @data, [ 'accessions with pedigree', $count ];
    }

    return \@data;
}

sub germplasm_count_with_genotypes {
    my $self = shift;

    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $dbh = $self->dbh();

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " stock.create_date IS NULL OR ";
    }

    # genotypes associated with accessions
    #
    my $query = "SELECT count(*) FROM stock join cvterm on(type_id=cvterm_id) join nd_experiment_stock on(stock.stock_id=nd_experiment_stock.stock_id) join nd_experiment_genotype on(nd_experiment_stock.nd_experiment_id=nd_experiment_genotype.nd_experiment_id) WHERE cvterm.name='accession' and ( $datelessq (stock.create_date > ? and stock.create_date < ?)) group by cvterm.name";


    my $h = $dbh->prepare($query);
    $h->execute($start_date, $end_date);


    my @data;
    while (my ($stock_type, $count) = $h->fetchrow_array()) {
	push @data, [ 'accessions with pedigree', $count ];
    }

    # genotypes associated with plants

    # gentoypes associated with plots, etc.??? need to do this separately?

    return \@data;
}


sub phenotype_count_per_trial {
    my $self = shift;

    my $start_date = shift || $self->start_date();
    my $end_date = shift || $self->end_date();
    my $include_dateless_items = shift;

    if (!defined($include_dateless_items)) { $include_dateless_items = $self->include_dateless_items(); }

    my $dbh = $self->dbh();

    my $datelessq;
    if ($include_dateless_items == 1) {
	$datelessq = " phenotype.create_date IS NULL OR ";
    }

    my $q = "select project.project_id, project.name, cvterm.name, count(cvterm_id) from project join nd_experiment_project using(project_id) join nd_experiment_phenotype using(nd_experiment_id) join phenotype using(phenotype_id) join cvterm on(cvalue_id=cvterm_id) where ( $datelessq ( phenotype.create_date > ? and phenotype.create_date < ? ))  group by project.project_id, project.name, cvterm.name";

    my $h = $dbh->prepare($q);
    $h->execute( $start_date, $end_date);

    return $h->fetch

}

1;

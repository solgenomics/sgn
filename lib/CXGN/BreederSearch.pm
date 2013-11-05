
package CXGN::BreederSearch;

use Moose;

use Data::Dumper;

has 'dbh' => ( 
    is  => 'rw',
    required => 1,
    );



sub get_intersect { 
    my $self = shift;
    my $criteria_list = shift;
    my $dataref = shift;
    
    my $type_id = $self->get_type_id('project year');
    my $accession_id = $self->get_stock_type_id('accession');
    my $plot_id = $self->get_stock_type_id('plot');

    my %queries = ( 
	accessions => {
	    location => "SELECT distinct(accession.uniquename), accession.uniquename FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and nd_geolocation.nd_geolocation_id in ($dataref->{accessions}->{locations})",
	    
	    years     => "SELECT distinct(accession.uniquename), accession.uniquename FROM projectprop JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and projectprop.value in ($dataref->{accessions}->{years})",
	    
	    projects  => "SELECT distinct(accession.uniquename), accession.uniquename FROM project JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and project.project_id in ($dataref->{accessions}->{projects})",
	    
	    traits    => "SELECT distinct(accession.uniquename), accession.uniquename FROM phenotype JOIN nd_experiment_phenotype using(phenotype_id) JOIN nd_experiment_stock USING (nd_experiment_id) JOIN stock as plot using(stock_id) JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) WHERE accession.type_id=$accession_id and phenotype.cvalue_id in ($dataref->{accessions}->{traits})",
	    
	    accessions    => "SELECT distinct(stock.uniquename), stock.uniquename FROM stock WHERE stock.type_id=$accession_id",

	    #genotype => "SELECT distinct(uniquename), stock.uniquename FROM stock as plot JOIN stock_relationship on (plot.stock_id=subject_id) JOIN stock as accession on (object_id=accession.stock_id) nd_experiment_stock USING(stock_id) JOIN nd_experiment_genotype USING (nd_experiment_id) JOIN ",
	    
	},

	plots => {
	    locations => "SELECT distinct(stock.uniquename), stock.uniquename FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) WHERE stock.type_id=$plot_id and nd_geolocation.nd_geolocation_id in ($dataref->{plots}->{locations})",
	    
	    years     => "SELECT distinct(stock.uniquename), stock.uniquename FROM projectprop JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock using(stock_id) WHERE  stock.type_id=$plot_id and projectprop.value in ($dataref->{plots}->{years})",
	    
	    projects  => "SELECT distinct(stock.uniquename), stock.uniquename FROM project JOIN nd_experiment_project using(project_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock using(stock_id) WHERE  stock.type_id=$plot_id and project.project_id in ($dataref->{plots}->{projects})",
	    
	    traits    => "SELECT distinct(stock.uniquename), stock.uniquename FROM phenotype JOIN nd_experiment_phenotype using(phenotype_id) JOIN nd_experiment_stock USING (nd_experiment_id) JOIN stock USING(stock_id) WHERE  stock.type_id=$plot_id and phenotype.cvalue_id in ($dataref->{plots}->{traits})",
	    
	    plots    => "SELECT distinct(stock.uniquename), stock.uniquename FROM stock WHERE  stock.type_id=$plot_id",

	    #genotype => "SELECT distinct(uniquename), stock.uniquename FROM stock JOIN nd_experiment_stock USING(stock_id) JOIN nd_experiment_genotype USING (nd_experiment_id) JOIN ",
	    
	},

	locations => { 
	    years     => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation join nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project USING (nd_experiment_id) JOIN projectprop using(project_id) where projectprop.value in ($dataref->{locations}->{years})",
	    projects  => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{locations}->{projects})",
	    
	    locations => "SELECT nd_geolocation_id, description FROM nd_geolocation",
	    
	    plots    => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock USING (nd_experiment_id) WHERE stock in ($dataref->{locations}->{plots})",
	    
	    traits    => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment USING (nd_geolocation_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) WHERE cvalue_id in ($dataref->{locations}->{traits})",

	    #genotype => "",
	    
	},
	
	years => {
	    locations => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING (project_id) JOIN nd_experiment using(nd_experiment_id) JOIN nd_geolocation USING (nd_geolocation_id) where nd_geolocation_id in ($dataref->{years}->{locations})",
	    
	    projects  => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN  project using(project_id) WHERE project.project_id in ($dataref->{years}->{projects})",
	    
	    years     => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop WHERE type_id=$type_id",
	    
            plots    => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE type_id=$type_id AND stock_id IN ($dataref->{years}->{plots})",
	    
	    traits    => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING(phenotype_id) WHERE type_id=$type_id AND cvalue_id IN ($dataref->{years}->{traits})",

	    #genotype => "",
	    
	    
	},
	
	
	projects => { 
	    locations => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_geolocation USING(nd_geolocation_id) WHERE nd_geolocation_id in ($dataref->{projects}->{locations})",
	    years     => "SELECT distinct(project_id), project.name FROM project JOIN projectprop USING (project_id) WHERE projectprop.value in ($dataref->{projects}->{years})",
	    
	    projects  => "SELECT project_id, project.name FROM project", 
	    
	    plots    => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id in ($dataref->{projects}->{plots})",
	    
	    traits    => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) WHERE cvalue_id in ($dataref->{projects}->{traits})",

	    #genotype => "",
	    
	},
	
	traits  => { 

	    prereq   => "DROP TABLE IF EXISTS cvalue_ids; CREATE TEMP TABLE cvalue_ids AS SELECT distinct(cvalue_id), phenotype_id FROM phenotype",

	    locations => "SELECT distinct(cvterm_id), cvterm.name FROM cvterm JOIN cvalue_ids on (cvalue_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_geolocation USING(nd_geolocation_id)  WHERE nd_geolocation.nd_geolocation_id in ($dataref->{traits}->{locations})",
	    
	    years => "SELECT distinct(cvterm_id), cvterm.name FROM cvterm JOIN cvalue_ids on (cvalue_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN projectprop USING(project_id) WHERE projectprop.type_id=$type_id and projectprop.value IN ($dataref->{traits}->{years})", 
	    
	    projects => "SELECT distinct(cvterm_id), cvterm.name FROM cvterm JOIN cvalue_ids on (cvalue_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN project USING(project_id) WHERE project.project_id in ($dataref->{traits}->{projects})",
	    
	    traits => "SELECT distinct(cvterm_id), cvterm.name FROM cvalue_ids JOIN cvterm on (cvalue_id=cvterm_id)",

	    plots => "SELECT distinct(cvterm_id), cvterm.name FROM nd_experiment_stock JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm ON (cvalue_id=cvterm_id) WHERE stock_id IN ($dataref->{traits}->{plots})",

	    #genotype => "",
	    
	},
	);
    
    my @query;
    my $item = $criteria_list->[-1];
    
    if (exists($queries{$item}->{prereq})) { 
	my $h = $self->dbh->prepare($queries{$item}->{prereq});
	$h->execute();
    }
    
    push @query, $queries{$item}->{$item}; # make the empty query work

    foreach my $criterion (@$criteria_list) { 
	if (exists($queries{$item}->{$criterion}) && $queries{$item}->{$criterion} && $dataref->{$item}->{$criterion}) { 
	    print STDERR "ITEM: $item. CRIT: $criterion. DATA: $queries{$item}->{$criterion}\n";
	    push @query, $queries{$item}{$criterion};
	}
    }
    my $query = join (" INTERSECT ", @query);
        
    print STDERR "QUERY: $query\n";
    my $h = $self->dbh->prepare($query);
    $h->execute();
    
    my @results;
    while (my ($id, $name) = $h->fetchrow_array()) { 
	push @results, [ $id, $name ];
    }    
    
    if (@results <= 10_000) { 
	return { results => \@results };
    }
    else { 
	
	return { message => 'Too many items to display ('.(scalar(@results)).')' };

    }
}




sub get_type_id { 
    my $self = shift;
    my $term = shift;
    my $q = "SELECT projectprop.type_id FROM projectprop JOIN cvterm on (projectprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='$term'";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}


sub get_stock_type_id { 
    my $self = shift;
    my $term =shift;
    my $q = "SELECT stock.type_id FROM stock JOIN cvterm on (stock.type_id=cvterm.cvterm_id) WHERE cvterm.name='$term'";
    my $h = $self->dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}

1;

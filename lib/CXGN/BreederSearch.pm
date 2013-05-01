
package CXGN::BreederSearch;

use Moose;

use Data::Dumper;

has 'dbh' => ( 
    is  => 'rw',
    isa => 'CXGN::DB::Connection',
    required => 1,
    );



sub get_intersect { 
    my $self = shift;
    my $criteria_list = shift;
    my $dataref = shift;
    
    my $type_id = $self->get_type_id('project year');
    
    my %queries = ( 
	stock => {
	    location => "SELECT distinct(stock.stock_id), stock.name FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) WHERE nd_geolocation.nd_geolocation_id in ($dataref->{stock}->{location})",
	    
	    year     => "SELECT distinct(stock.stock_id), stock.name FROM projectprop JOIN nd_experiment_project using(project_id) JOIN nd_experiment using(nd_experiment_id) JOIN stock using(stock_id) WHERE projectprop.value in ($dataref->{stock}->{year})",
	    
	    project  => "SELECT distinct(stock.stock_id), stock.name FROM project JOIN nd_experiment_project using(project_id) JOIN nd_experiment using(nd_experiment_id) JOIN stock using(stock_id) WHERE project.project_id in ($dataref->{stock}->{project})",
	    
	    trait    => "SELECT distinct(stock.stock_id), stock.name FROM phenotype JOIN nd_experiment_phenotype using(phenotype_id) JOIN nd_experiment_stock USING (nd_experiment_id) WHERE phenotype.cvalue_id in ($dataref->{stock}->{trait})",
	    
	    stock    => "SELECT stock_id, stock.name FROM stock",
	    
	},

	location => { 
	    year     => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation join nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project USING (nd_experiment_id) JOIN projectprop using(project_id) where projectprop.value in ($dataref->{location}->{year})",
	    project  => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{location}->{project})",
	    
	    location => "SELECT nd_geolocation_id, description FROM nd_geolocation",
	    
	    stock    => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock USING (nd_experiment_id) WHERE stock in ($dataref->{location}->{stock})",
	    
	    trait    => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment_phenotype USING (nd_experiment_id) JOIN phenotype USING phenotype_id WHERE cvalue_id in ($dataref->{location}->{trait})",
	    
	},
	
	year => {
	    location => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING (project_id) JOIN nd_experiment using(nd_experiment_id) JOIN nd_geolocation USING (nd_geolocation_id) where nd_geolocation_id in ($dataref->{year}->{location})",
	    
	    project  => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING project_id JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{year}->{project})",
	    
	    year     => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop WHERE type_id=$type_id",
	    
            stock    => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE type_id=$type_id AND stock_id IN ($dataref->{year}->{stock})",
	    
	    trait    => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING(phenotype_id) WHERE type_id=$type_id AND cvalue_id IN ($dataref->{year}->{trait})",
	    
	    
	},
	
	
	project => { 
	    location => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_geolocation USING(nd_geolocation_id) WHERE nd_geolocation_id in ($dataref->{project}->{location})",
	    year     => "SELECT distinct(project_id), project.name FROM project JOIN projectprop USING (project_id) WHERE projectprop.value in ($dataref->{project}->{year})",
	    
	    project  => "SELECT project_id, project.name FROM project", 
	    
	    stock    => "SELECT distinct(project_id), project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id in ($dataref->{project}->{stock})",
	    
	    trait    => "SELECT distinct(project_id, project.name FROM project JOIN nd_experiment_project USING(project_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING phenotype_id WHERE cvalue_id in ($dataref->{project}->{trait})",
	    
	},
	
	trait  => { 
	    location => "SELECT distinct(cvterm_id), cvterm.name FROM cvterm JOIN phenotype on (cdata_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_geolocation USING(nd_experiment_id)  WHERE nd_geolocation.nd_geolocation_id in ($dataref->{trait}->{location}",
	    
	    year => "SELECT distinct(cvterm_id), cvterm.name FROM cvterm JOIN phenotype on (cdata_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN projectprop USING(project_id) WHERE projectprop.type_id=$type_id and projectprop.value IN ($dataref->{trait}->{year})", 
	    
	    project => "SELECT distinct(cvterm_id), cvterm.name FROM cvterm JOIN phenotype on (cdata_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN project USING(project_id) WHERE project.project_id in ($dataref->{trait}->{project})",
	    
	    trait => "SELECT distinct(cvterm_id), cvterm.name FROM cvterm JOIN phenotype on (cdata_id=cvterm_id) JOIN nd_experiment_phenotype USING(phenotype_id)",
	    
	},
	);
    
    my @query;
    my $item = $criteria_list->[-1];
    print STDERR "criteria_list = ".join(",",@$criteria_list)."\n";
    
    print STDERR "DATAREF = ".Data::Dumper::Dumper($dataref);
    foreach my $criterion (@$criteria_list) { 
	if ($queries{$item}->{$criterion}) { 
	    print STDERR "ITEM: $item. CRIT: $criterion\n";
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
    return \@results;
    
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


1;

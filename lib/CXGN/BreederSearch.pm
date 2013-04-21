
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
	    
	    '' => 'SELECT stock_id, stock.name FROM stock',

	    stock => '',
	    
	    
	},

	location => { 
	    year => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation join nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project USING (nd_experiment_id) JOIN projectprop using(project_id) where projectprop.value in ($dataref->{location}->{year})",
	    project => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{location}->{project})",
	    
	    location => 'SELECT nd_geolocation_id, description FROM nd_geolocation',
	    
	},
	
	year => {
	    location => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING (project_id) JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_projectprop using(project_id) where nd_geolocation_id in ($dataref->{year}->{location})",

	    projects => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING project_id JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{year}->{project})",

	    '' => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop WHERE type_id=$type_id",

	    'year' => '',
	    
	    
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


package SGN::Controller::AJAX::BreederSearch;

use Moose;
use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );



sub get_data : Path('/ajax/breeder/search') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $select1 = $c->req->param("select1");
    my $select2 = $c->req->param("select2");
    my $select3 = $c->req->param("select3");

    my $c1    = $c->req->param("c1_data");
    my $c2    = $c->req->param("c2_data");
    my $c3    = $c->req->param("c3_data");

    my @c1 = split ",", $c1;
    my @c2 = split ",", $c2;
    my @c3 = split ",", $c3;

    my $c1_data = join ",", (map { "\'$_\'"; } @c1);
    my $c2_data = join ",", (map { "\'$_\'"; } @c2);
    my $c3_data = join ",", (map { "\'$_\'"; } @c3);
    
    print STDERR "C1: $c1_data. C2: $c2_data. C3: $c3_data\n";




    my $stocks = undef;
    my $error = "";

    foreach my $select ($select1, $select2, $select3) { 
	print STDERR "Checking $select\n";
	chomp($select);
	if (! any { $select eq $_ } ('project', 'location', 'year', undef)) { 
	    $error = "Valid keys are project, year, and location";
	    $c->stash->{rest} = { error => $error };
	    return;
	}
    }

    my $dbh = $c->dbc->dbh();
    my $q = "";  # get the primary requested data
    my $sq = ""; # the associated query to get all the stocks

    my $data_tainted = 0;
    foreach my $d ($c1_data, $c2_data, $c3_data) { 
	if ($d !~ /^[\d,]+$/g && defined($d)) { 
	    print STDERR "Illegal chars in $d\n";
	    $data_tainted =1;
	}
    }

    $q = "SELECT projectprop.type_id FROM projectprop JOIN cvterm on (projectprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='project year'";
    my $h = $dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();




    get_stock_union($select1, $select2, $select3, );
    
	if ($select1 eq "location") { 
	    get_location_union
    }


    

}
    

sub get_stock_union { 
    my $self = shift;
    my $c = shift;

    my $criteria_list = shift;

    my ($locations_ref, $years_ref, $projects_ref) = @_;

    my %queries = (
	location => 'SELECT distinct(stock.stock_id), stock.name FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) WHERE nd_geolocation.nd_geolocation_id in (?)',
	
	year     => 'SELECT distinct(stock.stock_id), stock.name FROM projectprop JOIN nd_experiment_project using(project_id) JOIN nd_experiment using(nd_experiment_id) JOIN stock using(stock_id) WHERE projectprop.value in (?)',

	project  => 'SELECT distinct(stock.stock_id), stock.name FROM project JOIN nd_experiment_project using(project_id) JOIN nd_experiment using(nd_experiment_id) JOIN stock using(stock_id) WHERE project.project_id in (?)',

	'' => 'SELECT stock_id, stock.name FROM stock',

	);

    my @query;
    foreach my $criterion (@$criteria_list) { 
	push @query, $queries{$criterion};
    }
    my $query = join (" UNION ", @query);
    
    my $h = $c->dbc->dbh->prepare($query);
    $h->execute();

    my @stocks;
    while (my ($stock_id, $stock_name) = $h->fetchrow_array()) { 
	push @stocks, [ $stock_id, $stock_name ];
    }
    return \@stocks;
}

sub get_location_union { 
    my $self = shift;
    my $c = shift;
    
    my $criteria_list = shift;
    
    my ($locations_ref, $years_ref, $projects_ref) = @_;
    
    my %queries = (
	year => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation join nd_experiment using(nd_geolocation_id) JOIN nd_experiment_projectprop using(project_id) where projectprop.values in ($years_ref)",
	projects => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($projects_ref)",
	
	'' => 'SELECT nd_geolocation_id, description FROM nd_geolocation',
	);

        my @query;
    foreach my $criterion (@$criteria_list) { 
	push @query, $queries{$criterion};
    }
    my $query = join (" UNION ", @query);
    
    my $h = $c->dbc->dbh->prepare($query);
    $h->execute();

    my @locations;
    while (my ($loc_id, $loc_name) = $h->fetchrow_array()) { 
	push @locations, [ $loc_id, $loc_name ];
    }
    return \@locations;
}

sub get_year_union { 
    my $self = shift;
    my $c = shift;
    
    my $criteria_list = shift;
    
    my ($locations_ref, $years_ref, $projects_ref) = @_;
    
    my %queries = (
	year => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING project_id JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_projectprop using(project_id) where projectprop.values in ($years_ref)",
	projects => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING project_id JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($projects_ref)",
	'' => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop WHERE type_id=$type_id";
	);

        my @query;
    foreach my $criterion (@$criteria_list) { 
	push @query, $queries{$criterion};
    }
    my $query = join (" UNION ", @query);
    
    my $h = $c->dbc->dbh->prepare($query);
    $h->execute();

    my @years;
    while (my ($year, $year) = $h->fetchrow_array()) { 
	push @years, [ $year, $year ];
    }
    return \@years;


}

sub get_project_union {


        my $self = shift;
    my $c = shift;
    
    my $criteria_list = shift;
    
    my ($locations_ref, $years_ref, $projects_ref) = @_;
    
    my %queries = (
	year => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation join nd_experiment using(nd_geolocation_id) JOIN nd_experiment_projectprop using(project_id) where projectprop.values in ($years_ref)",
	projects => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($projects_ref)",
	);

        my @query;
    foreach my $criterion (@$criteria_list) { 
	push @query, $queries{$criterion};
    }
    my $query = join (" UNION ", @query);
    
    my $h = $c->dbc->dbh->prepare($query);
    $h->execute();

    my @stocks;
    while (my ($lod_id, $loc_name) = $h->fetchrow_array()) { 
	push @locations, [ $loc_id, $loc_name ];
    }
    return \@stocks;

}
    
    

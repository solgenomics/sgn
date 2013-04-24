
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

    my $criteria_list;
    my @selects = qw | select1 select2 select3 |;
    foreach my $s (@selects) { 
	push @$criteria_list, $c->req->param($s);
    }

    my $dataref = {};
    
    my @params = qw | c1_data c2_data c3_data |;

    for (my $i=0; $i<scalar(@$criteria_list); $i++) { 
	my $data =  $c->req->params($params[$i]);

	# items need to be quoted in sql
	#
	my $qdata = join ",", (map { "\'$_\'"; } (split ",", $data));

	push $dataref->{$criteria_list->[$i]} = $qdata;
    }

    my $stocks = undef;
    my $error = "";

    foreach my $select (@$criteria_list) { 
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

  

    
    my $item = $criteria_list->[-1];

    my $results_ref = get_union($criteria_list, $data); 

    $c->stash->{rest} = $results_ref;
}
    


sub get_union { 
    my $self = shift;
    my $c = shift;
    my $criteria_list = shift;
    my $dataref = shift;
  
    my $type_id = $self->get_type_id('project year');
  
    my %queries = ( 
	stock => {
	    location => "SELECT distinct(stock.stock_id), stock.name FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) WHERE nd_geolocation.nd_geolocation_id in ($dataref->{location})",
	    
	    year     => "SELECT distinct(stock.stock_id), stock.name FROM projectprop JOIN nd_experiment_project using(project_id) JOIN nd_experiment using(nd_experiment_id) JOIN stock using(stock_id) WHERE projectprop.value in ($dataref->{year})",
	    
	    project  => "SELECT distinct(stock.stock_id), stock.name FROM project JOIN nd_experiment_project using(project_id) JOIN nd_experiment using(nd_experiment_id) JOIN stock using(stock_id) WHERE project.project_id in ($dataref->{project})",
	    
	    '' => 'SELECT stock_id, stock.name FROM stock',

	    stock => '',
	    
	    
	},

	location => { 
	    year => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation join nd_experiment using(nd_geolocation_id) JOIN nd_experiment_projectprop using(project_id) where projectprop.values in ($dataref->{year})",
	    projects => "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM nd_geolocation JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{project})",
	    
	    '' => 'SELECT nd_geolocation_id, description FROM nd_geolocation',
	    'location' => '',
	    
	},
	
	year => {
	    location => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING project_id JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_projectprop using(project_id) where nd_geolocation_id in ($dataref->{location})",

	    projects => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop JOIN nd_experiment_project USING project_id JOIN nd_experiment using(nd_geolocation_id) JOIN nd_experiment_project using(nd_experiment_id) JOIN project using(project_id) WHERE project.project_id in ($dataref->{project})",

	    '' => "SELECT distinct(projectprop.value), projectprop.value FROM projectprop WHERE type_id=$type_id",

	    'year' => '',
	    
	    
	},
	);
    
    my @query;
    my $item = $criteria_list->[-1];

    foreach my $criterion (@$criteria_list) { 
	if ($queries{$item}->{$criterion}) { 
	    push @query, $queries{$item}{$criterion};
	}
    }
    my $query = join (" UNION ", @query);
    
    my $h = $c->dbc->dbh->prepare($query);
    $h->execute();

    my @stocks;
    while (my ($id, $name) = $h->fetchrow_array()) { 
	push @results [ $id, $name ];
    }
    return \@results;

}
	    

sub get_type_id { 
    my $self = shift;
    my $c = shift;
    my $term = shift;
    $q = "SELECT projectprop.type_id FROM projectprop JOIN cvterm on (projectprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='$term'";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}
    

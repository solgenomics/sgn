
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


    my $req_data   = $c->req->param("req_data");

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


    # another idea: one could use temp tables to store the data in a more accessible format...
    # $dbh->do("CREATE TEMP TABLE temp_project (temp_project_id bigint, name varchar(255))");
    # $dbh->do("CREATE TEMP TABLE temp_year    (temp_year_id bigint, year varchar(20))");
    # $dbh->do("CREATE TEMP TABLE temp_location(temp_location_id bigint, description varchar(255))");
    # $dbh->do("CREATE TEMP TABLE temp_stock   (temp_stock_id 

    my $dbh = $c->dbc->dbh();
    my $q = "";  # get the primary requested data
    my $sq = ""; # the associated query to get all the stocks


    $q = "SELECT projectprop.type_id FROM projectprop JOIN cvterm on (projectprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='project year'";
    my $h = $dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();


    # if (!$select1 && !$select2 && !$select3) { 
    # 	#$sq = "SELECT stock_id FROM stock";	    
    # 	if ($select1 eq "project") { 
    # 	    $q = "SELECT project.project_id, project.name FROM project";
    # 	}
    # 	if ($select1 eq "year") { 
    # 	    $q = "SELECT value, value FROM projectprop 
    #               JOIN cvterm on (type_id=cvterm_id)
    #               WHERE cvterm.name='project year'";
    # 	}
    # 	if ($select1 eq "location") { 
    # 	    $q = "SELECT nd_geolocation.nd_geolocation_id, nd_geolocation.name FROM nd_geolocation";
    # 	}
    # }

    my $data_tainted = 0;
    foreach my $d ($c1_data, $c2_data, $c3_data) { 
	if ($d !~ /^[\d,]+$/g && defined($d)) { 
	    print STDERR "Illegal chars in $d\n";
	    $data_tainted =1;
	}
    }
    #if ($data_tainted) { $c->stash->{rest} = { error => "Data contains illegal characters" };return; }


    if ($select1 && !$select2 && !$select3) { 
	if ($select1 eq "project") { 
	    $q = "SELECT distinct(project.project_id), project.name FROM project order by project.name";
	}
	if ($select1 eq "year") { 
	    $q = "SELECT distinct(value), value FROM projectprop 
                   JOIN cvterm on (type_id=cvterm_id)
                   WHERE cvterm.name='project year' order by value";
	}
	if ($select1 eq "location") { 

	    $q = "SELECT nd_geolocation_id, description FROM nd_geolocation order by description";
	}
	
	
    }

    if ( ($select1 eq "project") && $select2 && !$select3) { 

	#$sq = "SELECT stock_id FROM stock order by stock.name"; # still report all the stocks

	if ($select2 eq "year") { 
	    $q = "SELECT distinct(projectprop.value), projectprop.value FROM project 
                  JOIN projectprop using(project_id) 
                  JOIN cvterm on (type_id=cvterm_id) 
                  WHERE cvterm.name='project year' and project_id in ($c1_data)  order by projectprop.value";
	    $sq ="SELECT distinct(stock_id), stock.uniquename FROM project 
                  JOIN projectprop using(project_id) 
                  JOIN cvterm on (type_id=cvterm_id) 
                  JOIN nd_experiment_project on (project.project_id=nd_experiment_project.project_id)
                  JOIN nd_experiment_stock USING (nd_experiment_id)
                  JOIN stock USING (stock_id) 
                  WHERE cvterm.name='project year' and project.project_id in ($c1_data)  order by stock.uniquename";
	}
	if ($select2 eq "location") { 
	    $q = "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM project 
                  JOIN nd_experiment_project using(project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id) 
                  WHERE project_id in ($c1_data) order by nd_geolocation.description"; 
	}
    }

    if ($select1 eq "year" && $select2  && !$select3) { 
	if ($select2 eq "location") { 
	    $q =  "SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM project 
                   JOIN projectprop using(project_id) 
                   JOIN nd_experiment_project USING(project_id) 
                   JOIN nd_experiment USING (nd_experiment_id) 
                   JOIN nd_geolocation using(nd_geolocation_id) 
                   WHERE projectprop.type_id=$type_id and projectprop.value in ($c1_data) order by nd_geolocation.description";

	    $sq = "SELECT distinct(stock_id), stock.uniquename FROM project 
                   JOIN projectprop using(project_id) 
                   JOIN nd_experiment_project USING(project_id) 
                   JOIN nd_experiment USING (nd_experiment_id) 
                   JOIN nd_geolocation using(nd_geolocation_id) 
                   JOIN nd_experiment_stock on(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id) 
                   JOIN stock using(stock_id) 
                   WHERE projectprop.type_id=$type_id and projectprop.value in ($c1_data) order by stock.uniquename";
	}

	if ($select2 eq "project") { 
	    $q = "SELECT distinct(project.project_id), project.name
                  FROM project join projectprop using(project_id) 
                  WHERE projectprop.value in ($c1_data) order by project.name";
	    $sq= "SELECT distinct(stock_id), stock.uniquename FROM project 
                  JOIN projectprop using(project_id) 
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment_stock using(nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and projectprop.value in ($c1_data) order by stock.uniquename";
	    
	}

    }

    if ($select1 eq "year" && $select2 eq "location" && $select3) { 
	if ($select3 eq "project") { 
	    $q = "SELECT distinct(project.project_id), project.name FROM projectprop 
                  JOIN project using(project_id) 
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id)
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id) WHERE projectprop.type_id=$type_id and projectprop.value in ($c1_data) order by project.name";
	    $sq= "SELECT distinct(stock.stock_id), stock.name FROM projectprop 
                  JOIN project using(project_id) 
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id)
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock on(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and projectprop.value in ($c1_data) and nd_geolocation.nd_geolocation_id in ($c2_data) order by stock.name";
	}	
    }

    if ($select1 eq "location" && $select2 && !$select3) { 

     	if ($select2 eq "year") { 
    	    $q = "SELECT distinct(projectprop.projectprop_id), projectprop.value FROM projectprop 
                  JOIN nd_experiment_project using(project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  WHERE projectprop.type_id=$type_id and nd_geolocation.nd_geolocation_id in ($c1_data) order by projectprop.value";

    	    $sq= "SELECT distinct(stock.stock_id), stock.uniquename FROM projectprop
                  JOIN nd_experiment_project using(project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock on (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and nd_geolocation.nd_geolocation_id in ($c1_data) order by stock.uniquename";
    	}

    	if ($select2 eq "project") { 
    	    $q = "SELECT distinct(project.project_id), project.name FROM project 
                  JOIN nd_experiment_project using(project_id)
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  WHERE nd_geolocation.nd_geolocation_id in ($c1_data) order by project.name";

    	    $sq="SELECT distinct(stock.stock_id), stock.uniquename FROM project 
                  JOIN nd_experiment_project using(project_id)
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock ON (nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE nd_geolocation.nd_geolocation_id in ($c1_data) order by stock.uniquename";
    	}

    }

    # third possibility: location, project and year. location year and project. 
    #                    project, location and year. project year, location
    #                    year, project, location. year, location, project

    my $c3_data_clause = "";
    if ($c3_data) { 
	if ($select3 eq "year") { $c3_data_clause = " and projectprop.value in ($c3_data) "; }
	if ($select3 eq "project") { $c3_data_clause = " and project.project_id in ($c3_data) "; }
	if ($select3 eq "location") { $c3_data_clause = " and nd_geolocation.nd_geolocation_id in ($c3_data) "; }
    }

    if (($select1 eq "location") && ($select2 eq "project") && $select3) { 
	if ($select3 eq "year") {
	    $q = "SELECT  distinct(projectprop.value), projectprop.value FROM project 
                  JOIN projectprop USING(project_id)
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  WHERE projectprop.type_id=$type_id and nd_geolocation.nd_geolocation_id in ($c1_data) and project.project_id in ($c2_data)  order by projectprop.value";

	    $sq= "SELECT distinct(stock.stock_id), stock.uniquename FROM project
                  JOIN projectprop using (project_id)
                  JOIN nd_experiment_project on(nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock on (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and nd_geolocation.nd_geolocation_id in ($c1_data) and project.project_id in ($c2_data) $c3_data_clause  order by stock.uniquename";
	    
	}
    }

    if (($select1 eq "location") && ($select2 eq "year") && $select3) { 
	if ($select3 eq "project") { 
	    $q = "SELECT  distinct(project.project_id), project.name FROM project 
                  JOIN projectprop USING (project_id)
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  WHERE projectprop.type_id=$type_id and nd_geolocation.nd_geolocation_id in ($c1_data) and projectprop.value  in ($c2_data) order by project.name";
	    
	    $sq= "SELECT distinct(stock.stock_id), stock.uniquename FROM projectprop
                  JOIN project using (project_id)
                  JOIN nd_experiment_project on(nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock on (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and nd_geolocation.nd_geolocation_id in ($c1_data) and projectprop.value in ($c2_data) $c3_data_clause order by stock.uniquename";
	}	    
    }   

    if (($select1 eq "project") && ($select2 eq "location") && $select3) { 
	if ($select3 eq "year") { 
	    $q = "SELECT  distinct(projectprop.value), projectprop.value FROM project 
                  JOIN projectprop USING(project_id)
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  WHERE projectprop.type_id=$type_id and project.project_id in ($c1_data) and nd_geolocation.nd_geolocation_id in ($c2_data) ";
	    
	    $sq= "SELECT distinct(stock.stock_id), stock.uniquename FROM projectprop
                  JOIN project using (project_id)
                  JOIN nd_experiment_project on(nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock on (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and project.project_id in ($c1_data) and nd_geolocation.nd_geolocation_id in ($c2_data) $c3_data_clause order by stock.uniquename";
	}	    
    }   

    if (($select1 eq "year") && ($select2 eq "project") && $select3) { 
	if ($select3 eq "location") { 

	    ##MODIFY
	    $q = "SELECT  distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM project 
                  JOIN projectprop USING(project_id)
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  WHERE projectprop.type_id=$type_id and project.project_id in ($c1_data) and projectprop.value in ($c2_data) order by nd_geolocation.description ";
	    
	    ##MODIFY
	    $sq= "SELECT distinct(stock.stock_id), stock.uniquename FROM project
                  JOIN projectprop using (project_id)
                  JOIN nd_experiment_project on(nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock on (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and project.project_id in ($c1_data) and projectprop.value in ($c2_data) order by stock.uniquename";
	}	    
    }   

    if (($select1 eq "year") && ($select2 eq "location") && $select3) { 
	if ($select3 eq "project") { 
	    ## MODIFY
	    $q = "SELECT  distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description FROM project 
                  JOIN projectprop USING(project_id)
                  JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  WHERE projectprop.type_id=$type_id and project.project_id in ($c1_data) and projectprop.value in ($c2_data) order by nd_geolocation.description ";
	    
	    ##MODIFY
	    $sq= "SELECT distinct(stock.stock_id), stock.uniquename FROM project
                  JOIN projectprop using (project_id)
                  JOIN nd_experiment_project on(nd_experiment_project.project_id=project.project_id) 
                  JOIN nd_experiment using(nd_experiment_id) 
                  JOIN nd_geolocation using(nd_geolocation_id)
                  JOIN nd_experiment_stock on (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
                  JOIN stock using(stock_id)
                  WHERE projectprop.type_id=$type_id and project.project_id in ($c1_data) and projectprop.value in ($c2_data) order by stock.uniquename";
	}	    
    

    print STDERR "Q: $q\n\n";

    my @list = ();
    $h = $dbh->prepare($q);
    $h->execute();
    while (my ($id, $name) = $h->fetchrow_array()) { 
	push @list, [ $id, $name ];
    }

  print STDERR "SQ: $sq\n\n";
    my @stocks = ();
    if ($sq) { 
	$h = $dbh->prepare($sq);
	$h->execute();
	while (my ($id, $name) = $h->fetchrow_array()) { 
	    push @stocks, [ $id, $name ];
	}
    }

    my $response = { list => \@list, 
		  stocks    => \@stocks,
    };

    $c->stash->{rest} = $response;
    

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

sub get_year_union { 

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
    
    

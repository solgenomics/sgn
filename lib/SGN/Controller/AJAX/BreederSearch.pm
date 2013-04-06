
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

    my $criterion1 = $c->req->param("criterion1");
    my $criterion2 = $c->req->param("criterion2");
    my $criterion3 = $c->req->param("criterion3");

    my $c1_data    = $c->req->param("c1_data");
    my $c2_data    = $c->req->param("c2_data");
    my $c3_data    = $c->req->param("c3_data");

    my $req_data   = $c->req->param("req_data");

    my $stocks = undef;

    my $error = "";

    foreach $criterion ($criterion1, $criterion2, $criterion3) { 
	if (any $criterion { $criterion eq $_ } qw | program year location |) { 
	    $error = "Valid keys are program, year, and location";
	    $c->stash->{rest} = { error => $error };
	    return;
	}
    }

    my $dbh = $c->dbic->dbh();
    my $q = "";  # get the primary requested data
    my $sq = ""; # the associated query to get all the stocks

    if (!$criterion1 && !$criterion2 && !$criterion3) { 
	$sq = "SELECT stock_id FROM stock";	    
	if ($req_data eq "program") { 
	    $q = "SELECT project.name FROM project";
	}
	if ($req_data eq "year") { 
	    $q = "SELECT distinct(value) FROM projectprop JOIN cvterm on (type_id=cvterm_id) where cvterm.name='project year'";
	}
	if ($req_data eq "location") { 
	    $q = "SELECT distinct(description) from nd.geolocation";
	}
    }

    if ($criterion1 eq "program" && !$criterion2 && !$criterion3) { 

	$sq = "SELECT stock_id FROM stock order by stock.name"; # still report all the stocks

	if ($req_data eq "year") { 
	    $q = "SELECT distinct(value) FROM project join projectprop using(project_id) JOIN cvterm on (type_id=cvterm_id) where cvterm.name='project year' and project_id in (?) order by projectprop.value";
	}
	if ($req_data eq "location") { 
	    $q = "SELECT distinct(nd_geolocation.nd_geolocation_id, nd_geolocation.description) FROM project join nd_experiment_project using(project_id) join nd_experiment using(nd_experiment_id) join nd_geolocation using(nd_geolocation_id) WHERE project_id in (?)";   
	}
    }

    $dbh->do("CREATE TEMP TABLE temp_project (temp_project_id bigint, name varchar(255))");
    $dbh->do("CREATE TEMP TABLE temp_year    (temp_year_id bigint, year varchar(20))");
    $dbh->do("CREATE TEMP TABLE temp_location(temp_location_id bigint, description varchar(255))");
    $dbh->do("CREATE TEMP TABLE temp_stock   (temp_stock_id 


    if ($criterion1 eq "program" && $criterion2 eq "location" && !$criterion3) { 

	if ($req_data eq "year") { 
	    $q = "SELECT distinct(projectprop.value) FROM project join projectprop using(project_id) JOIN nd_experiment_project on (nd_experiment_project.project_id= project.project_id) join nd_experiment using(nd_experiment_id) join nd_geolocation using(nd_geolocation_id) WHERE projectprop.type_id=(SELECT cvterm_id as type_id FROM cvterm WHERE name='project year') and project.project_id in (?) and nd_geolocation.nd_geolocation_id in (?) group by nd_experiment.nd_experiment_id, projectprop.value";

	    $sq = "SELECT distinct(stock.stock_id, stock.name) FROM project join projectprop using(project_id) JOIN nd_experiment_project on (nd_experiment_project.project_id= project.project_id) join nd_experiment using(nd_experiment_id) join nd_geolocation using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock using(stock_id) WHERE project.project_id in (?) and nd_geolocation_id in (?) group by stock.stock_id, stock.name";
	}
    }


    if ($criterion1 eq "program" && $criterion2 eq "location" && $criterion3 eq "year") { 
	$q = "SELECT distinct(stock.stock_id, stock_name) FROM project join projectprop using(project_id) JOIN nd_experiment_project on (nd_experiment_project.project_id=project.project_id) join nd_experiment using(nd_experiment_id) join nd_geolocation using(nd_geolocation_id) JOIN nd_experiment_stock using(nd_experiment_id) JOIN stock using(stock_id) WHERE project.project_id in (?) and 
    }

    if ($criterion1 eq "year" && !$criterion2  && !$criterion3) { 
	if ($req_data eq "location") { 
	    
	}

	if ($req_data eq "program") { 
	    
	}

    }
    

    if ($criterion1 eq "year" && $criterion2 eq "location" && !$criterion3) { 
	if ($req_data eq "program") { 
	}
	
    }

    if ($criterion1 eq "year" && $criterion2 eq "location" && $criteria3 eq "program") { 

    }

    if ($criterion1 eq "location" && !$criterion2 && !$criterion3) { 

	if ($req_data eq "year") { 
	}

	if ($req_data eq "program") { 
	}

    }


    if ($criterion1 eq "location" && $criterion2 eq "year") { 

	if ($req_data eq "program") { 
	}

    }

    if ($criterion1 eq "location" && $criterion2 eq "location") { 
	if ($req_data eq "
	
    

    







}
    

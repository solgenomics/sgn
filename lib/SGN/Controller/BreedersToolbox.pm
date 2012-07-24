
package SGN::Controller::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';
BEGIN { extends 'Catalyst::Controller'; }


sub make_cross_form :Path("/stock/cross/new") :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/new_cross.mas';
    if ($c->user()) { 
      my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
      # get projects
      my @rows = $schema->resultset('Project::Project')->all();
      my @projects = ();
      foreach my $row (@rows) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
      }
      $c->stash->{project_list} = \@projects;
      @rows = $schema->resultset('NaturalDiversity::NdGeolocation')->all();
      my @locations = ();
      foreach my $row (@rows) {
	push @locations,  [ $row->nd_geolocation_id,$row->description ];
      }
      $c->stash->{locations} = \@locations;

    }
    else {
      $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
      return;
    }
}


sub make_cross :Path("/stock/cross/generate") :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/progeny_from_crosses.mas';
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $c->req->param('cross_name');
    $c->stash->{cross_name} = $cross_name;
    my $trial_id = $c->req->param('trial_id');
    $c->stash->{trial_id} = $trial_id;
    #my $location = $c->req->param('location_id');
    my $maternal = $c->req->param('maternal');
    my $paternal = $c->req->param('paternal');
    my $progeny_number = $c->req->param('progeny_number');
    #my $private_to_role = $c->req->param('private_to_role');
    #my $progeny_count = $c->req->param('progeny');

    
    # get ID for $maternal
    #my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    #eval { 
#	my $maternal_id = $schema->resultset('Stock::Stock')->search( { stock_name => $maternal })->first->stock_id();
	
#	my $paternal_id = $schema->resultset('Stock::Stock')->search( { stock_name => $paternal })->first->stock_id();
#    };


    my $organism = $schema->resultset("Organism::Organism")->find_or_create(
    {
	genus   => 'Manihot',
	species => 'Manihot esculenta',
    } );
    my $organism_id = $organism->organism_id();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });


    my $cross_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'cross',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'cross',
    });

    my $female_parent_stock = $schema->resultset("Stock::Stock")->find(
            { name       => $maternal,
            } );

    my $male_parent_stock = $schema->resultset("Stock::Stock")->find(
            { name       => $paternal,
            } );

      my $female_parent = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'female_parent',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'female_parent',
    });

      my $male_parent = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'male_parent',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'male_parent',
    });

    my $increment = 1;
    while ($increment < $progeny_number + 1) {
      my $stock_name = $cross_name."-".$increment;
      my $accession_stock = $schema->resultset("Stock::Stock")->find_or_create(
            { organism_id => $organism_id,
              name       => $stock_name,
              uniquename => $stock_name,
              type_id     => $accession_cvterm->cvterm_id,
            } );

      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $female_parent->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $female_parent_stock->stock_id(),
	 					  } );

      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $male_parent->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $male_parent_stock->stock_id(),
	 					  } );
      $increment++;

    }
    if ($@) { 
    }

    
    


}

sub insert_new_location : Path("/breeders/location/insert") : Args(0) { 
    my ($self, $c) = @_;
    
    my $description => $c->req->param("description");
    my $longitude => $c->req->param("longitude");
    my $latitude  => $c->req->param("latitude");


    if (! $c->user()) { # redirect
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $exists = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $description } )->count();

    if ($exists > 0) { 
	$c->res->body("The location \'$description\' already exists!");
	return;
    }

    my $new_row = $schema->resultset('NaturalDiversity::NdGeolocation')->new( { 
	description => $description,
	longitude => $longitude,
	latitude  => $latitude,
							      });

    $new_row->insert();

    $c->res->body("Everything OK\n");

   #$c->res->redirect( uri( path => '/breeders/home', query => { goto_url => $c->req->uri->path_query } ) );
    
}
    
     
sub breeder_home :Path("/breeders/home") Args(0) { 
    my ($self , $c) = @_;
    if ($c->user()) { 
	
	my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

	# get projects

	my @rows = $schema->resultset('Project::Project')->all();

	my @projects = ();
	foreach my $row (@rows) { 
	    push @projects, [ $row->project_id, $row->name, $row->description ];

	}

	$c->stash->{projects} = \@projects;


	

	#get crosses

	my $stockrel = $schema->resultset("Cv::Cvterm")->create_with(
	 { name   => 'cross',
	   cv     => 'stock relationship',
	   db     => 'null',
	   dbxref => 'cross',
	 });



	#my $stockrel_type_id = $schema->resultset('Cv::Cvterm')->search( { 'name'=>'cross' })->first->cvterm_id;

	@rows = $schema->resultset('Stock::StockRelationship')->search( {type_id => $stockrel->cvterm_id });

	my @stockrelationships = ();

	foreach my $row (@rows) {
	  push @stockrelationships, [$row->type_id];
	}

	push @stockrelationships, ["example"];
	
	$c->stash->{stockrelationships} = \@stockrelationships;

	# get locations

	@rows = $schema->resultset('NaturalDiversity::NdGeolocation')->all();

	my $type_id = $schema->resultset('Cv::Cvterm')->search( { 'name'=>'plot' })->first->cvterm_id;

	my @locations = ();
	foreach my $row (@rows) { 

	    
	    my $plot_count = "SELECT count(*) from stock join cvterm on(type_id=cvterm_id) join nd_experiment_stock using(stock_id) join nd_experiment using(nd_experiment_id)   where cvterm.name='plot' and nd_geolocation_id=?"; # and sp_person_id=?";
	    my $sh = $c->dbc->dbh->prepare($plot_count);
	    $sh->execute($row->nd_geolocation_id); #, $c->user->get_object->get_sp_person_id);
	    
	    my ($count) = $sh->fetchrow_array();

	    print STDERR "PLOTS: $count\n";

	    if ($count > 0) { 

		push @locations,  [ $row->nd_geolocation_id, 
				    $row->description,
				    $row->latitude,
				    $row->longitude,
				    $row->altitude,
				    $count, # number of experiments TBD
				
		];
	    }
	}

	$c->stash->{locations} = \@locations;





	$c->stash->{template} = '/breeders_toolbox/home.mas';
    }
    else {
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
      

    }
}

1;

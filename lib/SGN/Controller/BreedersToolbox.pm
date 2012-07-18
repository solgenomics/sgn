
package SGN::Controller::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';
BEGIN { extends 'Catalyst::Controller'; }


sub make_cross_form :Path("/stock/cross/new") :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/stock/cross.mas';
}

sub make_cross :Path("/stock/cross/generate") :Args(0) { 
    my ($self, $c) = @_;
    my $trial_id = $c->req->param('trial_id');
    my $location = $c->req->param('location_id');
    my $maternal = $c->req->param('maternal');
    my $paternal = $c->req->param('paternal');
    my $private_to_role = $c->req->param('private_to_role');
    my $progeny_count = $c->req->param('progeny');
    
    # get ID for $maternal
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    eval { 
	my $maternal_id = $schema->resultset('Stock::Stock')->search( { stock_name => $maternal })->first->stock_id();
	
	my $paternal_id = $schema->resultset('Stock::Stock')->search( { stock_name => $paternal })->first->stock_id();
    };
    if ($@) { 
    }
}

sub insert_new_location :Path("/breeders/location/insert") Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $params = $c->request->parameters();

    my $description = $params->{description};
    my $longitude = $params->{longitude};
    my $latitude  = $params->{latitude};

    if (! $c->user()) { # redirect
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $exists = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $description } )->count();



    if ($exists > 0) { 
	$c->res->body("The location - $description - already exists!");
	return;
    }

    my $new_row = $schema->resultset('NaturalDiversity::NdGeolocation')->new( 
	{ 
	    description => $description,
	    longitude   => $longitude,
	    latitude    => $latitude,
	});

    $new_row->insert();

    $c->res->redirect( uri( path => '/breeders/home', query => { goto_url => $c->req->uri->path_query } ) );
    
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
	    
	    #if ($count > 0) { 

		push @locations,  [ $row->nd_geolocation_id, 
				    $row->description,
				    $row->latitude,
				    $row->longitude,
				    $row->altitude,
				    $count, # number of experiments TBD
				
		];
	#}
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

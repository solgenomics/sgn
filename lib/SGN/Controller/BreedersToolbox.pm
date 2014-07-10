
package SGN::Controller::BreedersToolbox;

use Moose;

use Data::Dumper;

use CXGN::Trial::TrialLayout;
use URI::FromHash 'uri';

use CXGN::BreederSearch;
use SGN::Controller::AJAX::List;
use CXGN::List::Transform;
use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Accessions;

BEGIN { extends 'Catalyst::Controller'; }

sub manage_breeding_programs : Path("/breeders/manage_programs") :Args(0) { 
    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 
	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );

    my $breeding_programs = $projects->get_breeding_programs();
    
    $c->stash->{breeding_programs} = $breeding_programs;
    $c->stash->{user} = $c->user();

    $c->stash->{template} = '/breeders_toolbox/breeding_programs.mas';
    

}

sub manage_trials : Path("/breeders/trials") Args(0) { 
    my $self = shift;
    my $c = shift;
 
    if (!$c->user()) { 
	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );

    my $breeding_programs = $projects->get_breeding_programs();

    my %trials_by_breeding_project = ();

    foreach my $bp (@$breeding_programs) { 
	$trials_by_breeding_project{$bp->[1]}= $projects->get_trials_by_breeding_program($bp->[0]);
    }

    $trials_by_breeding_project{'Other'} = $projects->get_trials_by_breeding_program();

    # locations are not needed for this page... (slow!!)
    $c->stash->{locations} = $self->get_all_locations($c);
   

    $c->stash->{trials_by_breeding_project} = \%trials_by_breeding_project; #$self->get_projects($c);

    $c->stash->{breeding_programs} = $breeding_programs;

    $c->stash->{template} = '/breeders_toolbox/manage_projects.mas';
}

sub manage_accessions : Path("/breeders/accessions") Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) { 	
	# redirect to login page
	#
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }

    my $ac = CXGN::BreedersToolbox::Accessions->new( { schema=>$schema });

    my $accessions = $ac->get_all_accessions($c);

    $c->stash->{accessions} = $accessions;

    $c->stash->{template} = '/breeders_toolbox/manage_accessions.mas';

}


sub manage_locations : Path("/breeders/locations") Args(0) { 
    my $self = shift;
    my $c = shift;
    
    if (!$c->user()) { 	
	
	# redirect to login page
	#
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $bp = CXGN::BreedersToolbox::Projects->new( { schema=>$schema });
    my $breeding_programs = $bp->get_breeding_programs();
    my $locations = {};
    foreach my $b (@$breeding_programs) { 
	$locations->{$b->[1]} = $bp->get_locations_by_breeding_program($b->[0]);
    }
    $locations->{'Other'} = $bp->get_locations_by_breeding_program();

    $c->stash->{user_id} = $c->user()->get_object()->get_sp_person_id();
    
    $c->stash->{locations} = $locations;

    $c->stash->{template} = '/breeders_toolbox/manage_locations.mas';
}

sub manage_crosses : Path("/breeders/crosses") Args(0) { 
    my $self = shift;
    my $c = shift;
    
    if (!$c->user()) { 	
	
	# redirect to login page
	#
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $bp = CXGN::BreedersToolbox::Projects->new( { schema=>$schema });
    my $breeding_programs = $bp->get_breeding_programs();

    $c->stash->{user_id} = $c->user()->get_object()->get_sp_person_id();
    
    $c->stash->{locations} = $self->get_locations($c);

    #$c->stash->{projects} = $self->get_projects($c);

    $c->stash->{programs} = $breeding_programs;

    $c->stash->{roles} = $c->user()->roles();

    $c->stash->{cross_populations} = $self->get_crosses($c);

    $c->stash->{template} = '/breeders_toolbox/manage_crosses.mas';

}

sub manage_phenotyping :Path("/breeders/phenotyping") Args(0) { 
    my $self =shift;
    my $c = shift;
 
    if (!$c->user()) { 
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }

    my $data = $self->get_phenotyping_data($c);

    $c->stash->{phenotype_files} = $data->{file_info};
    $c->stash->{deleted_phenotype_files} = $data->{deleted_file_info};

    $c->stash->{template} = '/breeders_toolbox/manage_phenotyping.mas';
    

}


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
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $visible_to_role = $c->req->param('visible_to_role');
    
    if (! $c->user()) { # redirect
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }


    #check that progeny number is an integer less than maximum allowed
    my $maximum_progeny_number = 1000;
    if ((! $progeny_number =~ m/^\d+$/) or ($progeny_number > $maximum_progeny_number)){
      #redirect to error page?
      return;
    }

    #check that parent names are not blank
    if ($maternal eq "" or $paternal eq "") {
      return;
    }

    #check that parents exist in the database
    if (! $schema->resultset("Stock::Stock")->find({name=>$maternal,})){
      return;
    }
    if (! $schema->resultset("Stock::Stock")->find({name=>$paternal,})){
      return;
    }

    #check that cross name does not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$cross_name})){
      return;
    }

    #check that progeny do not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$prefix.$cross_name.$suffix."-1",})){
      return;
    }

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

#    my $population_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
#      { name   => 'member',
#      cv     => 'stock type',
#      db     => 'null',
#      dbxref => 'member',
#    });

    my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
      { name   => 'population',
    });

#    my $cross_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
#    { name   => 'cross',
#      cv     => 'stock relationship',
#      db     => 'null',
#      dbxref => 'cross',
#    });

    my $female_parent_stock = $schema->resultset("Stock::Stock")->find(
            { name       => $maternal,
            } );

    my $male_parent_stock = $schema->resultset("Stock::Stock")->find(
            { name       => $paternal,
            } );

    my $population_stock = $schema->resultset("Stock::Stock")->find_or_create(
            { organism_id => $organism_id,
	      name       => $cross_name,
	      uniquename => $cross_name,
	      type_id => $population_cvterm->cvterm_id,
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

      my $population_members = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'cross_name',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'cross_name',
    });

      my $visible_to_role_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'visible_to_role',
      cv => 'local',
      db => 'null',
    });

    my $increment = 1;
    while ($increment < $progeny_number + 1) {
	$increment = sprintf "%03d", $increment;
	my $stock_name = $prefix.$cross_name."_".$increment.$suffix;
      my $accession_stock = $schema->resultset("Stock::Stock")->create(
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
      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $population_members->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $population_stock->stock_id(),
	 					  } );
      if ($visible_to_role ne "") {
	my $accession_stock_prop = $schema->resultset("Stock::Stockprop")->find_or_create(
	       { type_id =>$visible_to_role_cvterm->cvterm_id(),
		 value => $visible_to_role,
		 stock_id => $accession_stock->stock_id()
		 });
      }
      $increment++;

    }
    if ($@) { 
    }
}



    
sub breeder_home :Path("/breeders/home") Args(0) { 
    my ($self , $c) = @_;

    
    if (!$c->user()) { 
	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $bp = CXGN::BreedersToolbox::Projects->new( { schema=>$schema });
    my $breeding_programs = $bp->get_breeding_programs();

    $c->stash->{programs} = $breeding_programs;
    $c->stash->{breeding_programs} = $breeding_programs;
    
    my $locations_by_breeding_program;
    foreach my $b (@$breeding_programs) { 
        $locations_by_breeding_program->{$b->[1]} = $bp->get_locations_by_breeding_program($b->[0]);
    }
    $locations_by_breeding_program->{'Other'} = $bp->get_locations_by_breeding_program();

    $c->stash->{locations_by_breeding_program} = $locations_by_breeding_program;
    
    # get roles
    #
    my @roles = $c->user->roles();
    $c->stash->{roles}=\@roles;

    $c->stash->{cross_populations} = $self->get_crosses($c);

    $c->stash->{stockrelationships} = $self->get_stock_relationships($c);

    my $locations = $self->get_locations($c);
    
    $c->stash->{locations} = $locations;
    # get uploaded phenotype files
    #

    my $data = $self->get_phenotyping_data($c);

    $c->stash->{phenotype_files} = $data->{file_info};
    $c->stash->{deleted_phenotype_files} = $data->{deleted_file_info};

    
    $c->stash->{template} = '/breeders_toolbox/home.mas';
}


sub breeder_search : Path('/breeders/search/') :Args(0) { 
    my ($self, $c) = @_;
    
    $c->stash->{template} = '/breeders_toolbox/breeder_search_page.mas';

}


sub get_locations : Private { 
    my $self = shift;
    my $c= shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my @rows = $schema->resultset('NaturalDiversity::NdGeolocation')->all();
    
    my $type_id = $schema->resultset('Cv::Cvterm')->search( { 'name'=>'plot' })->first->cvterm_id;

    
    my @locations = ();
    foreach my $row (@rows) { 	    
	my $plot_count = "SELECT count(*) from stock join cvterm on(type_id=cvterm_id) join nd_experiment_stock using(stock_id) join nd_experiment using(nd_experiment_id)   where cvterm.name='plot' and nd_geolocation_id=?"; # and sp_person_id=?";
	my $sh = $c->dbc->dbh->prepare($plot_count);
	$sh->execute($row->nd_geolocation_id); #, $c->user->get_object->get_sp_person_id);
	
	my ($count) = $sh->fetchrow_array();
	
	#if ($count > 0) { 
	
		push @locations,  [ $row->nd_geolocation_id, 
				    $row->description,
				    $row->latitude,
				    $row->longitude,
				    $row->altitude,
				    $count, # number of experiments TBD
				    
		];
    }
    return \@locations;

}

sub get_all_locations { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $rs = $schema -> resultset("NaturalDiversity::NdGeolocation")->search( {} );
    
    my @locations = ();
    foreach my $loc ($rs->all()) { 
	push @locations, [ $loc->nd_geolocation_id(), $loc->description() ];
    }
    return \@locations;

}

# sub get_projects : Private { 
#     my $self = shift;
#     my $c = shift;

#     my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    

#    # get breeding programs
#     #

#     my $bp_rows = ();
#     # get projects
#     #
#     my @projects = ();
#     foreach my $bp (@bp_rows) { 
# 	my @project_rows = $schema->resultset('Project::Project')->search( { }, { join => 'project_relationship', { join => 'project' }}) ;
	
	
# 	foreach my $row (@project_rows) { 
# 	    push @projects, [ $row->project_id, $row->name, $row->description ];
	    
# 	}
#     }
#     return \@projects;
# }

sub get_crosses : Private { 
    my $self = shift;
    my $c = shift;
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    # get crosses
    #
    my $cross_cvterm = $schema->resultset("Cv::Cvterm")->find(
	{ name   => 'cross',
	});
    my @cross_populations = ();

    if ($cross_cvterm) {

      my @cross_population_stocks = $schema->resultset("Stock::Stock")->search(
									       { type_id => $cross_cvterm->cvterm_id, is_obsolete => 'f'
									       } );
      foreach my $cross_pop (@cross_population_stocks) {
	push @cross_populations, [$cross_pop->name,$cross_pop->stock_id];
      }
    }
    return  \@cross_populations;
}


sub get_stock_relationships : Private { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $stockrel = $schema->resultset("Cv::Cvterm")->create_with(
	{ name   => 'cross',
	  cv     => 'stock relationship',
	  db     => 'null',
	  dbxref => 'cross',
	});
    
    
    
    #my $stockrel_type_id = $schema->resultset('Cv::Cvterm')->search( { 'name'=>'cross' })->first->cvterm_id;
    
    my @rows = $schema->resultset('Stock::StockRelationship')->search( {type_id => $stockrel->cvterm_id });
    
    my @stockrelationships = ();
    
	foreach my $row (@rows) {
	    push @stockrelationships, [$row->type_id];
	}

    push @stockrelationships, ["example"];
	
 return \@stockrelationships;
    
}

sub get_phenotyping_data : Private { 
    my $self = shift;
    my $c = shift;

    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    
    my $file_info = [];
    my $deleted_file_info = [];

     my $metadata_rs = $metadata_schema->resultset("MdMetadata")->search( { create_person_id => $c->user()->get_object->get_sp_person_id(), obsolete => 0 }, { order_by => 'create_date' } );

    print STDERR "RETRIEVED ".$metadata_rs->count()." METADATA ENTRIES...\n";

    while (my $md_row = ($metadata_rs->next())) { 
	my $file_rs = $metadata_schema->resultset("MdFiles")->search( { metadata_id => $md_row->metadata_id() } );
	
	if (!$md_row->obsolete) { 
	    while (my $file_row = $file_rs->next()) { 
		push @$file_info, { file_id => $file_row->file_id(),		                    
				    basename => $file_row->basename,
				    dirname  => $file_row->dirname,
				    file_type => $file_row->filetype,
				    md5checksum => $file_row->md5checksum,
				    create_date => $md_row->create_date,
		};
	    }
	}
	else { 
	    while (my $file_row = $file_rs->next()) { 
		push @$deleted_file_info, { file_id => $file_row->file_id(),
					    basename => $file_row->basename,
					    dirname => $file_row->dirname,
					    file_type => $file_row->filetype,
					    md5checksum => $file_row->md5checksum,
					    create_date => $md_row->create_date,
		};
	    }
	}
    }

    my $data = { phenotype_files => $file_info, 
		 deleted_phenotype_files => $deleted_file_info, 
    };
    return $data;
		 

}

sub manage_genotyping : Path("/breeders/genotyping") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );

    my $breeding_programs = $projects->get_breeding_programs();

    my %genotyping_trials_by_breeding_project = ();

    foreach my $bp (@$breeding_programs) {
	$genotyping_trials_by_breeding_project{$bp->[1]}= $projects->get_genotyping_trials_by_breeding_program($bp->[0]);
    }

    $genotyping_trials_by_breeding_project{'Other'} = $projects->get_genotyping_trials_by_breeding_program();

    $c->stash->{locations} = $self->get_locations($c);

    $c->stash->{genotyping_trials_by_breeding_project} = \%genotyping_trials_by_breeding_project; #$self->get_projects($c);

    $c->stash->{breeding_programs} = $breeding_programs;


    $c->stash->{template} = '/breeders_toolbox/manage_genotyping.mas';
}


1;

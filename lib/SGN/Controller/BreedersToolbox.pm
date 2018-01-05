
package SGN::Controller::BreedersToolbox;

use Moose;

use Data::Dumper;
use SGN::Controller::AJAX::List;
use CXGN::List::Transform;
use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Accessions;
use SGN::Model::Cvterm;
use URI::FromHash 'uri';
use Spreadsheet::WriteExcel;
use Spreadsheet::Read;
use File::Slurp qw | read_file |;
use File::Temp;
use CXGN::Trial::TrialLayout;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use File::Spec::Functions;
use CXGN::People::Roles;
use CXGN::Trial::TrialLayout;


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

    # use get_all_locations, as other calls for locations can be slow
    #
    $c->stash->{locations} = $projects->get_all_locations();

    $c->stash->{breeding_programs} = $breeding_programs;

    $c->stash->{template} = '/breeders_toolbox/manage_projects.mas';
}

sub manage_accessions : Path("/breeders/accessions") Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $list_id = $c->req->param('list_id') || ''; #If a list_id is given in the URL, then the add accessions process will automatically begin with that list.

    if (!$c->user()) {
	# redirect to login page
	#
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $ac = CXGN::BreedersToolbox::Accessions->new( { schema=>$schema });

    my $accessions = $ac->get_all_accessions($c);
    # my $populations = $ac->get_all_populations($c);

    my @editable_stock_props = split ',', $c->config->{editable_stock_props};
    my %editable_stock_props = map { $_=>1 } @editable_stock_props;

    $c->stash->{accessions} = $accessions;
    $c->stash->{list_id} = $list_id;
    #$c->stash->{population_groups} = $populations;
    $c->stash->{preferred_species} = $c->config->{preferred_species};
    $c->stash->{editable_stock_props} = \%editable_stock_props;
    $c->stash->{template} = '/breeders_toolbox/manage_accessions.mas';
}

sub manage_roles : Path("/breeders/manage_roles") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{is_curator} = $c->user->check_roles("curator");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
    my $breeding_programs = $person_roles->get_breeding_program_roles();

    $c->stash->{roles} = $breeding_programs;
    $c->stash->{template} = '/breeders_toolbox/manage_roles.mas';
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

    $c->assets->include('/static/css/leaflet.css');
    $c->assets->include('/static/css/leaflet.extra-markers.min.css');
    $c->assets->include('/static/css/esri-leaflet-geocoder.css');

    $c->stash->{user_id} = $c->user()->get_object()->get_sp_person_id();

    $c->stash->{template} = '/breeders_toolbox/manage_locations.mas';
}

sub manage_nurseries : Path("/breeders/nurseries") Args(0) {
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

    $c->stash->{locations} = $bp->get_all_locations($c);

    #$c->stash->{projects} = $self->get_projects($c);

    $c->stash->{programs} = $breeding_programs;

    $c->stash->{roles} = $c->user()->roles();

    $c->stash->{nurseries} = $self->get_nurseries($c);

    $c->stash->{template} = '/breeders_toolbox/manage_nurseries.mas';

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

    $c->stash->{locations} = $bp->get_all_locations($c);

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

    $c->stash->{phenotype_files} = $data->{phenotype_files};
    $c->stash->{deleted_phenotype_files} = $data->{deleted_phenotype_files};

    $c->stash->{template} = '/breeders_toolbox/manage_phenotyping.mas';

}

sub manage_upload :Path("/breeders/upload") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );
    my $breeding_programs = $projects->get_breeding_programs();
    $c->stash->{locations} = $projects->get_all_locations();
    $c->stash->{breeding_programs} = $breeding_programs;
    $c->stash->{timestamp} = localtime;
    $c->stash->{preferred_species} = $c->config->{preferred_species};
    $c->stash->{template} = '/breeders_toolbox/manage_upload.mas';
}

sub manage_plot_phenotyping :Path("/breeders/plot_phenotyping") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $stock_id = $c->req->param('stock_id');

    if (!$c->user()) {
	     $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	      return;
    }
    my $stock = $schema->resultset("Stock::Stock")->find( { stock_id=>$stock_id })->uniquename();

    $c->stash->{plot_name} = $stock;
    $c->stash->{stock_id} = $stock_id;
    $c->stash->{template} = '/breeders_toolbox/manage_plot_phenotyping.mas';

}

sub manage_trial_phenotyping :Path("/breeders/trial_phenotyping") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_id = $c->req->param('trial_id');

    if (!$c->user()) {
	     $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	      return;
    }
    my $project_name = $schema->resultset("Project::Project")->find( { project_id=>$trial_id })->name();

    $c->stash->{trial_name} = $project_name;
    $c->stash->{trial_id} = $trial_id;
    $c->stash->{template} = '/breeders_toolbox/manage_trial_phenotyping.mas';
}

sub manage_odk_data_collection :Path("/breeders/odk") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    $c->stash->{odk_crossing_data_service_name} = $c->config->{odk_crossing_data_service_name};
    $c->stash->{odk_crossing_data_service_url} = $c->config->{odk_crossing_data_service_url};
    $c->stash->{odk_phenotyping_data_service_name} = $c->config->{odk_phenotyping_data_service_name};
    $c->stash->{odk_phenotyping_data_service_url} = $c->config->{odk_phenotyping_data_service_url};
    $c->stash->{template} = '/breeders_toolbox/manage_odk_data_collection.mas';
}

sub manage_phenotyping_download : Path("/breeders/phenotyping/download") Args(1) {
    my $self =shift;
    my $c = shift;
    my $file_id = shift;

    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});
    my $file_destination =  catfile($file_row->dirname, $file_row->basename);
    #print STDERR "\n\n\nfile name:".$file_row->basename."\n";
    my $contents = read_file($file_destination);
    my $file_name = $file_row->basename;
    $c->res->content_type('Application/trt');
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
    $c->res->body($contents);
}

sub manage_phenotyping_view : Path("/breeders/phenotyping/view") Args(1) {
    my $self =shift;
    my $c = shift;
    my $file_id = shift;

    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});
    my $file_destination =  catfile($file_row->dirname, $file_row->basename);
    #print STDERR "\n\n\nfile name:".$file_row->basename."\n";
    my @contents = ReadData ($file_destination);
    #print STDERR Dumper \@contents;
    my $file_name = $file_row->basename;
    $c->stash->{file_content} = \@contents;
    $c->stash->{filename} = $file_name;
    $c->stash->{template} = '/breeders_toolbox/view_file.mas';
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

    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');

    my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
      { name   => 'population',
    });


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
      my $female_parent =  SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent',  'stock_relationship');

      my $male_parent =  SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship');


      my $population_members =  SGN::Model::Cvterm->get_cvterm_row($schema,  'cross_relationship','stock_relationship');


    my $visible_to_role_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema,  'visible_to_role', 'local');

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

sub selection_index : Path("/selection/index") :Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {

	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

#    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

  #  my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );

#    my $breeding_programs = $projects->get_breeding_programs();

  #  $c->stash->{breeding_programs} = $breeding_programs;
    $c->stash->{user} = $c->user();

    $c->stash->{template} = '/breeders_toolbox/selection_index.mas';


}


sub breeder_home :Path("/breeders/home") Args(0) {
    my ($self , $c) = @_;


    if (!$c->user()) {

	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    # my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    # my $bp = CXGN::BreedersToolbox::Projects->new( { schema=>$schema });
    # my $breeding_programs = $bp->get_breeding_programs();

    # $c->stash->{programs} = $breeding_programs;
    # $c->stash->{breeding_programs} = $breeding_programs;

    # # my $locations_by_breeding_program;
    # # foreach my $b (@$breeding_programs) {
    # #     $locations_by_breeding_program->{$b->[1]} = $bp->get_locations_by_breeding_program($b->[0]);
    # # }
    # # $locations_by_breeding_program->{'Other'} = $bp->get_locations_by_breeding_program();

    # $c->stash->{locations_by_breeding_program} = ""; #$locations_by_breeding_program;

    # # get roles
    # #
    # my @roles = $c->user->roles();
    # $c->stash->{roles}=\@roles;

    # $c->stash->{cross_populations} = $self->get_crosses($c);

    # $c->stash->{stockrelationships} = $self->get_stock_relationships($c);

    # my $locations = $bp->get_locations($c);

    # $c->stash->{locations} = $locations;
    # # get uploaded phenotype files
    # #

    # my $data = $self->get_phenotyping_data($c);

    # $c->stash->{phenotype_files} = $data->{file_info};
    # $c->stash->{deleted_phenotype_files} = $data->{deleted_file_info};


    $c->stash->{template} = '/breeders_toolbox/home.mas';
}


sub breeder_search : Path('/breeders/search/') :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{dataset_id} = $c->req->param('dataset_id');
    $c->stash->{template} = '/breeders_toolbox/breeder_search_page.mas';

}


sub get_crosses : Private {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    # get crosses
    #
    my $stock_type_cv = $schema->resultset("Cv::Cv")->find( {name=>'stock_type'});
    my $cross_cvterm = $schema->resultset("Cv::Cvterm")->find(
	{ name   => 'cross',
	  cv_id => $stock_type_cv->cv_id(),
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



sub get_phenotyping_data : Private {
    my $self = shift;
    my $c = shift;

    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");

    my $file_info = [];
    my $deleted_file_info = [];

     my $metadata_rs = $metadata_schema->resultset("MdMetadata")->search( { create_person_id => $c->user()->get_object->get_sp_person_id() }, { order_by => 'create_date' } );

    print STDERR "RETRIEVED ".$metadata_rs->count()." METADATA ENTRIES...\n";

    while (my $md_row = ($metadata_rs->next())) {
	my $file_rs = $metadata_schema->resultset("MdFiles")->search( { metadata_id => $md_row->metadata_id(), filetype => {'!=' => 'document_browser'} } );

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

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );

    my $breeding_programs = $projects->get_breeding_programs();

    my %genotyping_trials_by_breeding_project = ();

    foreach my $bp (@$breeding_programs) {
	$genotyping_trials_by_breeding_project{$bp->[1]}= $projects->get_genotyping_trials_by_breeding_program($bp->[0]);
    }

    $genotyping_trials_by_breeding_project{'Other'} = $projects->get_genotyping_trials_by_breeding_program();

    $c->stash->{locations} = $projects->get_all_locations($c);

    $c->stash->{genotyping_trials_by_breeding_project} = \%genotyping_trials_by_breeding_project;

    $c->stash->{breeding_programs} = $breeding_programs;


    $c->stash->{template} = '/breeders_toolbox/manage_genotyping.mas';
}


1;

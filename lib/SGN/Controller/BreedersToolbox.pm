
package SGN::Controller::BreedersToolbox;

use Moose;

use CXGN::Trial::TrialLayout;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller'; }

sub trials : Path("/breeders/trials") Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    
    # get projects
    #
    my @rows = $schema->resultset('Project::Project')->all();
    
    my @projects = ();
    foreach my $row (@rows) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
	
    }
    
    $c->stash->{projects} = \@projects;

    $c->stash->{template} = '/breeders_toolbox/projects.mas';



}



    
sub breeder_home :Path("/breeders/home") Args(0) { 
    my ($self , $c) = @_;

    
    if (!$c->user()) { 
	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    
    # get projects
    #
    my @rows = $schema->resultset('Project::Project')->all();
    
    my @projects = ();
    foreach my $row (@rows) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
	
    }
    
    $c->stash->{projects} = \@projects;
    
    # get roles
    #
    my @roles = $c->user->roles();
    $c->stash->{roles}=\@roles;

    # get crosses
    #
    my $cross_cvterm = $schema->resultset("Cv::Cvterm")->find(
	{ name   => 'cross',
	});
    my @cross_populations = ();

    if ($cross_cvterm) {

      my @cross_population_stocks = $schema->resultset("Stock::Stock")->search(
									       { type_id => $cross_cvterm->cvterm_id,
									       } );
      foreach my $cross_pop (@cross_population_stocks) {
	push @cross_populations, [$cross_pop->name,$cross_pop->stock_id];
      }
    }

    $c->stash->{cross_populations} = \@cross_populations;

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
    #
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
    }
    
    # get uploaded phenotype files
    #
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    
    my $file_info = [];
    my $deleted_file_info = [];

    my $metadata_rs = $metadata_schema->resultset("MdMetadata")->search( { create_person_id => $c->user()->get_object->get_sp_person_id(), obsolete => 0 }, { order_by => 'create_date' } );

    while (my $md_row = ($metadata_rs->next())) { 
	my $file_rs = $metadata_schema->resultset("MdFiles")->search( { metadata_id => $md_row->metadata_id() } );
	
	if (!$md_row->obsolete) { 
	    while (my $file_row = $file_rs->next()) { 
		push @$file_info, { basename => $file_row->basename,
				    dirname  => $file_row->dirname,
				    file_type => $file_row->filetype,
				    md5checksum => $file_row->md5checksum,
				    create_date => $md_row->create_date,
		};
	    }
	}
	else { 
	    while (my $file_row = $file_rs->next()) { 
		push @$deleted_file_info, { basename => $file_row->basename,
					    dirname => $file_row->dirname,
					    file_type => $file_row->filetype,
					    md5checksum => $file_row->md5checksum,
					    create_date => $md_row->create_date,
		};
	    }
	}
    }

    $c->stash->{phenotype_files} = $file_info;
    $c->stash->{deleted_phenotype_files} = $deleted_file_info;
    $c->stash->{locations} = \@locations;
    $c->stash->{template} = '/breeders_toolbox/home.mas';
}


sub breeder_search : Path('/breeder_search/') :Args(0) { 
    my ($self, $c) = @_;
    
    $c->stash->{template} = '/breeders_toolbox/breeder_search.mas';

}

# sub trial_info : Path('/breeders_toolbox/trial') Args(1) { 
#   my $self = shift;
#   my $c = shift;

#   my $trial_id = shift;
    

    
#   if (!$c->user()) { 
#     $c->stash->{template} = '/generic_message.mas';
#     $c->stash->{message}  = 'You must be logged in to access this page.';
#     return;
#   }
#   my $dbh = $c->dbc->dbh();
    
#   my $h = $dbh->prepare("SELECT project.name FROM project WHERE project_id=?");
#   $h->execute($trial_id);

#   my ($name) = $h->fetchrow_array();

#   $c->stash->{trial_name} = $name;

#   $h = $dbh->prepare("SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description, count(*) FROM nd_geolocation JOIN nd_experiment USING(nd_geolocation_id) JOIN nd_experiment_project USING (nd_experiment_id) JOIN project USING (project_id) WHERE project_id=? GROUP BY nd_geolocation_id, nd_geolocation.description");
#   $h->execute($trial_id);

#   my @location_data = ();
#   while (my ($id, $desc, $count) = $h->fetchrow_array()) { 
#     push @location_data, [$id, $desc, $count];
#   }		       

#   $c->stash->{location_data} = \@location_data;

#   $h = $dbh->prepare("SELECT distinct(cvterm.name), count(*) FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? GROUP BY cvterm.name");

#   $h->execute($trial_id);

#   my @phenotype_data;
#   while (my ($trait, $count) = $h->fetchrow_array()) { 
#     push @phenotype_data, [$trait, $count];
#   }
#   $c->stash->{phenotype_data} = \@phenotype_data;

#   $h = $dbh->prepare("SELECT distinct(projectprop.value) FROM projectprop WHERE project_id=? AND type_id=(SELECT cvterm_id FROM cvterm WHERE name='project year')");
#   $h->execute($trial_id);

#   my @years;
#   while (my ($year) = $h->fetchrow_array()) { 
#     push @years, $year;
#   }
    

#   $c->stash->{years} = \@years;

#   $c->stash->{plot_data} = [];

#   $c->stash->{template} = '/breeders_toolbox/trial.mas';
# }


1;


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
use CXGN::Genotype::Search;
use JSON::XS;
use CXGN::Trial;


BEGIN { extends 'Catalyst::Controller'; }

sub manage_breeding_programs : Path("/breeders/manage_programs") :Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {

	# redirect to login page
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );

    my @editable_stock_props = split ',', $c->config->{editable_stock_props};
    my %editable_stock_props = map { $_=>1 } @editable_stock_props;

    my @editable_stock_props_definitions = split ',', $c->config->{editable_stock_props_definitions};
    my %def_hash;
    foreach (@editable_stock_props_definitions) {
        my @term_def = split ':', $_;
        $def_hash{$term_def[0]} = $term_def[1];
    }

    my $breeding_programs = $projects->get_breeding_programs();
    my @breeding_programs = @$breeding_programs;
    my @roles = $c->user->roles();

    #Add true false field to breeding program array indicating whether program is linked to current user
    foreach my $role (@roles) {
        for (my $i=0; $i < scalar @breeding_programs; $i++) {
            if ($role eq $breeding_programs[$i][1]){
                $breeding_programs[$i][3] = 1;
            } else {
                $breeding_programs[$i][3] = 0;
            }
        }
    }

    #print STDERR "Breeding programs are ".Dumper(@breeding_programs);
    my $field_management_factors = $c->config->{management_factor_types};
    my @management_factor_types = split ',',$field_management_factors;

    my $design_type_string = $c->config->{design_types};
    my @design_types = split ',',$design_type_string;

    $c->stash->{design_types} = \@design_types;
    $c->stash->{management_factor_types} = \@management_factor_types;
    $c->stash->{editable_stock_props} = \%editable_stock_props;
    $c->stash->{editable_stock_props_definitions} = \%def_hash;
    $c->stash->{preferred_species} = $c->config->{preferred_species};
    $c->stash->{timestamp} = localtime;

    my $json = JSON::XS->new();
    my $locations = $json->decode($projects->get_all_locations_by_breeding_program());

    #print STDERR "Locations are ".Dumper($locations)."\n";

    $c->stash->{locations} = $locations;

    $c->stash->{breeding_programs} = \@breeding_programs;

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
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $ac = CXGN::BreedersToolbox::Accessions->new( { schema=>$schema });

    my $accessions = $ac->get_all_accessions($c);
    # my $populations = $ac->get_all_populations($c);

    my @editable_stock_props = split ',', $c->config->{editable_stock_props};
    my %editable_stock_props = map { $_=>1 } @editable_stock_props;

    my @editable_stock_props_definitions = split ',', $c->config->{editable_stock_props_definitions};
    my %def_hash;
    foreach (@editable_stock_props_definitions) {
        my @term_def = split ':', $_;
        $def_hash{$term_def[0]} = $term_def[1];
    }

    $c->stash->{accessions} = $accessions;
    $c->stash->{list_id} = $list_id;
    #$c->stash->{population_groups} = $populations;
    $c->stash->{preferred_species} = $c->config->{preferred_species};
    $c->stash->{editable_stock_props} = \%editable_stock_props;
    $c->stash->{editable_stock_props_definitions} = \%def_hash;
    $c->stash->{template} = '/breeders_toolbox/manage_accessions.mas';
}

sub manage_roles : Path("/breeders/manage_roles") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{is_curator} = $c->user->check_roles("curator");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
    my $ascii_chars = 1;
    my $breeding_programs = $person_roles->get_breeding_program_roles($ascii_chars);

    $c->stash->{roles} = $breeding_programs;
    $c->stash->{template} = '/breeders_toolbox/manage_roles.mas';
}

sub manage_tissue_samples : Path("/breeders/samples") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    my $genotyping_facilities = $c->config->{genotyping_facilities};
    my @facilities = split ',',$genotyping_facilities;

    my $sampling_facilities = $c->config->{sampling_facilities};
    my @sampling_facilities = split ',',$sampling_facilities;

    $c->stash->{facilities} = \@facilities;
    $c->stash->{sampling_facilities} = \@sampling_facilities;
    $c->stash->{user_id} = $c->user()->get_object()->get_sp_person_id();
    $c->stash->{template} = '/breeders_toolbox/manage_samples.mas';
}


sub manage_locations : Path("/breeders/locations") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {

	# redirect to login page
	#
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    $c->stash->{user_id} = $c->user()->get_object()->get_sp_person_id();

    $c->stash->{template} = '/breeders_toolbox/manage_locations.mas';
}

sub manage_nurseries : Path("/breeders/nurseries") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {

	# redirect to login page
	#
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $bp = CXGN::BreedersToolbox::Projects->new( { schema=>$schema });
    my $breeding_programs = $bp->get_breeding_programs();

    my $crossingtrial = CXGN::BreedersToolbox::Projects->new( { schema=>$schema });
    my $crossing_trials = $crossingtrial->get_crossing_trials();

    $c->stash->{user_id} = $c->user()->get_object()->get_sp_person_id();


    my @breeding_programs = @$breeding_programs;
    my @roles = $c->user->roles();

    foreach my $role (@roles) {
        for (my $i=0; $i < scalar @breeding_programs; $i++) {
            if ($role eq $breeding_programs[$i][1]){
                $breeding_programs[$i][3] = 1;
            } else {
                $breeding_programs[$i][3] = 0;
            }
        }
    }

    my $json = JSON::XS->new();
    my $locations = $json->decode($crossingtrial->get_all_locations_by_breeding_program());

    $c->stash->{locations} = $locations;

    $c->stash->{programs} = \@breeding_programs;

    #$c->stash->{locations} = $bp->get_all_locations($c);

    #$c->stash->{programs} = $breeding_programs;

    $c->stash->{crossing_trials} = $crossing_trials;

    $c->stash->{roles} = $c->user()->roles();

    $c->stash->{template} = '/breeders_toolbox/manage_crosses.mas';

}

sub manage_phenotyping :Path("/breeders/phenotyping") Args(0) {
    my $self =shift;
    my $c = shift;

    if (!$c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my @file_types = ( 'spreadsheet phenotype file', 'direct phenotyping', 'trial_additional_file_upload', 'brapi observations', 'tablet phenotype file' );
    my $data = $self->get_file_data($c, \@file_types);

    $c->stash->{phenotype_files} = $data->{files};
    $c->stash->{deleted_phenotype_files} = $data->{deleted_files};

    $c->stash->{template} = '/breeders_toolbox/manage_phenotyping.mas';

}

sub manage_nirs :Path("/breeders/nirs") Args(0) {
    my $self =shift;
    my $c = shift;

    if (!$c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my @file_types = ( 'nirs spreadsheet' );
    my $all_data = $self->get_file_data($c, \@file_types, 1);
    my $data = $self->get_file_data($c, \@file_types, 0);

    my $sampling_facilities = $c->config->{sampling_facilities};
    my @sampling_facilities = split ',',$sampling_facilities;

    $c->stash->{sampling_facilities} = \@sampling_facilities;
    $c->stash->{nirs_files} = $data->{files};
    $c->stash->{deleted_nirs_files} = $data->{deleted_files};
    $c->stash->{all_nirs_files} = $all_data->{files};
    $c->stash->{all_deleted_nirs_files} = $all_data->{deleted_files};

    $c->stash->{template} = '/breeders_toolbox/manage_nirs.mas';

}

sub manage_sequence_metadata :Path("/breeders/sequence_metadata") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	    $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	    return;
    }

    $c->stash->{template} = '/breeders_toolbox/manage_sequence_metadata.mas';
}

sub manage_upload :Path("/breeders/upload") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my @editable_stock_props = split ',', $c->config->{editable_stock_props};
    my %editable_stock_props = map { $_=>1 } @editable_stock_props;

    my @editable_stock_props_definitions = split ',', $c->config->{editable_stock_props_definitions};
    my %def_hash;
    foreach (@editable_stock_props_definitions) {
        my @term_def = split ':', $_;
        $def_hash{$term_def[0]} = $term_def[1];
    }

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );
    my $breeding_programs = $projects->get_breeding_programs();

    my $genotyping_facilities = $c->config->{genotyping_facilities};
    my @facilities = split ',',$genotyping_facilities;

    my $json = JSON::XS->new();

    my $field_management_factors = $c->config->{management_factor_types};
    my @management_factor_types = split ',',$field_management_factors;

    my $design_type_string = $c->config->{design_types};
    my @design_types = split ',',$design_type_string;

    $c->stash->{editable_stock_props} = \%editable_stock_props;
    $c->stash->{editable_stock_props_definitions} = \%def_hash;
    $c->stash->{design_types} = \@design_types;
    $c->stash->{management_factor_types} = \@management_factor_types;
    $c->stash->{facilities} = \@facilities;
    $c->stash->{geojson_locations} = $json->decode($projects->get_all_locations_by_breeding_program());
    $c->stash->{locations} = $projects->get_all_locations();
    $c->stash->{breeding_programs} = $breeding_programs;
    $c->stash->{timestamp} = localtime;
    $c->stash->{preferred_species} = $c->config->{preferred_species};
    $c->stash->{template} = '/breeders_toolbox/manage_upload.mas';
}

sub manage_file_share_dump :Path("/breeders/file_share_dump") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{template} = '/breeders_toolbox/file_share/manage_file_share_dump.mas';
}

sub manage_plot_phenotyping :Path("/breeders/plot_phenotyping") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $stock_id = $c->req->param('stock_id');

    if (!$c->user()) {
	     $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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
	     $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	      return;
    }
    my $project_name = $schema->resultset("Project::Project")->find( { project_id=>$trial_id })->name();

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });

    $c->stash->{trial_stock_type} = $trial->get_trial_stock_type();
    $c->stash->{trial_name} = $project_name;
    $c->stash->{trial_id} = $trial_id;
    $c->stash->{template} = '/breeders_toolbox/manage_trial_phenotyping.mas';
}

sub manage_odk_data_collection :Path("/breeders/odk") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    $c->stash->{odk_crossing_data_service_name} = $c->config->{odk_crossing_data_service_name};
    $c->stash->{odk_crossing_data_service_url} = $c->config->{odk_crossing_data_service_url};
    $c->stash->{odk_crossing_data_test_form_name} = $c->config->{odk_crossing_data_test_form_name};
    $c->stash->{odk_phenotyping_data_service_name} = $c->config->{odk_phenotyping_data_service_name};
    $c->stash->{odk_phenotyping_data_service_url} = $c->config->{odk_phenotyping_data_service_url};
    $c->stash->{template} = '/breeders_toolbox/manage_odk_data_collection.mas';
}


sub manage_identifier_generation :Path("/breeders/identifier_generation") Args(0) {
    my $self =shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    $c->stash->{template} = '/breeders_toolbox/identifier_generation/manage_identifier_generation.mas';
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
      $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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

    # $c->stash->{stockrelationships} = $self->get_stock_relationships($c);

    # my $locations = $bp->get_locations($c);

    # $c->stash->{locations} = $locations;
    # # get uploaded phenotype files
    # #

    # my $data = $self->get_file_data($c, \@file_types);

    # $c->stash->{phenotype_files} = $data->{file_info};
    # $c->stash->{deleted_phenotype_files} = $data->{deleted_file_info};


    $c->stash->{template} = '/breeders_toolbox/home.mas';
}

sub breeder_search : Path('/breeders/search/') :Args(0) {
    my ($self, $c) = @_;

    if (!$c->user()) {
    	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    	return;
    }

    $c->stash->{dataset_id} = $c->req->param('dataset_id');
    $c->stash->{template} = '/breeders_toolbox/breeder_search_page.mas';

}
sub get_file_data : Private {
    my $self = shift;
    my $c = shift;
    my $file_types = shift;
    my $get_files_for_all_users = shift;
    my $file_type_string = "'".join("','", @$file_types)."'";

    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");

    my $file_info = [];
    my $deleted_file_info = [];

    my $where_string = '';
    if (!$get_files_for_all_users) {
        $where_string = ' AND md.create_person_id = '.$c->user()->get_object->get_sp_person_id();
    }

    my $q = "SELECT mdf.file_id, mdf.basename, mdf.dirname, mdf.filetype, mdf.md5checksum, md.create_date, md.obsolete
        FROM metadata.md_files AS mdf
        JOIN metadata.md_metadata AS md ON (mdf.metadata_id = md.metadata_id)
        WHERE mdf.filetype IN ($file_type_string) $where_string;";
    print STDERR $q."\n";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    while (my ($file_id, $basename, $dirname, $filetype, $md5, $create_date, $obsolete) = $h->fetchrow_array()) {
        if (!$obsolete) {
            push @$file_info, {
                file_id => $file_id,
                basename => $basename,
                dirname  => $dirname,
                file_type => $filetype,
                md5checksum => $md5,
                create_date => $create_date
            };
        }
        else {
            push @$deleted_file_info, {
                file_id => $file_id,
                basename => $basename,
                dirname  => $dirname,
                file_type => $filetype,
                md5checksum => $md5,
                create_date => $create_date
            };
        }
    }

    my $data = {
        files => $file_info,
        deleted_files => $deleted_file_info
    };
    return $data;
}


sub manage_genotyping : Path("/breeders/genotyping") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	# redirect to login page
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
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

    my $genotyping_facilities = $c->config->{genotyping_facilities};
    my @facilities = split ',',$genotyping_facilities;

    $c->stash->{locations} = $projects->get_all_locations($c);

    $c->stash->{genotyping_trials_by_breeding_project} = \%genotyping_trials_by_breeding_project;

    $c->stash->{breeding_programs} = $breeding_programs;

    $c->stash->{facilities} = \@facilities;

    $c->stash->{template} = '/breeders_toolbox/manage_genotyping.mas';
}

sub manage_genotype_qc : Path("/breeders/genotype_qc") :Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        # redirect to login page
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    $c->stash->{template} = '/breeders_toolbox/manage_genotype_qc.mas';
}


sub manage_markers : Path("/breeders/markers") Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/breeders_toolbox/markers/manage_markers.mas';
}

sub manage_drone_imagery : Path("/breeders/drone_imagery") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        # redirect to login page
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    $c->stash->{template} = '/breeders_toolbox/manage_drone_imagery.mas';
}

1;

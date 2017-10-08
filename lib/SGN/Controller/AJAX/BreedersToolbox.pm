
package SGN::Controller::AJAX::BreedersToolbox;

use Moose;

use URI::FromHash 'uri';
use Data::Dumper;
use File::Slurp "read_file";

use CXGN::List;
use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Delete;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Stock::StockLookup;
use CXGN::Location;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub insert_new_project : Path("/ajax/breeders/project/insert") Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to add projects." } ;
	return;
    }

    my $params = $c->req->parameters();

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $exists = $schema->resultset('Project::Project')->search(
	{ name => $params->{project_name} }
	);

    if ($exists > 0) {
	$c->stash->{rest} = { error => "This trial name is already used." };
	return;
    }


    my $project = $schema->resultset('Project::Project')->find_or_create(
	{
	    name => $params->{project_name},
	    description => $params->{project_description},
	}
	);

    my $projectprop_year = $project->create_projectprops( { 'project year' => $params->{year},}, {autocreate=>1}); #cv_name => 'project_property' } );



    $c->stash->{rest} = { error => '' };
}

sub get_breeding_programs : Path('/ajax/breeders/all_programs') Args(0) {
    my $self = shift;
    my $c = shift;

    my $po = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $breeding_programs = $po->get_breeding_programs();

    $c->stash->{rest} = $breeding_programs;
}

sub new_breeding_program :Path('/breeders/program/new') Args(0) {
    my $self = shift;
    my $c = shift;
    my $name = $c->req->param("name");
    my $desc = $c->req->param("desc");

    if (!($c->user() || $c->user()->check_roles('submitter'))) {
	$c->stash->{rest} = { error => 'You need to be logged in and have sufficient privileges to add a breeding program.' };
    }


    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $error = $p->new_breeding_program($name, $desc);

    if ($error) {
	$c->stash->{rest} = { error => $error };
    }
    else {
	$c->stash->{rest} =  {};
    }

}

sub delete_breeding_program :Path('/breeders/program/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $program_id = shift;

    if ($c->user && ($c->user->check_roles("curator"))) {
	my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });
	$p->delete_breeding_program($program_id);
	$c->stash->{rest} = [ 1 ];
    }
    else {
	$c->stash->{rest} = { error => "You don't have sufficient privileges to delete breeding programs." };
    }
}


sub get_breeding_programs_by_trial :Path('/breeders/programs_by_trial/') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );

    my $projects = $p->get_breeding_programs_by_trial($trial_id);

    $c->stash->{rest} =   { projects => $projects };

}

sub add_data_agreement :Path('/breeders/trial/add/data_agreement') Args(0) {
    my $self = shift;
    my $c = shift;

    my $project_id = $c->req->param('project_id');
    my $data_agreement = $c->req->param('text');

    if (!$c->user()) {
	$c->stash->{rest} = { error => 'You need to be logged in to add a data agreement' };
	return;
    }

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
	$c->stash->{rest} = { error => 'You do not have the required privileges to add a data agreement to this trial.' };
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $data_agreement_cvterm_id_rs = $schema->resultset('Cv::Cvterm')->search( { name => 'data_agreement' });

    my $type_id;
    if ($data_agreement_cvterm_id_rs->count>0) {
	$type_id = $data_agreement_cvterm_id_rs->first()->cvterm_id();
    }

    eval {
	my $project_rs = $schema->resultset('Project::Project')->search(
	    { project_id => $project_id }
	    );

	if ($project_rs->count() == 0) {
	    $c->stash->{rest} = { error => "No such project $project_id", };
	    return;
	}

	my $project = $project_rs->first();

	my $projectprop_rs = $schema->resultset("Project::Projectprop")->search( { 'project_id' => $project_id, 'type_id'=>$type_id });

	my $projectprop;
	if ($projectprop_rs->count() > 0) {
	    $projectprop = $projectprop_rs->first();
	    $projectprop->value($data_agreement);
	    $projectprop->update();
	    $c->stash->{rest} = { message => 'Updated data agreement.' };
	}
	else {
	    $projectprop = $project->create_projectprops( { 'data_agreement' => $data_agreement,}, {autocreate=>1});
	    $c->stash->{rest} = { message => 'Inserted new data agreement.'};
	}
    };
    if ($@) {
	$c->stash->{rest} = { error => $@ };
	return;
    }
}

sub get_data_agreement :Path('/breeders/trial/data_agreement/get') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $project_id = $c->req->param('project_id');

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $data_agreement_cvterm_id_rs = $schema->resultset('Cv::Cvterm')->search( { name => 'data_agreement' });

    if ($data_agreement_cvterm_id_rs->count() == 0) {
	$c->stash->{rest} = { error => "No data agreements have been added yet." };
	return;
    }

    my $type_id = $data_agreement_cvterm_id_rs->first()->cvterm_id();

    print STDERR "PROJECTID: $project_id TYPE_ID: $type_id\n";

    my $projectprop_rs = $schema->resultset('Project::Projectprop')->search(
	{ project_id => $project_id, type_id=>$type_id }
	);

    if ($projectprop_rs->count() == 0) {
	$c->stash->{rest} = { error => "No such project $project_id", };
	return;
    }
    my $projectprop = $projectprop_rs->first();
    $c->stash->{rest} = { prop_id => $projectprop->projectprop_id(), text => $projectprop->value() };

}

sub get_all_years : Path('/ajax/breeders/trial/all_years' ) Args(0) {
    my $self = shift;
    my $c = shift;

    my $bp = CXGN::BreedersToolbox::Projects->new({ schema => $c->dbic_schema("Bio::Chado::Schema") });
    my @years = $bp->get_all_years();

    $c->stash->{rest} = { years => \@years };
}

sub get_trial_location : Path('/ajax/breeders/trial/location') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $t = CXGN::Trial->new(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    trial_id => $trial_id
	});

    if ($t) {
	$c->stash->{rest} = { location => $t->get_location() };
    }
    else {
	$c->stash->{rest} = { error => "The trial with id $trial_id does not exist" };

    }
}

sub get_trial_type : Path('/ajax/breeders/trial/type') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $t = CXGN::Trial->new(
	{
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    trial_id => $trial_id
	});

    my $type = $t->get_project_type();
    $c->stash->{rest} = { type => $type };
}

sub get_all_trial_types : Path('/ajax/breeders/trial/alltypes') Args(0) {
    my $self = shift;
    my $c = shift;

    my @types = CXGN::Trial::get_all_project_types($c->dbic_schema("Bio::Chado::Schema"));

    $c->stash->{rest} = { types => \@types };
}

sub genotype_trial : Path('/ajax/breeders/genotypetrial') Args(0) {
    my $self = shift;
    my $c = shift;


    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
        $c->detach();
    }

    my $list_id = $c->req->param("list_id");
    my $name = $c->req->param("name");
    my $breeding_program_id = $c->req->param("breeding_program");
    my $description = $c->req->param("description");
    my $location_id = $c->req->param("location");
    my $year = $c->req->param("year");

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh(), list_id => $list_id });
    my $elements = $list->elements();

    if (!$name || !$list_id || !$breeding_program_id || !$location_id || !$year) {
        $c->stash->{rest} = { error => "Please provide all parameters." };
        $c->detach();
    }

    my $td = CXGN::Trial::TrialDesign->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    $td->set_stock_list($elements);

    $td->set_block_size(96);

    $td->set_design_type("genotyping_plate");
    $td->set_trial_name($name);
    my $design;

    eval {
        $td->calculate_design();
    };

    if ($@) {
        $c->stash->{rest} = { error => "Design failed. Error: $@" };
        $c->detach();
    }

    $design = $td->get_design();

    if (exists($design->{error})) {
        $c->stash->{rest} = $design;
        $c->detach();
    }
    #print STDERR Dumper($design);

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $location_id } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $breeding_program_id });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
        $c->detach();
    }


    my $ct = CXGN::Trial::TrialCreate->new( {
        chado_schema => $c->dbic_schema("Bio::Chado::Schema"),
        dbh => $c->dbc->dbh(),
        user_name => $c->user()->get_object()->get_username(), #not implemented
        trial_year => $year,
        trial_location => $location->description(),
        program => $breeding_program->name(),
        trial_description => $description,
        design_type => 'genotyping_plate',
        design => $design,
        trial_name => $name,
        is_genotyping => 1,
        operator => $c->user->get_object->get_username
    });

    my %message;
    my $error;
    try {
        %message = $ct->save_trial();
    } catch {
        $error = $_;
    };

    if ($message{'error'}) {
        $error = $message{'error'};
    }
    if ($error){
        $c->stash->{rest} = {error => "Error saving trial in the database: $error"};
        $c->detach();
    }

    $c->stash->{rest} = {
        message => "Successfully stored the trial.",
        trial_id => $message{trial_id},
    };
    #print STDERR Dumper(%message);
}


# this version of the genotype trial requires the upload of a file from the IGD
#
sub igd_genotype_trial : Path('/ajax/breeders/igdgenotypetrial') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = { error => 'You must be logged in to create a genotyping trial.' };
        $c->detach();
    }

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
        $c->detach();
    }
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $list_id = $c->req->param("list_id");
    #my $name = $c->req->param("name");
    my $breeding_program_id = $c->req->param("breeding_program");
    my $description = $c->req->param("description");
    my $location_id = $c->req->param("location");
    my $year = $c->req->param("year");
    my $upload = $c->req->upload('igd_genotyping_trial_upload_file');
    my $upload_tempfile  = $upload->tempname;
    my $upload_original_name = $upload->filename();
    my $upload_contents = read_file($upload_tempfile);

    print STDERR "Parsing IGD file...\n";

    my $p = CXGN::Trial::ParseUpload->new( { chado_schema => $schema, filename=>$upload_tempfile });
    $p->load_plugin("ParseIGDFile");

    my $meta = $p->parse();

    my $errors = $p->get_parse_errors();
    if (@{$errors->{'error_messages'}}) {
        $c->stash->{rest} = { error => "The file has the following problems: ".join ", ", @{$errors->{'error_messages'}}.". Please fix these problems and try again." };
        print STDERR "Parsing errors in uploaded file. Aborting. (".join ",", @{$errors->{'error_messages'}}.")\n";
        $c->detach();
    }
    print STDERR "Meta information from genotyping trial file: ".Dumper($meta);

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh(), list_id => $list_id });
    my $elements = $list->elements();

    print STDERR "PARAMS: $upload_original_name, $list_id, $breeding_program_id, $location_id, $year\n";
    if (!$upload_original_name || !$list_id || !$breeding_program_id || !$location_id || !$year) {
        $c->stash->{rest} = { error => "Please provide all parameters, including a file." };
        $c->detach();
    }

    print STDERR "Looking up stock names and converting to IGD accepted names...\n";

    my $slu = CXGN::Stock::StockLookup->new({ schema => $schema });

    # remove non-word characters from names as required by
    # IGD naming conventions. Store new names as synonyms.
    #
    foreach my $e (@$elements) {
	my $submission_name = $e;
	$submission_name =~ s/\W/\_/g;

	print STDERR "Replacing element $e with $submission_name\n";
	$slu->set_stock_name($e);
	my $s = $slu -> get_stock();
	$slu->set_stock_name($submission_name);

	print STDERR "Storing synonym $submission_name for $e\n";
	$slu->set_stock_name($e);
	eval {
	    #my $rs = $slu->_get_stock_resultset();
	    $s->create_stockprops(
		{ igd_synonym => $submission_name },
		{  autocreate => 1,
		   'cv.name' => 'local',
		});
	};
	if ($@) {
	    print STDERR "[warning] An error occurred storing the synonym: $submission_name because of $@\n";
	}
    }

    print STDERR "Creating new trial design...\n";

    my $td = CXGN::Trial::TrialDesign->new( { schema => $schema });

    $td->set_stock_list($elements);
    $td->set_block_size(96);
    $td->set_blank($meta->{blank_well});
    $td->set_trial_name($meta->{trial_name});
    $td->set_design_type("genotyping_plate");

    my $design;

    eval {
        $td->calculate_design();
    };

    if ($@) {
        $c->stash->{rest} = { error => "Design failed. Error: $@" };
        print STDERR "Design failed because of $@\n";
        $c->detach();
    }

    $design = $td->get_design();

    if (exists($design->{error})) {
        $c->stash->{rest} = $design;
        $c->detach();
    }
    #print STDERR Dumper($design);

    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $location_id } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $breeding_program_id });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
        $c->detach();
    }

    print STDERR "Creating the trial...\n";

    my $ct = CXGN::Trial::TrialCreate->new( {
        chado_schema => $schema,
        dbh => $c->dbc->dbh(),
        user_name => $c->user()->get_object()->get_username(), #not implemented
        trial_year => $year,
        trial_location => $location->description(),
        program => $breeding_program->name(),
        trial_description => $description || "",
        design_type => 'genotyping_plate',
        design => $design,
        trial_name => $meta->{trial_name},
        is_genotyping => 1,
        genotyping_user_id => $meta->{user_id} || "unknown",
        genotyping_project_name => $meta->{project_name} || "unknown",
        operator => $c->user->get_object->get_username
    });

    my %message;
    my $error;
    try {
        %message = $ct->save_trial();
    } catch {
        $error = $_;
    };

    if ($message{'error'}) {
        $error = $message{'error'};
    }
    if ($error){
        $c->stash->{rest} = {error => "Error saving trial in the database: $error"};
        $c->detach;
    }

    $c->stash->{rest} = {
        message => "Successfully stored the trial.",
        trial_id => $message{trial_id},
    };
    #print STDERR Dumper(%message);
}

sub get_accession_plots :Path('/ajax/breeders/get_accession_plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $field_trial = $c->req->param("field_trial");
    my $parent_accession = $c->req->param("parent_accession");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $field_layout_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "field_layout", "experiment_type")->cvterm_id();
    my $dbh = $schema->storage->dbh();

    my $cross_accession = $schema->resultset("Stock::Stock")->find ({uniquename => $parent_accession});
    my $cross_accession_id = $cross_accession->stock_id();

    my $q = "SELECT stock.stock_id, stock.uniquename
            FROM nd_experiment_project join nd_experiment on (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id) AND nd_experiment.type_id= ?
            JOIN nd_experiment_stock ON (nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
            JOIN stock_relationship on (nd_experiment_stock.stock_id = stock_relationship.subject_id) AND stock_relationship.object_id = ?
            JOIN stock on (stock_relationship.subject_id = stock.stock_id)
            WHERE nd_experiment_project.project_id= ? ";

    my $h = $dbh->prepare($q);
    $h->execute($field_layout_typeid, $cross_accession_id, $field_trial, );

    my @plots=();
    while(my ($plot_id, $plot_name) = $h->fetchrow_array()){

      push @plots, [$plot_id, $plot_name];
    }

    $c->stash->{rest} = {data=>\@plots};

}


1;

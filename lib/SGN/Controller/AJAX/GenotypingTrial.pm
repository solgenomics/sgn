
package SGN::Controller::AJAX::GenotypingTrial;

use Moose;
use JSON::Any;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



sub genotype_trial : Path('/ajax/breeders/genotypetrial') ActionClass('REST') {}

sub genotype_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $list_id = $c->req->param("list_id");
    my $breeding_program_id = $c->req->param("breeding_program");
    my $description = $c->req->param("description");
    my $location_id = $c->req->param("location");
    my $year = $c->req->param("year");
    my $plate_json = $c->req->param("plate_json");
    my $trial_name = $c->req->param("trial_name");
    my $list = CXGN::List->new( { dbh => $c->dbc->dbh(), list_id => $list_id });
    my $elements = $list->elements();

    print STDERR "PARAMS: $list_id, $breeding_program_id, $location_id, $year\n";
    if ( !$list_id || !$breeding_program_id || !$location_id || !$year || !$trial_name) {
        $c->stash->{rest} = { error => "Please provide all parameters" };
        $c->detach();
    }
    
    # process $plate_json
    #
    my $meta = JSON::Any->decode($plate_json);
   
    print STDERR Dumper($meta);

    print STDERR "Looking up stock names and converting to IGD accepted names...\n";
    
    my $slu = CXGN::Stock::StockLookup->new({ schema => $schema });

    # remove non-word characters from names as required by
    # IGD naming conventions. Store new names as synonyms.
    #
    foreach my $e (@$elements) {

	# with new system, the name can contain special characters
	#my $submission_name = $e;
	#$submission_name =~ s/\W/\_/g;

	#print STDERR "Replacing element $e with $submission_name\n";
	$slu->set_stock_name($e);
	my $s = $slu -> get_stock();
	#$slu->set_stock_name($submission_name);

	#print STDERR "Storing synonym $submission_name for $e\n";
	$slu->set_stock_name($e);
	#
	#eval {
	    #my $rs = $slu->_get_stock_resultset();
	    #$s->create_stockprops(
	#	{ igd_synonym => $submission_name },
	#	{  autocreate => 1,
	#	   'cv.name' => 'local',
	##	});
	#};
	if ($@) {
	    #print STDERR "[warning] An error occurred storing the synonym: $submission_name because of $@\n";
	}
    }


    # THE DESIGN IS NOW PROVIDED BY THE GDF AJAX REQUEST

    # print STDERR "Creating new trial design...\n";

     my $td = CXGN::Trial::TrialDesign->new( { schema => $schema });

     $td->set_stock_list($elements);
     $td->set_block_size(96);
     $td->set_blank($meta->{blank_well});
    # $td->set_trial_name($meta->{trial_name});
    # $td->set_design_type("genotyping_plate");

    my $design = [];

    # eval {
    #     $td->calculate_design();
    # };

    # if ($@) {
    #     $c->stash->{rest} = { error => "Design failed. Error: $@" };
    #     print STDERR "Design failed because of $@\n";
    #     $c->detach();
    # }

    # $design = $td->get_design();

    # if (exists($design->{error})) {
    #     $c->stash->{rest} = $design;
    #     $c->detach();
    # }
    # #print STDERR Dumper($design);

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

# old genotyping trial database routines given for reference
#
sub genotype_trial_old : Path('/ajax/breeders/genotypetrial_old') ActionClass('REST') {}

sub genotype_trial_old_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $list_id = $c->req->param("list_id");
    my $breeding_program_id = $c->req->param("breeding_program");
    my $description = $c->req->param("description");
    my $location_id = $c->req->param("location");
    my $year = $c->req->param("year");
    my $plate_json = $c->req->param("plate_json");

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh(), list_id => $list_id });
    my $elements = $list->elements();

    print STDERR "PARAMS: $list_id, $breeding_program_id, $location_id, $year\n";
    if ( !$list_id || !$breeding_program_id || !$location_id || !$year) {
        $c->stash->{rest} = { error => "Please provide all parameters" };
        $c->detach();
    }
    
    # process $plate_json
    #
    my $meta = JSON::Any->decode($plate_json);
   
    print STDERR Dumper($meta);

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

sub get_genotypingserver_credentials : Path('/ajax/breeders/genotyping_credentials') Args(0) { 
    my $self = shift;
    my $c = shift;

    if ($c->user && ($c->user->check_roles("submitter") || $c->user->check_roles("curator"))) { 
        $c->stash->{rest} = { 
            host => $c->config->{genotyping_server_host},
            username => $c->config->{genotyping_server_username},
            password => $c->config->{genotyping_server_password}
        };
    }
    else { 
        $c->stash->{rest} = { 
            error => "Insufficient privileges for this operation." 
        };
    }
}

1;

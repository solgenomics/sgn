package SGN::Controller::AJAX::Propagation;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Person;
use SGN::Image;
use CXGN::Stock::StockLookup;
use CXGN::Stock::ParseUpload;
use CXGN::Location::LocationLookup;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::List;
use CXGN::BreedersToolbox::Projects;
use CXGN::Propagation::AddPropagationProject;
use DateTime;
use List::MoreUtils qw /any /;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub add_propagation_project : Path('/ajax/propagation/add_propagation_project') : ActionClass('REST') {}

sub add_propagation_project_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    my $project_name = $c->req->param('project_name');
    my $propagation_type = $c->req->param('propagation_type');
    my $breeding_program_id = $c->req->param('project_program_id');
    my $location = $c->req->param('project_location');
    my $year = $c->req->param('year');
    my $project_description = $c->req->param('project_description');
    $project_name =~ s/^\s+|\s+$//g;

    print STDERR "PROJECT NAME =".Dumper($project_name)."\n";

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a propagation project." };
        return;
    }

    my $program_name = $schema->resultset('Project::Project')->find({project_id => $breeding_program_id})->name();
    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    if (! ( (exists($has_roles{$program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
        $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $program_name to add new propagation project." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
       $geolocation_lookup->set_location_name($location);
       if(!$geolocation_lookup->get_geolocation()){
           $c->stash->{rest}={error => "Location not found"};
           return;
       }

    my $error;
    my $return;
    my $propagation_project_id;
    eval{
        my $add_propagation_project = CXGN::Propagation::AddPropagationProject->new({
            chado_schema => $schema,
            dbh => $dbh,
            breeding_program_id => $breeding_program_id,
            year => $year,
            project_description => $project_description,
            propagation_project_name => $project_name,
            propagation_type => $propagation_type,
            nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id(),
            owner_id => $user_id
        });

        $return = $add_propagation_project->save_propagation_project();
    };

    if (!$return){
        $c->stash->{rest} = {error => "Error saving project",};
        return;
    }

    if ($return->{error}){
        $error = $return->{error};
        $c->stash->{rest}={error => $error};
        return;
    } else {
        $propagation_project_id = $return->{project_id};
    }
    print STDERR "PROJECT ID =".Dumper($propagation_project_id)."\n";

    if ($@) {
        $c->stash->{rest} = {error => $@};
        return;
    };

    $c->stash->{rest} = {success => 1};

}


sub add_propagation_identifier : Path('/ajax/propagation/add_propagation_identifier') : ActionClass('REST') {}

sub add_transformation_identifier_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $propagation_identifier = $c->req->param('propagation_identifier');
    $propagation_identifier =~ s/^\s+|\s+$//g;
    my $propagation_project_id = $c->req->param('propagation_project_id');
    my $accession_name = $c->req->param('accession_name');
    my $material_type = $c->req->param('material_type');
    my $source_name = $c->req->param('source_name');
    my $rootstock_accession_name = $c->req->param('rootstock_accession_name');
    my $location = $c->req->param('location');
    my $date = $c->req->param('date');
    my $description = $c->req->param('description');
    my $program_name = $c->req->param('breeding_program_name');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a transformation ID." };
        return;
    }

    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    if (! ( (exists($has_roles{$program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
        $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $program_name to add propagation identifiers." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'accession', 'stock_type')->cvterm_id();

    if ($schema->resultset("Stock::Stock")->find({uniquename => $propagation_identifier})){
        $c->stash->{rest} = {error =>  "Propagation Identifier already exists. Please use another name" };
        return;
    }

    if (! $schema->resultset("Stock::Stock")->find({uniquename => $accession_name, type_id => $accession_cvterm_id })){
        $c->stash->{rest} = {error =>  "Accession name does not exist or does not exist as accession uniquename." };
        return;
    }

    if (! $schema->resultset("Stock::Stock")->find({uniquename => $source_name})){
        $c->stash->{rest} = {error =>  "Source name does not exist in the database." };
        return;
    }

    my $propagation_stock_id;
    eval {
        my $add_propagation_identifier = CXGN::Propagation::AddPropagationIdentifier->new({
            chado_schema => $schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
            propagation_project_id => $propagation_project_id,
            propagation_identifier => $propagation_identifier,
            accession_name => $accession_name,
            material_type => $material_type,
            source_name => $source_name,
            rootstock_accession_name => $rootstock_accession_name,
            location => $location,
            owner_id => $user_id,
            date => $date,
            description => $description
        });

        my $add = $add_propagation_identifier->add_propagation_identifier();
        $propagation_stock_id = $add->{propagation_stock_id};
    };

    if ($@) {
        $c->stash->{rest} = { success => 0, error => $@ };
        print STDERR "An error condition occurred, was not able to create propagation identifier. ($@).\n";
        return;
    }

    $c->stash->{rest} = { success => 1 };

}




###
1;#
###

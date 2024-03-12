package SGN::Controller::AJAX::Transformation;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Person;
use SGN::Image;
use CXGN::Stock::StockLookup;
use CXGN::Location::LocationLookup;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::List;
use CXGN::Transformation::AddTransformationProject;
use CXGN::Transformation::AddTransformationIdentifier;
use CXGN::Transformation::Transformation;
use CXGN::Transformation::AddTransformant;
use List::MoreUtils qw /any /;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub add_transformation_project : Path('/ajax/transformation/add_transformation_project') : ActionClass('REST') {}

sub add_transformation_project_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    my $project_name = $c->req->param('project_name');
    my $breeding_program_id = $c->req->param('project_program_id');
    my $location = $c->req->param('project_location');
    my $year = $c->req->param('year');
    my $project_description = $c->req->param('project_description');
    $project_name =~ s/^\s+|\s+$//g;

    print STDERR "PROJECT NAME =".Dumper($project_name)."\n";
    if (!$c->user()){
        $c->stash->{rest} = {error => "You need to be logged in to add a transformation project."};
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a transformation project." };
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
    eval{
        my $add_transformation_project = CXGN::Transformation::AddTransformationProject->new({
            chado_schema => $schema,
            dbh => $dbh,
            breeding_program_id => $breeding_program_id,
            year => $year,
            project_description => $project_description,
            transformation_project_name => $project_name,
            nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id(),
            owner_id => $user_id
        });

        my $return = $add_transformation_project->save_transformation_project();
        if ($return->{error}){
            $error = $return->{error};
        }
    };

    if ($@) {
        $c->stash->{rest} = {error => $@};
        return;
    };

    if ($error){
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {success => 1};
    }

}


sub add_transformation_identifier : Path('/ajax/transformation/add_transformation_identifier') : ActionClass('REST') {}

sub add_transformation_identifier_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $transformation_identifier = $c->req->param('transformation_identifier');
    my $plant_material = $c->req->param('plant_material');
    my $vector_construct = $c->req->param('vector_construct');
    my $notes = $c->req->param('notes');
    my $transformation_project_id = $c->req->param('transformation_project_id');
    $transformation_identifier =~ s/^\s+|\s+$//g;

    if (!$c->user()){
        $c->stash->{rest} = {error => "You need to be logged in to add a transformation transformation identifier."};
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a transformation identifier." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'accession', 'stock_type')->cvterm_id();
    my $vector_construct_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'vector_construct', 'stock_type')->cvterm_id();

    if ($schema->resultset("Stock::Stock")->find({uniquename => $transformation_identifier})){
        $c->stash->{rest} = {error =>  "Transformation identifier already exists." };
        return 0;
    }

    if (! $schema->resultset("Stock::Stock")->find({uniquename => $plant_material, type_id => $accession_cvterm_id })){
        $c->stash->{rest} = {error =>  "Plant material does not exist or does not exist as accession uniquename." };
        return;
    }

    if (! $schema->resultset("Stock::Stock")->find({uniquename => $vector_construct, type_id => $vector_construct_cvterm_id })){
        $c->stash->{rest} = {error =>  "vector construct does not exist or does not exist as vector construct uniquename." };
        return;
    }

    eval {
        my $add_transformation = CXGN::Transformation::AddTransformationIdentifier->new({
            chado_schema => $schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
            transformation_project_id => $transformation_project_id,
            transformation_identifier => $transformation_identifier,
            plant_material => $plant_material,
            vector_construct => $vector_construct,
            notes => $notes,
            owner_id => $user_id,
        });

        $add_transformation->add_transformation_identifier();
    };

    if ($@) {
        $c->stash->{rest} = { success => 0, error => $@ };
        print STDERR "An error condition occurred, was not able to create transformation identifier. ($@).\n";
        return;
    }

    $c->stash->{rest} = { success => 1 };

}


sub get_transformations_in_project :Path('/ajax/transformation/transformations_in_project') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $project_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;

    my $transformation_obj = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, project_id=>$project_id});

    my $result = $transformation_obj->get_transformations_in_project();
#    print STDERR "RESULT =".Dumper($result)."\n";
    my @transformations;
    foreach my $r (@$result){
        my ($transformation_id, $transformation_name, $plant_id, $plant_name, $vector_id, $vector_name) =@$r;
        push @transformations, [qq{<a href="/transformation/$transformation_id">$transformation_name</a>}, qq{<a href="/stock/$plant_id/view">$plant_name</a>}, qq{<a href="/stock/$vector_id/view">$vector_name</a>},'' , ''];
    }

    $c->stash->{rest} = { data => \@transformations };

}


sub add_transformants : Path('/ajax/transformation/add_transformants') : ActionClass('REST') {}

sub add_transformants_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $transformation_name = $c->req->param('transformation_name');
    my $transformation_stock_id = $c->req->param('transformation_stock_id');
    my $new_name_count = $c->req->param('new_name_count');
    print STDERR "TRANSFORMATION NAME =".Dumper($transformation_name)."\n";
    print STDERR "COUNT =".Dumper($new_name_count)."\n";

    if (!$c->user()){
        $c->stash->{rest} = {error => "You need to be logged in to add new transformants."};
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add new transformants." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $start_number = 1;
    my $basename = $transformation_name.'_T';
    my @new_transformant_names = ();
    foreach my $n (1..$new_name_count) {
        push @new_transformant_names, $basename. (sprintf "%04d", $n + $start_number -1);
    }

    foreach my $new_name (@new_transformant_names) {
        my $validate_new_name_rs = $schema->resultset("Stock::Stock")->search({uniquename=> $new_name});
        if ($validate_new_name_rs->count() > 0) {
            $c->stash->{rest} = {error_string => "Error creating new transformant name",};
            return;
        }
    }

    eval {
        my $add_transformants = CXGN::Transformation::AddTransformant->new({
            schema => $schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
            transformation_stock_id => $transformation_stock_id,
            transformant_names => \@new_transformant_names,
            owner_id => $user_id,
        });

        $add_transformants->add_transformant();
    };

    if ($@) {
        $c->stash->{rest} = { success => 0, error => $@ };
        print STDERR "An error condition occurred, was not able to create transformation identifier. ($@).\n";
        return;
    }

    $c->stash->{rest} = { success => 1 };

}



###
1;#
###

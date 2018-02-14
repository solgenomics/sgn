
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



1;


package SGN::Controller::AJAX::BreedersToolbox::Folder;

use Moose;
use List::MoreUtils qw | any |;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

sub get_folder : Chained('/') PathPart('ajax/folder') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;

    my $folder_id = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    $c->stash->{folder_id} = $folder_id;

}

sub create_folder :Path('/ajax/folder/new') Args(0) {
    my $self = shift;
    my $c = shift;
    my $parent_folder_id = $c->req->param("parent_folder_id");
    my $folder_name = $c->req->param("folder_name");
    my $breeding_program_id = $c->req->param("breeding_program_id");

    my $folder_for_trials;
    my $folder_for_crosses;
    my $folder_for_genotyping_trials;
    my $folder_for_genotyping_projects;
    my $folder_for_tracking_activities;
    my $folder_for_transformations;

    my $project_type = $c->req->param("project_type");
    if ($project_type eq 'field_trial') {
        $folder_for_trials = 1;
    } elsif ($project_type eq 'crossing_experiment') {
        $folder_for_crosses = 1;
    } elsif ($project_type eq 'genotyping_plate') {
        $folder_for_genotyping_trials = 1;
    } elsif ($project_type eq 'genotyping_project') {
        $folder_for_genotyping_projects = 1;
    } elsif ($project_type eq 'activity_record') {
        $folder_for_tracking_activities = 1;
    } elsif ($project_type eq 'transformation_project') {
        $folder_for_transformations = 1;
    }

    if (! $self->check_privileges($c)) {
	return;
    }
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $existing = $schema->resultset("Project::Project")->find( { name => $folder_name });

    if ($existing) {
        $c->stash->{rest} = { error => "A folder or trial with that name already exists in the database. Please select another name." };
        $c->detach;
    }
    my $folder = CXGN::Trial::Folder->create({
	    bcs_schema => $schema,
	    parent_folder_id => $parent_folder_id,
	    name => $folder_name,
	    breeding_program_id => $breeding_program_id,
        folder_for_trials => $folder_for_trials,
        folder_for_crosses => $folder_for_crosses,
        folder_for_genotyping_trials => $folder_for_genotyping_trials,
        folder_for_genotyping_projects => $folder_for_genotyping_projects,
        folder_for_tracking_activities => $folder_for_tracking_activities,
        folder_for_transformations => $folder_for_transformations,
	});

    $c->stash->{rest} = {
      success => 1,
      folder_id => $folder->folder_id()
    };
}

sub delete_folder : Chained('get_folder') PathPart('delete') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $self->check_privileges($c)) {
        return;
    }

    my $folder = CXGN::Trial::Folder->new({
        bcs_schema => $c->stash->{schema},
        folder_id => $c->stash->{folder_id}
    });

    my $delete_folder = $folder->delete_folder();
    if ($delete_folder) {
        $c->stash->{rest} = { success => 1 };
    } else {
        $c->stash->{rest} = { error => 'Folder Not Deleted! To delete a folder first move all trials and sub-folders out of it.' };
    }

}

sub rename_folder : Chained('get_folder') PathPart('name') Args(0) {
    my $self = shift;
    my $c = shift;
    my $new_folder_name = $c->req->param("new_name") ;
    if (! $self->check_privileges($c)) {
        return;
    }

    my $folder = CXGN::Trial::Folder->new({
        bcs_schema => $c->stash->{schema},
        folder_id => $c->stash->{folder_id}
    });
    my $rename_folder = $folder->rename_folder($new_folder_name);
    if ($rename_folder) {
        $c->stash->{rest} = { success => 1 };
    } else {
        $c->stash->{rest} = { error => 'Folder could not be renamed!' };
    }

}


sub associate_parent_folder : Chained('get_folder') PathPart('associate/parent') Args(1) {
    my $self = shift;
    my $c = shift;
    my $parent_id = shift;

    if (! $self->check_privileges($c)) {
	return;
    }

    my $folder = CXGN::Trial::Folder->new(
	{
	    bcs_schema => $c->stash->{schema},
	    folder_id => $c->stash->{folder_id}
	});

    $folder->associate_parent($parent_id);

    $c->stash->{rest} = { success => 1 };

}

sub set_folder_categories : Chained('get_folder') PathPart('categories') Args(0) {
    my $self = shift;
    my $c = shift;
    my $folder_for_trials = $c->req->param("folder_for_trials") eq 'true' ? 1 : 0;
    my $folder_for_experiments_menu = $c->req->param("folder_for_experiments_menu") eq 'true' ? 1 : 0;
    my $folder_for_crosses = $c->req->param("folder_for_crosses") eq 'true' ? 1 : 0;
    my $folder_for_genotyping_trials = $c->req->param("folder_for_genotyping_trials") eq 'true' ? 1 : 0;

    if (! $self->check_privileges($c)) {
        return;
    }

    my $folder = CXGN::Trial::Folder->new({
        bcs_schema => $c->stash->{schema},
        folder_id => $c->stash->{folder_id}
    });

    $folder->set_folder_content_type('folder_for_trials', $folder_for_trials);
    $folder->set_folder_content_type('folder_for_experiments_menu', $folder_for_experiments_menu);
    $folder->set_folder_content_type('folder_for_crosses', $folder_for_crosses);
    $folder->set_folder_content_type('folder_for_genotyping_trials', $folder_for_genotyping_trials);

    $c->stash->{rest} = { success => 1 };
}

sub check_privileges {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        print STDERR "User not logged in... not uploading coordinates.\n";
        $c->stash->{rest} = {error => "You need to be logged in." };
        $c->detach;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        $c->stash->{rest} = {error =>  "You have insufficient privileges." };
        $c->detach;
    }
    return 1;
}



1;

package SGN::Controller::Folder;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Trial::Folder;

BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub folder_page :Path("/folder") Args(1) {
    my $self = shift;
    my $c = shift;
    my $folder_id = shift;

    my $folder_project = $self->schema->resultset("Project::Project")->find( { project_id => $folder_id } );
    if (!$folder_project) {
        $c->stash->{message} = "The requested folder ($folder_id) does not exist or has been deleted.";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    # If the requested id is actually a breeding program, redirect to the program page
    # rather than treating it as a folder. The trial detail mason template renders an
    # unconditional /folder/{folder_id} link for the Folder cell; for trials whose
    # recorded parent is the breeding program directly (no intermediate folder), that
    # link resolves to /folder/{breeding_program_id} and used to 500 here.
    my $breeding_program_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'breeding_program', 'project_property');
    if ($breeding_program_cvterm) {
        my $is_program = $self->schema->resultset('Project::Projectprop')->find({
            project_id => $folder_id,
            type_id    => $breeding_program_cvterm->cvterm_id(),
        });
        if ($is_program) {
            $c->res->redirect("/breeders/program/$folder_id");
            return;
        }
    }

    my $folder = CXGN::Trial::Folder->new({ bcs_schema => $self->schema, folder_id => $folder_id });

    my $children = $folder->children();

    my @trials;
    my @cross_trials;
    my @genotyping_trials;
    my @genotyping_projects;
    my @analyses_trials;
    my @tracking_activities;
    my @child_folders;
    my $has_child_folders;
    foreach (@$children) {
#        print STDERR "CHECK FOLDER =".Dumper($_->folder_type." : ".$_->name)."\n";
        if ($_->folder_type eq 'trial') {
            push @trials, $_;
        }
        if ($_->folder_type eq 'cross') {
            push @cross_trials, $_;
        }
        if ($_->folder_type eq 'genotyping_trial') {
            push @genotyping_trials, $_;
        }
        if ($_->folder_type eq 'genotyping_project') {
            push @genotyping_projects, $_;
        }
        if ($_->folder_type eq 'analyses') {
            push @analyses_trials, $_;
        }
        if ($_->folder_type eq 'activity_record') {
            push @tracking_activities, $_;
        }
        if ($_->folder_type eq 'folder') {
            $has_child_folders = 1;
            push @child_folders, $_;
        }
    }

    $c->stash->{trials} = \@trials;
    $c->stash->{crossing_trials} = \@cross_trials;
    $c->stash->{genotyping_trials} = \@genotyping_trials;
    $c->stash->{genotyping_projects} = \@genotyping_projects;
    $c->stash->{analyses_trials} = \@analyses_trials;
    $c->stash->{tracking_activities} = \@tracking_activities;
    $c->stash->{child_folders} = \@child_folders;
    $c->stash->{project_parent} = $folder->project_parent();
    $c->stash->{breeding_program} = $folder->breeding_program();
    $c->stash->{folder_id} = $folder_id;
    $c->stash->{folder_name} = $folder_project->name();
    $c->stash->{folder_for_trials} = $folder->folder_for_trials();
    $c->stash->{folder_for_crosses} = $folder->folder_for_crosses();
    $c->stash->{folder_for_genotyping_trials} = $folder->folder_for_genotyping_trials();
    $c->stash->{folder_for_genotyping_projects} = $folder->folder_for_genotyping_projects();
    $c->stash->{folder_for_tracking_activities} = $folder->folder_for_tracking_activities();
    $c->stash->{folder_for_transformations} = $folder->folder_for_transformations();    
    $c->stash->{folder_description} = $folder_project->description();
    $c->stash->{has_child_folders} = $has_child_folders;
    if (!$folder->breeding_program) {
        $c->stash->{message} = "The requested folder does not exist or has been deleted.";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    $c->stash->{template} = '/breeders_toolbox/folder/folder.mas';
}

1;

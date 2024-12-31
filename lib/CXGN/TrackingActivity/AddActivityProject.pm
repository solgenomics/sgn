=head1 NAME

CXGN::TrackingActivity::AddActivityProject - a module for adding activity project

=cut


package CXGN::TrackingActivity::AddActivityProject;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::TrackingActivity::ActivityProject;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'breeding_program_id' => (
    isa =>'Int',
    is => 'rw',
    required => 1,
);

has 'year' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'project_description' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'nd_geolocation_id' => (
    isa => 'Int|Undef',
    is => 'rw',
    required => 1,
);

has 'activity_project_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'activity_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'parent_folder_id' => (
    isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'project_vendor' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'progress_of_project_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);


sub existing_project_name {
    my $self = shift;
    my $activity_project_name = $self->get_activity_project_name();
    my $schema = $self->get_bcs_schema();
    if($schema->resultset('Project::Project')->find({name => $activity_project_name})){
        return 1;
    } else {
        return;
    }
}


sub save_activity_project {
    my $self = shift;
    my $schema = $self->get_bcs_schema();

    if ($self->existing_project_name()){
        print STDERR "Can't create activity project: Project name already exists\n";
        return {error => "Tracking activity project not saved: Project name already exists"};
    }

    if (!$self->get_breeding_program_id()){
        print STDERR "Can't create activity project: Breeding program does not exist\n";
        return {error => "Tracking activity project not saved: Breeding program does not exist"};
    }

    my $parent_folder_id;
    $parent_folder_id = $self->get_parent_folder_id() || 0;

    my $project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_record', 'project_type')->cvterm_id();
    my $activity_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_type', 'project_property')->cvterm_id();
    my $project_vendor_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_vendor', 'project_property')->cvterm_id();
    my $progress_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'progress_of', 'project_relationship')->cvterm_id();

    my $project = $schema->resultset('Project::Project')
        ->create({
              name => $self->get_activity_project_name(),
              description => $self->get_project_description(),
#              type_id => $project_type_cvterm_id
        });

    my $project_id = $project->project_id();
#    print STDERR "NEW PROJECT ID =".Dumper($project_id)."\n";

    my $activity_project = CXGN::TrackingActivity::ActivityProject->new({
        bcs_schema => $schema,
        trial_id => $project_id,
    });

    if ($self->get_nd_geolocation_id()){
        $activity_project->set_location($self->get_nd_geolocation_id());
    }

    $activity_project->set_project_type($project_type_cvterm_id);
    $activity_project->set_year($self->get_year());
    $activity_project->set_breeding_program($self->get_breeding_program_id());
    $activity_project->set_trial_owner($self->get_owner_id);

    my $activity_projectprop = $schema->resultset('Project::Projectprop')->create({
        project_id => $project_id,
        type_id => $activity_type_cvterm_id,
        value => $self->get_activity_type(),
    });

    my $project_vendor = $self->get_project_vendor();
    if (defined $project_vendor) {
        my $vendor_projectprop = $schema->resultset('Project::Projectprop')->create({
            project_id => $project_id,
            type_id => $project_vendor_cvterm_id,
            value => $project_vendor,
        });
    }

    my $progress_of_project_id = $self->get_progress_of_project_id();

    if ($progress_of_project_id) {
        my $project_rel_row = $schema->resultset('Project::ProjectRelationship')->create({
            object_project_id => $progress_of_project_id,
            subject_project_id => $project_id,
            type_id => $progress_of_cvterm_id,
        });
        $project_rel_row->insert();
    }

    return {project_id => $project_id};

}


#########
1;
#########

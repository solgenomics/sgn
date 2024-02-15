=head1 NAME

CXGN::AddActivityProject - a module for adding activity project

=cut


package CXGN::AddActivityProject;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'schema' => (
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

has 'parent_folder_id' => (
    isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
);


sub existing_project_name {
    my $self = shift;
    my $activity_project_name = $self->get_activity_project_name();
    my $schema = $self->get_schema();
    if($schema->resultset('Project::Project')->find({name => $activity_project_name})){
        return 1;
    }
    else{
        return;
    }
}


sub save_activity_project {
    my $self = shift;
    my $schema = $self->get_schema();

    if ($self->existing_project_name()){
        print STDERR "Can't create activity project: Project name already exists\n";
        return {error => "Activity project not saved: Project name already exists"};
    }

    if (!$self->get_breeding_program_id()){
        print STDERR "Can't create activity project: Breeding program does not exist\n";
        return {error => "Activity project not saved: Breeding program does not exist"};
    }

    my $parent_folder_id;
    $parent_folder_id = $self->get_parent_folder_id() || 0;

    my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,'project year', 'project_property');
    my $project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_record', 'project_type')->cvterm_id();

    my $project = $schema->resultset('Project::Project')
        ->create({
              name => $self->get_activity_project_name(),
              description => $self->get_project_description(),
              type_id => $project_type_cvterm_id
        });


    my $activity_project = CXGN::TrackingActivity::ActivityProject->new({
        bcs_schema => $schema,
        project_id => $project->project_id(),
    });

    if ($self->get_nd_geolocation_id()){
        $activity_project->set_location($self->get_nd_geolocation_id());
    }

    $activity_project->set_year($self->get_year());
    $activity_project->set_breeding_program($self->get_breeding_program_id);
    $activity_project->set_trial_owner($self->get_owner_id);

    return {success=>1, activity_project_id=>$activity_project->get_activity_project_id};
}


#########
1;
#########

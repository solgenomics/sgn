=head1 NAME

CXGN::Propagation::AddPropagationProject - a module for adding propagation project

=cut


package CXGN::Propagation::AddPropagationProject;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'chado_schema' => (isa => 'DBIx::Class::Schema',
	is => 'rw',
	required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'breeding_program_id' => (isa =>'Int',
    is => 'rw',
    required => 1,
);

has 'year' => (isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'project_description' => (isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'nd_geolocation_id' => (isa => 'Int|Undef',
    is => 'rw',
    required => 1,
);

has 'propagation_project_name' => (isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'propagation_type' => (isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'owner_id' => (isa => 'Int',
    is => 'rw',
    );


sub existing_propagation_project {
    my $self = shift;
    my $propagation_project_name = $self->get_propagation_project_name();
    my $schema = $self->get_chado_schema();
    if($schema->resultset('Project::Project')->find({name=>$propagation_project_name})){
        return 1;
    }
    else {
        return;
    }
}

sub save_propagation_project {
    my $self = shift;
    my $schema = $self->get_chado_schema();

    if ($self->existing_propagation_project()){
        return {error => "Propagation project not saved: Project name already exists"};
    }

    if (!$self->get_breeding_program_id()){
        return {error => "Propagation project not saved: Breeding program does not exist"};
    }

    my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,'project year', 'project_property');
    my $propagation_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'propagation_type', 'project_property')->cvterm_id();
    my $project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_project', 'project_type')->cvterm_id();

    my $project = $schema->resultset('Project::Project')
        ->create({
              name => $self->get_propagation_project_name(),
              description => $self->get_project_description(),
        });

    my $project_id = $project->project_id();

    my $propagation_project = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $project_id
    });

    if ($self->get_nd_geolocation_id()){
        $propagation_project->set_location($self->get_nd_geolocation_id());
    }

    $propagation_project->set_project_type($project_type_cvterm_id);
    $propagation_project->set_year($self->get_year());
    $propagation_project->set_breeding_program($self->get_breeding_program_id);
    $propagation_project->set_trial_owner($self->get_owner_id);

    my $propagation_type_projectprop = $schema->resultset('Project::Projectprop')->create({
        project_id => $project_id,
        type_id => $propagation_type_cvterm_id,
        value => $self->get_propagation_type(),
    });


    return {success=>1, project_id=>$propagation_project->get_trial_id};

}


#########
1;
#########

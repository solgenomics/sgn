=head1 NAME

CXGN::Pedigree::AddCrossingtrial - a module for adding crossing experiment

=cut


package CXGN::Pedigree::AddCrossingtrial;

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

has 'crossingtrial_name' => (isa => 'Str',
    is => 'rw',
    required => 1,
    );

has 'parent_folder_id' => (isa => 'Str',
    is => 'rw',
    required => 0,
    );

sub existing_crossingtrials {
    my $self = shift;
    my $crossingtrial_name = $self->get_crossingtrial_name();
    my $schema = $self->get_chado_schema();
    if($schema->resultset('Project::Project')->find({name=>$crossingtrial_name})){
        return 1;
    }
    else{
        return;
    }
}


sub save_crossingtrial {
    print STDERR "Check 4.1:".localtime();
    my $self = shift;
    my $schema = $self->get_chado_schema();

    if ($self->existing_crossingtrials()){
        print STDERR "Can't create crossing experiment: Crossing experiment name already exists\n";
        return {error => "Crossing experiment not saved: Crossing experiment name already exists"};
    }


    if (!$self->get_breeding_program_id()){
        print STDERR "Can't create crossing experiment: Breeding program does not exist\n";
        return {error => "Crossing experiment not saved: Breeding program does not exist"};
    }

    my $parent_folder_id;
    $parent_folder_id = $self->get_parent_folder_id() || 0;
    my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,'project year', 'project_property');
    my $project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial', 'project_type')->cvterm_id();

    my $project = $schema->resultset('Project::Project')
        ->create({
              name => $self->get_crossingtrial_name(),
              description => $self->get_project_description(),
        });

    #add crossing experiment to folder if one was specified
    		if ($parent_folder_id) {
    		my $folder = CXGN::Trial::Folder->new(
    			{
    				bcs_schema => $schema,
    				folder_id => $project->project_id(),
    			});

    			$folder->associate_parent($parent_folder_id);
    		}

    my $crossing_trial = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $project->project_id()
    });

    if ($self->get_nd_geolocation_id()){
        $crossing_trial->set_location($self->get_nd_geolocation_id());
    }
    $crossing_trial->set_project_type($project_type_cvterm_id);
    $crossing_trial->set_year($self->get_year());
    $crossing_trial->set_breeding_program($self->get_breeding_program_id);
    return {success=>1, trial_id=>$crossing_trial->get_trial_id};
}







#########
1;
#########

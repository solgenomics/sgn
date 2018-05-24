=head1 NAME

CXGN::BreedingProgram - class for retrieving breeding program information and filtering by location/s, year/s, etc.

=head1 AUTHORS

Naama Menda <nm249@cornell.edu>


=head1 METHODS

=cut

package CXGN::BreedingProgram;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;


has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id;
    my $row = $self->schema->resultset("Project::Project")->find( 
	{ project_id             => $self->get_program_id(),
	  'projectprops.type_id' => $breeding_program_cvterm_id },
	{ join => 'projectprops' }
	);
    $self->set_project_object($row);
    if (!$row) {
	die "The breeding program  ".$self->get_project_id()." does not exist";
    }
}

=head2 accessors get_program_id()

 Desc: get the breeding program project_id

=cut

has 'program_id' => (isa => 'Int',
		     is => 'rw',
		     reader => 'get_program_id',
		     writer => 'set_program_id',
    );



=head2 accessors get_name, set_name

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_name {
    my $self = shift;
    my $project_obj = $self->get_project_object;

    if ($project_obj) {
	return $project_obj->name();
    }
}

sub set_name {
    my $self = shift;
    my $name = shift;
    my $project_obj = $self->get_project_object;
    if ($project_obj) {
	$project_obj->name($name);
	$project_obj->update();
    }
}

sub get_project_object {
  my $self = shift;
  return $self->{project_object}; 
}

sub set_project_object {
  my $self = shift;
  $self->{project_object} = shift;
}


=head2 accessors get_description, set_description

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_description {
  my $self = shift;
  return $self->{description}; 
}

sub set_description {
  my $self = shift;
  $self->{description} = shift;
}


sub get_breeding_program_cvterm_id {
    my $self = shift;
    
    my $breeding_program_cvterm_id;
    my $breeding_program_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'breeding_program', 'project_property');
    if ($breeding_program_cvterm) {
        $breeding_program_cvterm_id = $breeding_program_cvterm->cvterm_id();
    }
    return $breeding_program_cvterm_id;
}

sub get_project_year_cvterm_id {
    my $self = shift;
    my $year_cvterm_row = SGN::Model::Cvterm->get_cvterm_row( $self->schema, 'project year', 'project_property' );
    return $year_cvterm_row->cvterm_id();
}

sub get_accession_cvterm_id {
    my $self = shift;
    my $accession_cvterm_row = SGN::Model::Cvterm->get_cvterm_row( $self->schema, 'accession', 'stock_type' );
    return $accession_cvterm_row->cvterm_id();
}
=head2 get_trials

 Usage: $self->get_trials
 Desc:  find the trials (projects) associated with the breeding program
 Ret:   BCS Project resultset 
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_trials {
    my $self = shift;
    my $project_obj = $self->get_project_object;
    
    my $trials_rs;
    my $trial_rel_rs = $project_obj->project_relationship_object_projects;

    if ($trial_rel_rs) {
	$trials_rs = $trial_rel_rs->search_related('subject_project');
    }
    
    return $trials_rs;
}



=head2 get_locations

 Usage: my $locations = $breeding_program->get_locations()
 Desc:  find nd_geolocations by breeding program
 Ret:   NdGeolocation resultset
 Args:  none
 Side Effects: calls get_trials
 Example:

=cut

sub get_locations {
    my $self = shift;
    my $trials = $self->get_trials();
    my $nd_exp_projects = $trials->nd_experiment_projects;
    my $locations;

    if ( $nd_exp_projects ) {
	$locations = $nd_exp_projects->nd_experiment->nd_geolocation;
    }
    return $locations
}


=head2 get_years

 Usage:
 Desc:
 Ret: arrayref of project year values from projectprop
 Args:
 Side Effects: calls $self->get_trials
 Example:

=cut

sub get_years {
    my $self = shift;
    my $trials = $self->get_trials();
    my $project_year_cvterm_id = $self->get_project_year_cvterm_id;
    my $trialprops_rs = $trials->projectprops->search( { type_id=>$project_year_cvterm_id }, { distinct => 1, } );
    my @years = $trialprops_rs->value;
    return \@years;
}

=head2 get_accessions

 Usage: $self->get_accessions
 Desc:
 Ret: BCS Stock resultset of type_id accession
 Args:
 Side Effects:
 Example:

=cut

sub get_accessions {
    my $self = shift; 
    my $trials = $self->get_trials();
    my $accession_cvterm_id = $self->get_accession_cvterm_id;
    my $accessions = $trials->nd_experiment->nd_experiment_stock->stock->search( { type_id => $accession_cvterm_id }, {distinct => 1, } );
    return $accessions;
}


    
####
1;##
####

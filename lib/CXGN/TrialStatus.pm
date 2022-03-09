package CXGN::TrialStatus;


=head1 NAME

CXGN::TrialStatus - a class to record trial status

=head1 DESCRIPTION

The projectprop of type "trial_status_json" is stored as JSON.

=head1 EXAMPLE

my $trial_status = CXGN::TrialStatus->new( { schema => $schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;


has 'started_phenotyping' => (isa => 'Str', is => 'rw');

has 'phenotyping_completed' => (isa => 'Str', is => 'rw');

has 'data_cleaning_completed' => (isa => 'Str', is => 'rw');

has 'data_analysis_completed' => (isa => 'Str', is => 'rw');

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('trial_status_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | started_phenotyping phenotyping_completed data_cleaning_completed data_analysis_completed | ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}




1;

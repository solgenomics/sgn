package CXGN::BreedersToolbox::SoilData;


=head1 NAME

CXGN::BreedersToolbox::SoilData - a class to manage soil data

=head1 DESCRIPTION

The projectprop of type "soil_data_json" is stored as JSON.

=head1 EXAMPLE

my $soil_data = CXGN::BreedersToolbox::SoilData->new( { schema => $schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;


has 'description' => (isa => 'Str', is => 'rw');

has 'year' => (isa => 'Maybe[Str]', is => 'rw');

has 'gps' => (isa => 'Maybe[Str]', is => 'rw');

has 'type_of_sampling' => (isa => 'Str', is => 'rw');

has 'data_type_order' => (isa => 'ArrayRef', is => 'rw');

has 'soil_data_details' => (isa => 'HashRef', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('soil_data_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | description year gps type_of_sampling data_type_order soil_data_details | ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}



1;

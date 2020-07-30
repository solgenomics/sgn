package CXGN::BreedersToolbox::ProductProfile;


=head1 NAME

CXGN::BreedersToolbox::ProductProfile - a class to manage product profile

=head1 DESCRIPTION

The projectprop of type "product_profile_json" is stored as JSON.

=head1 EXAMPLE

my $profile = CXGN::BreedersToolbox::ProductProfile->new( { schema => $schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;


has 'product_profile_name' => (isa => 'Str', is => 'rw');

has 'product_profile_scope' => (isa => 'Str', is => 'rw');

has 'product_profile_details' => (isa => 'Str', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('product_profile_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | product_profile_name product_profile_scope product_profile_details| ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}


1;

package CXGN::Pedigree::TargetNumbers;

use Moose;

extends 'CXGN::JSONProp';

has 'target_numbers' => (isa => 'HashRef', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('target_numbers_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | target_numbers | ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}

1;

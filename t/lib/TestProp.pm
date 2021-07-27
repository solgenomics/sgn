package TestProp;

use Moose;

use Data::Dumper;

BEGIN { extends 'CXGN::JSONProp'; }

has 'info_field1' => (isa => 'Str', is => 'rw');

has 'info_field2' => (isa => 'Str', is => 'rw');

sub BUILD {
    my $self = shift;
    my $args = shift;
    
    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('analysis_metadata_json');
    $self->cv_name('project_property');
    $self->allowed_fields( [ qw | info_field1 info_field2 | ] );
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}

1;

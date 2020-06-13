
=head1 NAME

CXGN::Analysis::AnalysisMetadata - manage metadata for analyses in breedbase

=head1 DESCRIPTION

CXGN::Analysis::AnalysisMetadata manages analysis metadata using a projectprop. It extends CXGN::JSONProp.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::Analysis::AnalysisMetadata;

use Moose;

extends 'CXGN::JSONProp';

=head2 dataset_id()

=cut

has 'dataset_id' => ( isa => 'Maybe[Int]', is => 'rw');

=head2 dataset_data()

=cut

has 'dataset_data' => (isa => 'Maybe[Str]', is => 'rw');

=head2 analysis_protocol()

=cut
    
has 'analysis_protocol' => (isa => 'Maybe[Str]', is => 'rw');

=head2 traits()

=cut

has 'traits' => (isa => 'Maybe[Ref]', is => 'rw');

=head2 create_timestamp()

=cut

has 'create_timestamp' => (isa => 'Maybe[Str]', is =>'rw');

=head2 modified_timestamp()

=cut

has 'modified_timestamp' => (isa => 'Maybe[Str]', is => 'rw');

=head2 result_summary()

=cut

has 'result_summary' => (isa => 'Maybe[HashRef]', is => 'rw');

=head1 INHERITED METHODS

=head2 store()

=head2 delete()

=cut

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('analysis_metadata_json');
    $self->prop_id($args->{prop_id});
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | dataset_id dataset_data analysis_protocol create_timestamp modified_timestamp result_summary| ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();

}


1;

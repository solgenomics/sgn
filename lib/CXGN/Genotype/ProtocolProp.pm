
=head1 NAME

CXGN::Genotype::ProtocolProp

=head1 DESCRIPTION

CXGN::Genotype::ProtocolProp manages genotyping protocol metadata stored in nd_protocolprop with type 'vcf_map_details'. It extends CXGN::JSONProp.

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::Genotype::ProtocolProp;

use Moose;

extends 'CXGN::JSONProp';


has 'assay_type' => (isa => 'Str', is => 'rw');

has 'chromosomes' => (isa => 'Maybe[HashRef]', is => 'rw');

has 'header_information_line' => (isa => 'Maybe[Str]', is =>'rw');

has 'marker_info_keys' => ( isa => 'Maybe[ArrayRef]', is => 'rw');

has 'marker_names' => ( isa => 'Maybe[ArrayRef]', is => 'rw');

has 'reference_genome_name' => (isa => 'Str', is =>'rw');

has 'sample_observation_unit_type_name' => (isa => 'Str', is =>'rw');

has 'species_name' => (isa => 'Str', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('nd_protocolprop');
    $self->prop_namespace('NaturalDiversity::NdProtocolprop');
    $self->prop_primary_key('nd_protocolprop_id');
    $self->prop_type('vcf_map_details');
    $self->prop_id($args->{prop_id});
    $self->cv_name('protocol_property');
    $self->allowed_fields([ qw | assay_type chromosomes header_information_line marker_info_keys marker_names reference_genome_name sample_observation_unit_type_name species_name | ]);
    $self->parent_table('nd_protocol');
    $self->parent_primary_key('nd_protocol_id');

    $self->load();

}


1;

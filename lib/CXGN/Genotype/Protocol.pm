package CXGN::Genotype::Protocol;

=head1 NAME

CXGN::Genotype::Protocol - an object to handle genotyping protocols (breeding data)

=head1 USAGE

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'nd_protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'protocol_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'markers' => (
    isa => 'HashRef',
    is => 'rw',
);

has 'header_information_lines' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has 'reference_genome_name' => (
    isa => 'Str',
    is => 'rw'
);

has 'species_name' => (
    isa => 'Str',
    is => "rw"
);

has 'sample_observation_unit_type_name' => (
    isa => 'Str',
    is => 'rw'
);

sub BUILD {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $protocol_vcf_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    my $protocol_rs = $schema->resultset('NaturalDiversity::NdProtocol')->search({
        'me.nd_protocol_id'=>$self->nd_protocol_id,
        'me.type_id'=>$geno_cvterm_id,
        'nd_protocolprops.type_id'=>$protocol_vcf_details_cvterm_id
    }, {
        join => 'nd_protocolprops',
        '+select' => ['nd_protocolprops.value'],
        '+as' => ['value']
    });
    if ($protocol_rs->count != 1){
        print STDERR "Not a valide nd_protocol_id\n";
        return;
    }
    my $protocol = $protocol_rs->first;
    my $map_details = decode_json $protocol->get_column('value');
    $self->markers($map_details->{markers});
    $self->protocol_name($protocol->name);
    $self->header_information_lines($map_details->{header_information_lines});
    $self->reference_genome_name($map_details->{reference_genome_name});
    $self->species_name($map_details->{species_name});
    $self->sample_observation_unit_type_name($map_details->{sample_observation_unit_type_name});
    return;
}

#class method
sub list {
    my $schema = shift;
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $protocol_vcf_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    my $protocol_rs = $schema->resultset('NaturalDiversity::NdProtocol')->search({
        'me.type_id'=>$geno_cvterm_id,
        'nd_protocolprops.type_id'=>$protocol_vcf_details_cvterm_id
    }, {
        join => 'nd_protocolprops',
        '+select' => ['nd_protocolprops.value'],
        '+as' => ['value']
    });
    my @results;
    while (my $r = $protocol_rs->next()){
        my $name = $r->name;
        my $map_details = decode_json $r->get_column('value');
        my $marker_set = $map_details->{markers};
        my $header_information_lines = $map_details->{header_information_lines};
        my $reference_genome_name = $map_details->{reference_genome_name};
        my $species_name = $map_details->{species_name};
        my $sample_observation_unit_type_name = $map_details->{sample_observation_unit_type_name};
        push @results, {
            protocol_id => $r->nd_protocol_id,
            protocol_name => $name,
            markers => $marker_set,
            header_information_lines => $header_information_lines,
            reference_genome_name => $reference_genome_name,
            species_name => $species_name,
            sample_observation_unit_type_name => $sample_observation_unit_type_name
        };
    }
    #print STDERR Dumper \@results;
    return \@results;
}

1;


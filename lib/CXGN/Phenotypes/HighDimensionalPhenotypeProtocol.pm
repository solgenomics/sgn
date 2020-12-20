package CXGN::Phenotypes::HighDimensionalPhenotypeProtocol;

=head1 NAME

CXGN::Phenotypes::HighDimensionalPhenotypeProtocol - an object to handle high dimensional phenotype data protocols (NIRS, Transcriptomics, Metabolomics)

To get info for a specific protocol:

my $protocol = CXGN::Phenotypes::HighDimensionalPhenotypeProtocol->new({
    bcs_schema => $schema,
    nd_protocol_id => $protocol_id,
    nd_protocol_type_id => $nirs_protocol_cvterm_id #nd_protocol type_id in cvterm table
});
And then use Moose attributes to retrieve info

----------------

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

has 'nd_protocol_type_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'protocol_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'protocol_description' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'header_column_names' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has 'header_column_details' => (
    isa => 'HashRef',
    is => 'rw'
);

has 'protocol_properties' => (
    isa => 'HashRef',
    is => 'rw'
);

has 'create_date' => (
    isa => 'Str',
    is => 'rw'
);

sub BUILD {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $nd_protocol_cvterm_id = $self->nd_protocol_type_id;
    my $protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocolprop.value, nd_protocol.create_date, nd_protocol.description
        FROM nd_protocol
        JOIN nd_protocolprop ON(nd_protocol.nd_protocol_id = nd_protocolprop.nd_protocol_id AND nd_protocolprop.type_id=$protocol_prop_cvterm_id)
        WHERE nd_protocol.type_id=$nd_protocol_cvterm_id AND nd_protocol.nd_protocol_id=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($self->nd_protocol_id);
    my ($nd_protocol_id, $nd_protocol_name, $value, $create_date, $description) = $h->fetchrow_array();

    my $protocol_details = $value ? decode_json $value : {};
    my $header_column_names = $protocol_details->{header_column_names} || [];
    my $header_column_details = $protocol_details->{header_column_details} || {};
    delete($protocol_details->{header_column_names});
    delete($protocol_details->{header_column_details});

    $self->header_column_names($header_column_names);
    $self->header_column_details($header_column_details);
    $self->protocol_name($nd_protocol_name);
    $self->protocol_properties($protocol_details);
    if ($create_date) {
        $self->create_date($create_date);
    }
    if ($description) {
        $self->protocol_description($description);
    }

    return;
}

1;


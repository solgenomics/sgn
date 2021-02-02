package CXGN::Genotype::StorePCRMarkerInfo;

=head1 NAME


=head1 USAGE


=head1 AUTHORS

Titima Tantikanjana <tt15@cornell.edu>

=cut

use Moose;
use Data::Dumper;
use Bio::Chado::Schema;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'protocol_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'protocol_description' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'species_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'marker_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'marker_details' => (
    isa => 'HashRef',
    is => 'rw',
    required => 1
);

has 'sample_observation_unit_type_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

sub store_pcr_marker_info {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $protocol_name = $self->protocol_name();
    my $protocol_description = $self->protocol_description();
    my $species_name = $self->species_name();
    my $marker_type = $self->marker_type();
    my $marker_details = $self->marker_details();
    my $sample_type = $self->sample_observation_unit_type_name();

    my $pcr_marker_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'pcr_marker_protocol', 'protocol_type')->cvterm_id();
    my $pcr_marker_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'pcr_marker_details', 'protocol_property')->cvterm_id();

    my %marker_hash = %$marker_details;
    my @marker_names = keys %marker_hash;
#    print STDERR "MARKER NAMES =".Dumper(\@marker_names)."\n";

    my %pcr_marker_info;
    $pcr_marker_info{'marker_type'} = $marker_type;
    $pcr_marker_info{'species_name'} = $species_name;
    $pcr_marker_info{'marker_details'} = $marker_details;
    $pcr_marker_info{'marker_names'} = \@marker_names;
    $pcr_marker_info{'sample_observation_unit_type_name'} = $sample_type;

    my $pcr_marker_info_ref = \%pcr_marker_info;

    my $pcr_marker_info_prop = [{value => encode_json $pcr_marker_info_ref, type_id=>$pcr_marker_prop_cvterm_id}];

	my $protocol_id;
    my $protocol_rs = $schema->resultset("NaturalDiversity::NdProtocol")->find({
        name => $protocol_name,
    });
    if ($protocol_rs) {
        return { error => "The protocol name: $protocol_name has already been used! Please use a new name." };
    }
    else {
        $protocol_rs = $schema->resultset("NaturalDiversity::NdProtocol")->create({
            name => $protocol_name,
            type_id => $pcr_marker_protocol_cvterm_id,
            nd_protocolprops => $pcr_marker_info_prop
        });
        $protocol_id = $protocol_rs->nd_protocol_id();
    }

    my $q = "UPDATE nd_protocol SET description = ? WHERE nd_protocol_id = ?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($protocol_description, $protocol_id);

	return $protocol_id;
}

1;

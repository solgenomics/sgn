package CXGN::Genotype::StorePCRMarkerInfo;

=head1 NAME


=head1 USAGE


=head1 AUTHORS


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


sub store_pcr_marker_info {
    my $self = shift;
    my $protocol_name = $self->protocol_name();
    my $protocol_description = $self->protocol_description();
    my $species_name = $self->species_name();
    my $marker_type = $self->marker_type();
    my $marker_details = $self->marker_details();

    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping experiment', 'experiment_type')->cvterm_id();
    my $pcr_marker_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'pcr_marker_details', 'protocol_property')->cvterm_id();

    my %pcr_marker_info;
    $pcr_marker_info{'marker_type'} = $marker_type;
    $pcr_marker_info{'species'} = $species_name;
    $pcr_marker_info{'markers'} = $marker_details;
    my $pcr_marker_info_ref = \%pcr_marker_info;

    my $pcr_marker_info_prop = [{value => encode_json $pcr_marker_info_ref, type_id=>$pcr_marker_prop_cvterm_id}];


	my $protocol_id;
    my $protocol_rs = $schema->resultset("NaturalDiversity::NdProtocol")->find({
        name => $protocol_name,
        type_id => $genotyping_experiment_cvterm_id
    });
    if ($protocol_rs) {
        return { error => "The protocol name: $protocol_name has already been used! Please use a new name." };
    }
    else {
        $protocol_rs = $schema->resultset("NaturalDiversity::NdProtocol")->create({
            name => $model_name,
            type_id => $genotyping_experiment_cvterm_id,
            nd_protocolprops => $pcr_marker_info_prop;
        });
        $protocol_id = $protocol_rs->nd_protocol_id();
    }

    my $q = "UPDATE nd_protocol SET description = ? WHERE nd_protocol_id = ?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($protocol_description, $protocol_id);

	return {success => 1, nd_protocol_id => $protocol_id};
}

1;

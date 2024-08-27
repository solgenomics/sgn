=head1 NAME

CXGN::TrackingActivity::TrackingIdentifier - an object representing tracking identifier in the database

=head1 DESCRIPTION


=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::TrackingActivity::TrackingIdentifier;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

has 'schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'tracking_identifier_stock_id' => (
    isa => "Int",
    is => 'rw',
);


sub get_tracking_identifier_info {
    my $self = shift;
    my $schema = $self->schema();
    my $tracking_identifier_stock_id = $self->tracking_identifier_stock_id();
    my $tracking_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "tracking_identifier", "stock_type")->cvterm_id();
    my $material_of_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id;
    my $activity_stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id;
    my $discarded_metadata_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'discarded_metadata', 'stock_property')->cvterm_id();

    my $q = "SELECT tracking_id.stock_id, tracking_id.uniquename, material.stock_id, material.uniquename, material_type.name, activity_info.value, status_type.name
        FROM stock AS tracking_id
        JOIN stock_relationship ON (tracking_id.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock AS material ON (stock_relationship.subject_id = material.stock_id)
        JOIN cvterm AS material_type ON (material.type_id = material_type.cvterm_id)
        LEFT JOIN stockprop AS activity_info ON (activity_info.stock_id = tracking_id.stock_id) AND activity_info.type_id = ?
        LEFT JOIN stockprop AS updated_status ON (updated_status.stock_id = tracking_id.stock_id) AND updated_status.type_id = ?
        LEFT JOIN cvterm AS status_type ON (status_type.cvterm_id = updated_status.type_id)
        WHERE tracking_id.stock_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($material_of_type_id, $activity_stockprop_type_id, $discarded_metadata_type_id, $tracking_identifier_stock_id);

    my @tracking_info = ();
    while (my ($tracking_stock_id, $tracking_name, $material_stock_id, $material_name, $material_stock_type, $activity_info, $updated_status_type) = $h->fetchrow_array()){
        push @tracking_info, [$tracking_stock_id, $tracking_name, $material_stock_id, $material_name, $material_stock_type, $activity_info, $updated_status_type]
    }
    print STDERR "TRACKING INFO =".Dumper(\@tracking_info)."\n";
    return \@tracking_info;

}


###
1;
###

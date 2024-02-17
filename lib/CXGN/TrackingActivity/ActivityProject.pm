package CXGN::TrackingActivity::ActivityProject;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;


extends 'CXGN::Project';


has 'project_id' => (
    isa => "Int",
    is => 'rw',
    required => 0,
);


=head2 get_project_active_identifiers

    Class method.
    Returns all active tracking identifers and tracking info.
    Example: my @active_identifiers = CXGN::TrackingActivity::ActivityProject->get_project_active_identifiers($schema, $project_id)

=cut

sub get_project_active_identifiers {
    my $self = shift;
    my $schema = $self->schema;
    my $activity_project_id = $self->project_id;

    my $project_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_record', 'project_type')->cvterm_id;
    my $experiment_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id;
    my $stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id;
    my $stock_relationship_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id;
    my $stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id;

    my $q = "SELECT identifier.stock_id, identifier.uniquename, material.stock_id, material.uniquename, material.type_id, stock_property.value  FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS identifier on (nd_experiment_stock.stock_id = identifier.stock_id) AND identifier.type_id = ?
        JOIN stock_relationship on (identifier.stock_id = stock_relationship.object_id) AND type_id = ?
        JOIN stock as material on (stock_relationship.subject_id = material.stock_id)
        LEFT JOIN stockprop on (identifier.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($stock_type_id, $stock_relationship_type_id, $stockprop_type_id, $activity_project_id);

    my @data = ();
    while(my($identifier_id, $identifier_name, $material_id, $material_name, $material_type_id, $tracking_info) = $h->fetchrow_array()){
        push @data, [$identifier_id, $identifier_name, $material_id, $material_name, $material_type_id, $tracking_info];
    }

    print STDERR "DATA =".Dumper(\@data)."\n";
    return \@data;
}


1;

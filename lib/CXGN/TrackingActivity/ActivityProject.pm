package CXGN::TrackingActivity::ActivityProject;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;


extends 'CXGN::Project';

has 'trial_id' => (isa => "Int",
    is => 'rw',
    required => 0,
);

has 'activity_type' => (isa => "Str",
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
    my $schema = $self->bcs_schema;
    my $activity_project_id = $self->trial_id;
    my $activity_type = $self->activity_type;

    my $project_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_record', 'project_type')->cvterm_id;
    my $experiment_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id;
    my $project_tracking_id_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'project_tracking_identifier', 'experiment_type')->cvterm_id;
    my $stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id;
    my $stock_relationship_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id;
    my $stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id;
    my $trial_treatments_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_trial_treatments_json', 'stock_property')->cvterm_id;
    my $material_type_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_type', 'stock_property')->cvterm_id;

    my @data = ();

    if ($activity_type eq 'trial_treatments') {
        my $q = "SELECT identifier.stock_id, identifier.uniquename, project.project_id, project.name, stockprop.value
            FROM nd_experiment_project AS nd_experiment_project_1
            JOIN nd_experiment_stock AS nd_experiment_stock_1 ON (nd_experiment_project_1.nd_experiment_id = nd_experiment_stock_1.nd_experiment_id) and nd_experiment_stock_1.type_id = ?
            JOIN nd_experiment_stock AS nd_experiment_stock_2 ON (nd_experiment_stock_1.stock_id = nd_experiment_stock_2.stock_id) and nd_experiment_stock_2.type_id = ?
            JOIN nd_experiment_project AS nd_experiment_project_2 ON (nd_experiment_stock_2.nd_experiment_id = nd_experiment_project_2.nd_experiment_id)
            JOIN project ON (project.project_id = nd_experiment_project_2.project_id)
            JOIN stock AS identifier on (nd_experiment_stock_1.stock_id = identifier.stock_id) AND identifier.type_id = ?
            LEFT JOIN stockprop on (identifier.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
            WHERE nd_experiment_project_1.project_id = ?";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($experiment_type_id, $project_tracking_id_type_id, $stock_type_id, $trial_treatments_type_id, $activity_project_id);

        while(my($identifier_id, $identifier_name, $source_project_id, $source_project_name, $tracking_info) = $h->fetchrow_array()){
            push @data, [$identifier_id, $identifier_name, $source_project_id, $source_project_name, $tracking_info];
        }
    } else {
        my $q = "SELECT identifier.stock_id, identifier.uniquename, material.stock_id, material.uniquename, stockprop.value
            FROM nd_experiment_project
            JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN stock AS identifier on (nd_experiment_stock.stock_id = identifier.stock_id) AND identifier.type_id = ?
            LEFT JOIN stockprop on (identifier.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
            JOIN stock_relationship on (identifier.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
            JOIN stock as material on (stock_relationship.subject_id = material.stock_id)
            WHERE nd_experiment_project.project_id = ?";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($stock_type_id, $stockprop_type_id, $stock_relationship_type_id, $activity_project_id);

        while(my($identifier_id, $identifier_name, $material_id, $material_name, $tracking_info) = $h->fetchrow_array()){
            push @data, [$identifier_id, $identifier_name, $material_id, $material_name, $tracking_info];
        }
    }

#    print STDERR "DATA =".Dumper(\@data)."\n";
    return \@data;
}


1;

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


=head2 get_project_active_identifiers

    Class method.
    Returns all active tracking identifers and tracking info.
    Example: my @active_identifiers = CXGN::TrackingActivity::ActivityProject->get_project_active_identifiers($schema, $project_id)

=cut

sub get_project_active_identifiers {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $activity_project_id = $self->trial_id;

    my $project_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_record', 'project_type')->cvterm_id;
    my $experiment_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id;
    my $stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id;
    my $stock_relationship_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id;
    my $tissue_culture_stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id;
    my $transformation_stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_transformation_json', 'stock_property')->cvterm_id;
    my $completed_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'completed_metadata', 'stock_property')->cvterm_id;
    my $terminated_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'terminated_metadata', 'stock_property')->cvterm_id;

    my $q = "SELECT identifier.stock_id, identifier.uniquename, material.stock_id, material.uniquename, material.type_id, stockprop1.value
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS identifier on (nd_experiment_stock.stock_id = identifier.stock_id) AND identifier.type_id = ?
        LEFT JOIN stockprop AS stockprop1 on (identifier.stock_id = stockprop1.stock_id) AND stockprop1.type_id in (?, ?)
        LEFT JOIN stockprop AS stockprop2 on (identifier.stock_id = stockprop2.stock_id) AND stockprop2.type_id in (?, ?)
        JOIN stock_relationship on (identifier.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock as material on (stock_relationship.subject_id = material.stock_id)
        WHERE nd_experiment_project.project_id = ? AND stockprop2.value IS NULL";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($stock_type_id, $tissue_culture_stockprop_type_id, $transformation_stockprop_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $stock_relationship_type_id,  $activity_project_id);

    my @data = ();
    while(my($identifier_id, $identifier_name, $material_id, $material_name, $material_type_id, $tracking_info) = $h->fetchrow_array()){
        push @data, [$identifier_id, $identifier_name, $material_id, $material_name, $material_type_id, $tracking_info];
    }

    return \@data;
}


=head2 get_project_inactive_identifiers

    Class method.
    Returns all inactive tracking identifers and tracking info.
    Example: my @inactive_identifiers = CXGN::TrackingActivity::ActivityProject->get_project_inactive_identifiers($schema, $project_id)

=cut

sub get_project_inactive_identifiers {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $activity_project_id = $self->trial_id;

    my $project_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_record', 'project_type')->cvterm_id;
    my $experiment_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id;
    my $stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id;
    my $stock_relationship_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id;
    my $tissue_culture_stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id;
    my $transformation_stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_transformation_json', 'stock_property')->cvterm_id;
    my $completed_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'completed_metadata', 'stock_property')->cvterm_id;
    my $terminated_metadata_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'terminated_metadata', 'stock_property')->cvterm_id;

    my $q = "SELECT identifier.stock_id, identifier.uniquename, material.stock_id, material.uniquename, material.type_id, stockprop1.value, cvterm.name, stockprop2.value
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS identifier on (nd_experiment_stock.stock_id = identifier.stock_id) AND identifier.type_id = ?
        LEFT JOIN stockprop AS stockprop1 on (identifier.stock_id = stockprop1.stock_id) AND stockprop1.type_id IN (?, ?)
        JOIN stockprop AS stockprop2 on (identifier.stock_id = stockprop2.stock_id) AND stockprop2.type_id IN (?, ?)
        JOIN cvterm on (cvterm.cvterm_id = stockprop2.type_id)
        JOIN stock_relationship on (identifier.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock as material on (stock_relationship.subject_id = material.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($stock_type_id, $tissue_culture_stockprop_type_id, $transformation_stockprop_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $stock_relationship_type_id,  $activity_project_id);

    my @data = ();
    while(my($identifier_id, $identifier_name, $material_id, $material_name, $material_type_id, $tracking_info, $status_type, $status_details) = $h->fetchrow_array()){
        push @data, [$identifier_id, $identifier_name, $material_id, $material_name, $material_type_id, $tracking_info, $status_type, $status_details];
    }

    return \@data;
}


sub get_project_activity_type {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $project_id = $self->trial_id;

    my $activity_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_type', 'project_property')->cvterm_id();
    my $activity_type = $schema->resultset("Project::Projectprop")->find ({ project_id => $project_id, type_id => $activity_type_cvterm_id })->value();

    return $activity_type;
}


1;

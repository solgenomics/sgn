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
    my $tissue_culture_stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id;
    my $transformation_stockprop_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_transformation_json', 'stock_property')->cvterm_id;
    my $completed_metadata_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'completed_metadata', 'stock_property')->cvterm_id();
    my $terminated_metadata_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'terminated_metadata', 'stock_property')->cvterm_id();

    my $q = "SELECT tracking_id.stock_id, tracking_id.uniquename, material.stock_id, material.uniquename, material_type.name, activity_info.value, info_type.name, status_type.name
        FROM stock AS tracking_id
        JOIN stock_relationship ON (tracking_id.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock AS material ON (stock_relationship.subject_id = material.stock_id)
        JOIN cvterm AS material_type ON (material.type_id = material_type.cvterm_id)
        LEFT JOIN stockprop AS activity_info ON (activity_info.stock_id = tracking_id.stock_id) AND activity_info.type_id IN (?, ?)
        LEFT JOIN cvterm AS info_type ON (info_type.cvterm_id = activity_info.type_id)
        LEFT JOIN stockprop AS updated_status ON (updated_status.stock_id = tracking_id.stock_id) AND updated_status.type_id IN (?, ?)
        LEFT JOIN cvterm AS status_type ON (status_type.cvterm_id = updated_status.type_id)
        WHERE tracking_id.stock_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($material_of_type_id, $tissue_culture_stockprop_type_id, $transformation_stockprop_type_id, $completed_metadata_type_id, $terminated_metadata_type_id, $tracking_identifier_stock_id);

    my @tracking_info = ();
    while (my ($tracking_stock_id, $tracking_name, $material_stock_id, $material_name, $material_stock_type, $activity_info, $info_type, $updated_status_type) = $h->fetchrow_array()){
        push @tracking_info, [$tracking_stock_id, $tracking_name, $material_stock_id, $material_name, $material_stock_type, $activity_info, $info_type, $updated_status_type]
    }

    return \@tracking_info;

}


sub get_associated_project_program {
    my $self = shift;
    my $schema = $self->schema();
    my $tracking_identifier_stock_id = $self->tracking_identifier_stock_id();
    my @project_program;

    my $experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id();
    my $program_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $progress_of_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'progress_of', 'project_relationship')->cvterm_id();

    my $q = "SELECT tracking_project.project_id, tracking_project.name, program.project_id, program.name, linked_project.project_id, linked_project.name
        FROM nd_experiment_stock
        JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN project AS tracking_project ON (nd_experiment_project.project_id = tracking_project.project_id)
        JOIN project_relationship ON (tracking_project.project_id = project_relationship.subject_project_id) AND project_relationship.type_id = ?
        JOIN project AS program ON (project_relationship.object_project_id = program.project_id)
        LEFT JOIN project_relationship AS linked_project_relationship ON (linked_project_relationship.subject_project_id = tracking_project.project_id) AND linked_project_relationship.type_id = ?
        LEFT JOIN project AS linked_project ON (linked_project_relationship.object_project_id = linked_project.project_id)
        WHERE nd_experiment_stock.stock_id = ? ";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($program_relationship_cvterm_id, $progress_of_relationship_cvterm_id, $tracking_identifier_stock_id);

    my @project_and_program = ();
    while(my($project_id, $project_name, $program_id, $program_name, $linked_project_id, $linked_project_name) = $h->fetchrow_array()){
        push @project_and_program, [$project_id, $project_name, $program_id, $program_name, $linked_project_id, $linked_project_name];
    }

    return \@project_and_program;

}



###
1;
###

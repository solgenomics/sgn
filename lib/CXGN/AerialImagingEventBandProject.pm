
package CXGN::AerialImagingEventBandProject;

use Moose;

extends 'CXGN::Project';

use SGN::Model::Cvterm;

=head2 function get_associated_field_trial()

 Usage:
 Desc:         returns the field trial [id, name]
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_associated_field_trial_to_drone_run_band {
    my $self = shift;
    my $schema = $self->bcs_schema;

    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_field_trial_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();

    my $q = "SELECT drone_run.project_id, drone_run.name, drone_run_band.project_id, drone_run_band.name, field_trial.project_id, field_trial.name
        FROM project AS drone_run
        JOIN project_relationship AS drone_run_on_drone_run_band ON (drone_run.project_id = drone_run_on_drone_run_band.object_project_id AND drone_run_on_drone_run_band.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run_band ON (drone_run_band.project_id = drone_run_on_drone_run_band.subject_project_id)
        JOIN project_relationship AS drone_run_on_field_trial ON (drone_run.project_id = drone_run_on_field_trial.subject_project_id AND drone_run_on_field_trial.type_id = $drone_run_field_trial_type_id)
        JOIN project AS field_trial ON (field_trial.project_id = drone_run_on_field_trial.object_project_id)
        WHERE drone_run_band.project_id = ?
        LIMIT 1;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($self->get_trial_id);
    my ($drone_run_project_id, $drone_run_project_name, $drone_run_band_project_id, $drone_run_band_project_name, $field_trial_id, $field_trial_name) = $h->fetchrow_array();

    return ($field_trial_id, $field_trial_name);
}

=head2 function get_associated_field_trial_layout()

 Usage:
 Desc:         returns the field layout for the drone run band
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_associated_field_trial_layout {
    my $self = shift;
    my $schema = $self->bcs_schema;

    my ($field_trial_id, $field_trial_name) = $self->get_associated_field_trial_to_drone_run_band();
    my $field_trial_layout = CXGN::Trial->new({bcs_schema => $schema, trial_id=>$field_trial_id})->get_layout()->get_design();

    return $field_trial_layout;
}

1;

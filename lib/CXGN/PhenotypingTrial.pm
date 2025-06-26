
package CXGN::PhenotypingTrial;

use Moose;

extends 'CXGN::Project';

use SGN::Model::Cvterm;

=head2 function set_field_trials_source_field_trials()

 Usage:
 Desc:         sets associated source field trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:         an arrayref [source_trial_id1, source_trial_id2]
 Side Effects:
 Example:

=cut

sub set_field_trials_source_field_trials {
    my $self = shift;
    my $source_field_trial_ids = shift;
    my $schema = $self->bcs_schema;
    my $field_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_from_field_trial', 'project_relationship')->cvterm_id();

    foreach (@$source_field_trial_ids){
        if ($_){
            my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->create({
                'subject_project_id' => $self->get_trial_id(),
                'object_project_id' => $_,
                'type_id' => $field_trial_from_field_trial_cvterm_id
            });
        }
    }
    my $projects = $self->get_field_trials_source_field_trials();
    return $projects;
}

=head2 function get_field_trials_source_field_trials()

 Usage:
 Desc:         return associated source field trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_source_field_trials {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $field_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.subject_project_id' => $self->get_trial_id(),
        'me.type_id' => $field_trial_from_field_trial_cvterm_id
    }, {
        join => 'object_project', '+select' => ['object_project.name'], '+as' => ['source_trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->object_project_id, $r->get_column('source_trial_name') ];
    }
    return  \@projects;
}

=head2 function get_field_trials_sourced_from_field_trials()

 Usage:
 Desc:         return associated source field trials for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_sourced_from_field_trials {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $field_trial_from_field_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_from_field_trial', 'project_relationship')->cvterm_id();

    my $trial_rs= $self->bcs_schema->resultset('Project::ProjectRelationship')->search({
        'me.object_project_id' => $self->get_trial_id(),
        'me.type_id' => $field_trial_from_field_trial_cvterm_id
    }, {
        join => 'subject_project', '+select' => ['subject_project.name'], '+as' => ['trial_name']
    });

    my @projects;
    while (my $r = $trial_rs->next) {
        push @projects, [ $r->subject_project_id, $r->get_column('trial_name') ];
    }
    return  \@projects;
}

=head2 function get_drone_run_bands_from_field_trial()

 Usage:
 Desc:         return associated drone_run_band projects for the current field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_drone_run_bands_from_field_trial {
    my $self = shift;
    my $bcs_schema = $self->bcs_schema;

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, project.project_id, project.name, project.description, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_relationship_type_id)
        JOIN project ON (drone_run_band_rel.object_project_id = project.project_id)
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        WHERE field_trial.project_id = ?
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($self->get_trial_id());
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_name, $drone_run_band_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description) = $h->fetchrow_array()) {
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        push @result, [$drone_run_band_project_id, $drone_run_band_name, $drone_run_band_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_date_display, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description];
    }
    return \@result;
}

=head2 function get_trial_stock_type()

 Usage:
 Desc:         Get stock type used in trial
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_trial_stock_type {
    my $self = shift;
    my $trial_stock_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'trial_stock_type', 'project_property');
    my $type_id = $trial_stock_type_cvterm->cvterm_id();

    my $stock_type_rs = $self->bcs_schema->resultset('Project::Project')->search( { 'me.project_id' => $self->get_trial_id() })->search_related('projectprops', { 'projectprops.type_id' => $type_id } );

    if ($stock_type_rs->count() == 0) {
        return;
    } else {
        return $stock_type_rs->first()->value();
    }
}


=head2 get_stock_entry_summary

 Usage:        my $stock_entry_summary = $t->get_stock_entry_summary();
 Desc:         retrieves the accessions, plots, subplots, plants and tissue samples based on their relationships in this trial.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_stock_entry_summary {
	my $self = shift;
    my $trial_id = $self->get_trial_id();
    my $schema = $self->bcs_schema;
    my @stock_entry_summary;

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_sample_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $tissue_sample_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT distinct(tissue_sample.uniquename) AS tissue_sample_name, tissue_sample.stock_id, parent_stock.uniquename, parent_stock.stock_id, cvterm.name, plot.uniquename, plot.stock_id, plant.uniquename, plant.stock_id
    FROM nd_experiment_project
    JOIN nd_experiment_stock ON (nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id)
    JOIN stock AS plot ON (plot.stock_id = nd_experiment_stock.stock_id) AND plot.type_id = ?
    JOIN stock_relationship AS plot_parent_relationship ON (plot_parent_relationship.subject_id = plot.stock_id) AND plot_parent_relationship.type_id = ?
    JOIN stock AS parent_stock ON (plot_parent_relationship.object_id = parent_stock.stock_id) AND parent_stock.type_id IN (?,?,?)
    JOIN cvterm ON (cvterm.cvterm_id = parent_stock.type_id)
    LEFT JOIN stock_relationship AS plot_plant ON (plot_plant.subject_id = plot.stock_id) AND plot_plant.type_id = ?
    LEFT JOIN stock AS plant ON (plant.stock_id = plot_plant.object_id) AND plant.type_id = ?
    LEFT JOIN stock_relationship AS plant_tissue_sample ON (plant_tissue_sample.object_id = plant.stock_id) AND plant_tissue_sample.type_id = ?
    LEFT JOIN stock AS tissue_sample ON (tissue_sample.stock_id = plant_tissue_sample.subject_id) AND tissue_sample.type_id = ?
    WHERE nd_experiment_project.project_id = ? ORDER BY parent_stock.uniquename, plot.uniquename, plant.uniquename, tissue_sample.uniquename ASC ;";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);

    $h->execute($plot_type_id, $plot_of_type_id, $accession_type_id, $cross_type_id, $family_name_type_id, $plant_of_type_id, $plant_type_id, $tissue_sample_of_type_id, $tissue_sample_type_id, $trial_id);
    while (my ($tissue_sample_name, $tissue_sample_id, $parent_stock_name, $parent_stock_id, $parent_stock_type, $plot_name, $plot_id, $plant_name, $plant_id) = $h->fetchrow_array()) {
        push @stock_entry_summary, [$parent_stock_name, $parent_stock_id, $parent_stock_type, $plot_name, $plot_id, $plant_name, $plant_id, $tissue_sample_name, $tissue_sample_id];
    }

    return \@stock_entry_summary;
}

=head2 remove_treatment

 Usage:        my $trial_object->remove_treatment($treatment_id);
 Desc:         removes the selected treatment from this trial
 Ret:
 Args:         $treatment_id
 Side Effects:
 Example:

=cut

sub remove_treatment {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $treatment_id =shift;

    my $trial_id = $self->get_trial_id();

    my $treatment_rs = $schema->resultset('Project::Project')->find({ project_id => $treatment_id });
    if (!$treatment_rs) {
        return { error => "Treatment not found" };
    }

    eval {
        $treatment_rs->delete();
    };

    return { success => 1 };
}



1;

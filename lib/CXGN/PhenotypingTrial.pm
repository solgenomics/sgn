
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
        return undef;
    } else {
        return $stock_type_rs->first()->value();
    }
}

=head2 function get_plants_on_plot($plot)

Desc:   Get the plants that are on plot $plot

=cut

sub get_plants_on_plot {
    my $self = shift;
    my $plot = shift;

    my $plant_of_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'plant_of', 'stock_relationship');
    my $plot_type_id =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'plant', 'stock_type');

    my $q = "select plant.uniquename, plant.stock_id, plot.uniquename, plot.stock_id, plot.type_id stock_relationship.type_id FROM stock as plot join stock_relationship on(subject_id=plot.stock_id) join stock as plant on(object_id=plant.stock_id) where plot.uniquename=? and stock_relationship.type_id=?";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($plot, $plant_of_id);

    my @plants;
    while (my ($plant_name, $plant_id, $plot_name, $plot_id, $this_plot_type_id, $stock_rel_type_id) = $h->fetchrow_array()) {
	if ($plot_type_id != $this_plot_type_id) {
	    die "The plot parameter has to designate a plot - $plot_name has a type_id of $this_plot_type_id which is not plot type id of $plot_type_id";
	}

	push @plants, [ $plant_id, $plant_name ];

    }

    return \@plants;
}

=head2 function get_subplots_on_plot($plot)

Desc:   Get the subplots that are on plot $plot

=cut

sub get_subplots_on_plot {
    my $self = shift;
    my $plot = shift;

    my $subplot_of_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'subplot_of', 'stock_relationship');
    my $plot_type_id =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'plot', 'stock_type');
    my $q = "select subplot.stock_id, subplot.uniquename, plot.stock_id, plot.uniquename, plot.type_id, stock_relationship.type_id FROM stock as subplot join stock_relationship on(subject_id=subplot.stock_id) join stock as plot on(object_id=plot.stock_id) where subplot.uniquename= ? and stock_relationship.type_id= ? ";
    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($plot, $subplot_of_id);

    my @subplots;
    while (my ($subplot_name, $subplot_id, $plot_name, $plot_id, $this_plot_type_id, $stock_rel_type_id) = $h->fetchrow_array()) {
	if ($plot_type_id != $this_plot_type_id) {
	    die "The plot parameter has to designate a plot - $plot_name has a type_id of $this_plot_type_id which is not plot";
	}

	push @subplots, [ $subplot_id, $subplot_name ];

    }

    return \@subplots


}

=head2 function get_tissue_samples_for_plant($plot)

Desc:   Get the tissue samples for plant $plant

=cut

sub get_tissue_samples_for_plant {
    my $self = shift;
    my $plant = shift;

    my $tissue_sample_of_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'tissue_sample_of', 'stock_relationship');
    my $plant_type_id =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'plant', 'stock_type');
    my $q = "select tissue_sample.stock_id, tissue_sample.uniquename, plant.stock_id, plant.uniquename, plant.type_id, stock_relationship.type_id FROM stock as tissue_sample join stock_relationship on(subject_id=tissue_sample.stock_id) join stock as plant on(object_id=plant.stock_id) where tissue_sample.uniquename= ? and stock_relationship.type_id= ? ";
    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($plant, $tissue_sample_of_id);

    my @tissue_samples;
    while (my ($tissue_sample_name, $tissue_sample_id, $plant_name, $plant_id, $this_plant_type_id, $stock_rel_type_id) = $h->fetchrow_array()) {
	if ($plant_type_id != $this_plant_type_id) {
	    die "The plot parameter has to designate a plant - $plant_name has a type_id of $this_plant_type_id which is not the plant type id of $plant_type_id";
	}

	push @tissue_samples, [ $tissue_sample_id, $tissue_sample_name ];

    }

    return \@tissue_samples;

}

=head2 function get_tissue_samples_for_plant($plot)

Desc:   Get the tissue samples for plant $plant

=cut

sub get_tissue_samples_for_plot {
    my $self = shift;
    my $plot = shift;

    my $tissue_sample_of_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'tissue_sample_of', 'stock_relationship');
    my $plot_type_id =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'plot', 'stock_type');
    my $q = "select tissue_sample.stock_id, tissue_sample.uniquename, plot.stock_id, plot.uniquename, plot.type_id, stock_relationship.type_id FROM stock as tissue_sample join stock_relationship on(subject_id=tissue_sample.stock_id) join stock as plot on(object_id=plot.stock_id) where tissue_sample.uniquename= ? and stock_relationship.type_id= ? ";
    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($plot, $tissue_sample_of_id);

    my @tissue_samples;
    while (my ($tissue_sample_name, $tissue_sample_id, $plot_name, $plot_id, $this_plot_type_id, $stock_rel_type_id) = $h->fetchrow_array()) {
	if ($plot_type_id != $this_plot_type_id) {
	    die "The plot parameter has to designate a plant - $plot_name has a type_id of $this_plot_type_id which is not the plot type id of $plot_type_id";
	}

	push @tissue_samples, [ $tissue_sample_id, $tissue_sample_name ];

    }

    return \@tissue_samples;
}

=head2 get_accession_associated_with_layout_object()

    Desc:    returns the accession associated with a layout object
             a layout object can be a plot, subplot, plant, or tissue_sample
    Params:  layout_object_id, layout_object_name
    Returns: the stock_id of the accession associated with this item

=cut

sub get_accessions_associated_with_layout_item {
    my $self = shift;
    my $layout_item_id = shift;
    my $layout_item_type_id = shift;

    my $q = "select accession.stock_id, accession.uniquename, source.stock_id, source.uniquename, source.type_id, stock_relationship.type_id FROM stock as accession join stock_relationship on(object_id=accession.stock_id) join stock as source on(subject_id=source.stock_id) where source.uniquename=? and accession.type_id=?";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    $h->execute($plot, $tissue_sample_of_id);

    my @accessions;
    while (my ($accession_name, $accession_id, $source_name, $source_id, $source_type_id, $stock_rel_type_id) = $h->fetchrow_array()) {

	push @accessions, [ $accession_id, $accession_name ];

    }

    return \@accessions;


}

=head2 replace_accession_associated_with_layout_item()

    Desc:    replaces the accession associated with a layout item
             a layout item can be a plot, subplot, plant, or tissue_sample
    Params:  layout_item_id, layout_item_name
    Returns: the stock_id of the accession associated with this item

=cut

sub replace_accession_associated_with_layout_item {
    my $self = shift;
    my $layout_item_id = shift;
    my $layout_item_name = shift;
    my $old_accession_id = shift;
    my $new_accession_id = shift;

    

}



1;

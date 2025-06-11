
package CXGN::PhenotypingTrial;

use Moose;

extends 'CXGN::Project';

use SGN::Model::Cvterm;
use Data::Dumper;

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


=head2 function get_crossing_experiments_from_field_trial()

 Usage:
 Desc:         return associated crossing experiments from field trial
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_crossing_experiments_from_field_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $field_trial_id = $self->get_trial_id();

    my $field_trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id});
    my $plots = $field_trial->get_plots();
    my @related_stock_ids;
    foreach my $plot (@$plots){
        push @related_stock_ids, $plot->[0];
    }

    my $plants = $field_trial->get_plants();
    if ($plants) {
        foreach my $plant (@$plants) {
            push @related_stock_ids, $plant->[0];
        }
    }
    print STDERR "RELATED STOCK IDS =".Dumper(\@related_stock_ids)."\n";

    my @where_clause;
    my $stock_ids_sql = join (",", @related_stock_ids);
    push @where_clause, "stock_relationship.subject_id IN ($stock_ids_sql)";
    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $female_plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plot_of", "stock_relationship")->cvterm_id();
    my $male_plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plot_of", "stock_relationship")->cvterm_id();
    my $female_plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plant_of", "stock_relationship")->cvterm_id();
    my $male_plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plant_of", "stock_relationship")->cvterm_id();
    my $cross_experiment_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', "experiment_type")->cvterm_id();


    my $q = "SELECT DISTINCT project.project_id, project.name
        FROM stock_relationship
        JOIN nd_experiment_stock ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id IN (?,?,?,?)
        JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id) AND nd_experiment_stock.type_id = ?
        JOIN project ON (nd_experiment_project.project_id = project.project_id)
        $where_clause;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_plot_of_type_id, $male_plot_of_type_id, $female_plot_of_type_id, $male_plant_of_type_id, $cross_experiment_type_id);

    my @crossing_experiments = ();
    while(my($experiment_id, $experiment_name) = $h->fetchrow_array()){
        push @crossing_experiments, [$experiment_id, $experiment_name];
    }

    return  \@crossing_experiments;
}



1;

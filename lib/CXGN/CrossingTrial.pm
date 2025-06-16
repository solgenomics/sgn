
package CXGN::CrossingTrial;

use Moose;

extends 'CXGN::Project';

use SGN::Model::Cvterm;
use CXGN::Cross;
use Data::Dumper;

=head2 function get_field_trial_sources_of_crossing_experiment()

 Usage:
 Desc:         return associated source field trials for crosses in crossing experiment
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trial_sources_of_crossing_experiment {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $crossing_experiment_id = $self->get_trial_id();

    my $crossing_experiment = CXGN::Cross->new({schema=>$schema, trial_id => $crossing_experiment_id});
    my $parent_plots = $crossing_experiment->get_plots_used_in_crossing_experiment();
    my $plots_of_plants = $crossing_experiment->get_plots_of_plants_used_in_crossing_experiment();
    my %all_plots;

    if ($parent_plots) {
        foreach my $plot (@$parent_plots) {
            my $plot_id = $plot->[0];
            $all_plots{$plot_id}++;
        }
    }

    if ($plots_of_plants) {
        foreach my $plot_of_plant (@$plots_of_plants) {
            my $plot_of_plant_id = $plot_of_plant->[0];
            $all_plots{$plot_of_plant_id}++;
        }
    }

    my @field_trials = ();
    my @where_clause;
    my @plot_ids = keys %all_plots;

    if (scalar(@plot_ids) > 0) {
        my $plot_sql = join (",", @plot_ids);
        push @where_clause, "nd_experiment_stock.stock_id IN ($plot_sql)";
        my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

        my $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, , 'field_layout', 'experiment_type')->cvterm_id();
        my $q = "SELECT DISTINCT project.project_id, project.name
            FROM nd_experiment_stock
            JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id) AND nd_experiment_stock.type_id = ?
            JOIN project ON (nd_experiment_project.project_id = project.project_id)
            $where_clause";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($nd_experiment_type_id);

        while(my($trial_id, $trial_name) = $h->fetchrow_array()){
            push @field_trials, [$trial_id, $trial_name]
        }
    }

    return  \@field_trials;
}


=head2 function get_field_trials_for_evaluating_crosses()

 Usage:
 Desc:         return associated field trials used for evaluating crosses in crossing experiment
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_for_evaluating_crosses {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $crossing_experiment_id = $self->get_trial_id();

    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot_of", "stock_relationship")->cvterm_id();
    my $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, , 'field_layout', 'experiment_type')->cvterm_id();

    my $crossing_experiment = CXGN::Cross->new({schema=>$schema, trial_id => $crossing_experiment_id});
    my $crosses = $crossing_experiment->get_crosses_in_crossing_experiment();

    my @field_trials = ();
    my @cross_ids;
    if ($crosses) {
        foreach my $cross (@$crosses) {
           push @cross_ids, $cross->[0];
        }
    }

    if (scalar(@cross_ids) > 0) {
        my @where_clause;
        my $cross_sql = join (",", @cross_ids);
        push @where_clause, "stock_relationship.object_id IN ($cross_sql)";
        my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

        my $q = "SELECT DISTINCT project.project_id, project.name
            FROM stock_relationship
            JOIN nd_experiment_stock ON (nd_experiment_stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ?
            JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id) AND nd_experiment_stock.type_id = ?
            JOIN project ON (nd_experiment_project.project_id = project.project_id)
           $where_clause";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($plot_of_type_id, $nd_experiment_type_id);

        while(my($trial_id, $trial_name) = $h->fetchrow_array()){
            push @field_trials, [$trial_id, $trial_name]
        }

    }

    return  \@field_trials;
}


1;


package CXGN::CrossingTrial;

use Moose;

extends 'CXGN::Project';

use SGN::Model::Cvterm;
use CXGN::Cross;

=head2 function get_field_trials_source_of_crossing_experiment()

 Usage:
 Desc:         return associated source field trials for crosses in crossing experiment
 Ret:          returns an arrayref [ id, name ] of arrayrefs
 Args:
 Side Effects:
 Example:

=cut

sub get_field_trials_source_of_crossing_experiment {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $crossing_experiment_id = $self->get_trial_id();

    my $crossing_experiment = CXGN::Cross->new({schema=>$schema, trial_id => $crossing_experiment_id});
    my $plots = $crossing_experiment->get_plots_used_in_crossing_experiment();
    my $plots_of_plants = $crossing_experiment->get_plots_of_plants_used_in_crossing_experiment();




    my @field_trials;
    return  \@field_trials;
}




1;

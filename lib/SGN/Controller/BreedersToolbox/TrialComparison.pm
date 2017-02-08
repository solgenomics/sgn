
package SGN::Controller::BreedersToolbox::Trial::TrialComparison;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }


sub trial_comparison_input :Path('/tools/trial/comparison/') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/tools/trial_comparison/index.mas';

}

1;

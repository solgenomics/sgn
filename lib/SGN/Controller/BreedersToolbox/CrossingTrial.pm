
package SGN::Controller::BreedersToolbox::CrossingTrial;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub crossing_trial_page : Path('/breeders/crossing_trial') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/breeders_toolbox/cross/crossing_trial.mas';

}

1;

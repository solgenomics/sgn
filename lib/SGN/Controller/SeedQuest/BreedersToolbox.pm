package SGN::Controller::SeedQuest::BreedersToolbox;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub weather_gdd : Path('/tools/weather/gdd') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/gdd_analysis.mas';
}

sub gdd_analysis : Path('/breeders/gdd_analysis') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/gdd_analysis.mas';
}

__PACKAGE__->meta->make_immutable;

1;

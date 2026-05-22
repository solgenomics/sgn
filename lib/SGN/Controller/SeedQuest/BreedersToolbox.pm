package SGN::Controller::SeedQuest::BreedersToolbox;

use Moose;
use namespace::autoclean;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub manage_drone_imagery_simple : Path('/breeders/drone_imagery_simple') Args(0) {
    my ($self, $c) = @_;

    if (!$c->user()) {
        $c->res->redirect(uri(
            path  => '/user/login',
            query => { goto_url => $c->req->uri->path_query },
        ));
        return;
    }

    $c->stash->{template} = '/breeders_toolbox/drone_imagery/upload_drone_imagery_simple.mas';
}

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

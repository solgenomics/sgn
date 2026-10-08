package SGN::Controller::Search::Treatment;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trait_search_page : Path('/search/treatments/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/treatments.mas';
}

1;
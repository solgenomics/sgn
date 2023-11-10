
package SGN::Controller::Search::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trial_search_page : Path('/search/datasets/') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/datasets.mas';

}

1;


package SGN::Controller::Search::Trait;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trait_search_page : Path('/search/traits/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/traits.mas';
}

1;

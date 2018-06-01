
package SGN::Controller::Search::Trait;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trait_search_page : Path('/search/traits/') Args(0) {
    my $self = shift;
    my $c = shift;
    my $trait_cv_name = $c->get_conf("trait_cv_name");

    $c->stash->{trait_cv_name} = $trait_cv_name  || 'not_provided';
    $c->stash->{template} = '/search/traits.mas';
}

1;

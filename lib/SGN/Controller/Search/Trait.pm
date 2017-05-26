
package SGN::Controller::Search::Trait;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trait_search_page : Path('/search/traits/') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{cv_name} = $c->req->param('trait_cv_name') || 'cassava_trait' ; #'not_provided';
    $c->stash->{template} = '/search/traits.mas';

}

1;

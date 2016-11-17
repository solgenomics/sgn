
package SGN::Controller::Search::Crosses;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub search_page : Path('/search/crosses') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/crosses.mas';

}

1;

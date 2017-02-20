
package SGN::Controller::Search::Cross;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub search_page : Path('/search/cross') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross.mas';

}

1;

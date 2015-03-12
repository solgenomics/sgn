
package SGN::Controller::People;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub people_search : Path('/search/people') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/people.mas';


}

1;

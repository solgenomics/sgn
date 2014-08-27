
package SGN::Controller::Search::Trial;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trial_search_page : Path('/search/trial/') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/search/trial.mas';

}

1;

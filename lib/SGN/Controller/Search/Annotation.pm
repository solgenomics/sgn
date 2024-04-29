package SGN::Controller::Search::Annotation;
use Moose;

BEGIN{ extends 'Catalyst::Controller' }


sub annotation_search : Path('/search/annotation') Args(0) {
    $_[1]->stash(
        template => '/search/annotation/stub.mas',
     );
}

1;

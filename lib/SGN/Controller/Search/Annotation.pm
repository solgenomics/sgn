package SGN::Controller::Search::Annotation;
use Moose;

BEGIN{ extends 'Catalyst::Controller' }


sub annotation_search : Path('/search/annotation') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $page = shift;

    my $template = '/search/annotation/'.$page. '.mas'; 

    $c->stash(
        template => $template,
     );

    $c->throw_404
        unless $c->view('Mason')->component_exists( $template );

}

1;

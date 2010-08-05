package SGN::Controller::Root;
use Moose;
use namespace::autoclean;

use CatalystX::GlobalContext ();

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

SGN::Controller::Root - Root Controller for SGN

=head1 DESCRIPTION

Web application to run the SGN web site.

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Hello World
    $c->stash->{template} = '/index.mas';
    $c->stash->{schema}   = $c->dbic_schema('SGN::Schema');
}

=head2 default

Attempt to find index.pl pages, and prints standard 404 error page if
nothing could be found.

=cut

sub default :Path {
    my ( $self, $c ) = @_;

    return 1 if $self->_do_redirects($c);

    # other
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub _do_redirects {
    my ($self, $c) = @_;
    my $path = $c->req->path;
    my $query = $c->req->uri->query || '';
    $query = "?$query" if $query;

    $c->log->debug("searching for redirects ($path) ($query)");

    # if the path has multiple // in it, collapse them and redirect to
    # the result
    if(  $path =~ s!/{2,}!/!g ) {
        $c->log->debug("redirecting multi-/ request to /$path$query");
        $c->res->redirect( "/$path$query", 301 );
        return 1;
    }

    # try an internal redirect for index.pl files if the url has not
    # already been found and does not have an extension
    if( $path !~ m|\.\w{2,4}$| ) {
        if( my $index_action = $self->_find_cgi_action( $c, "$path/index.pl" ) ) {
            $c->log->debug("dispatching to action $index_action");
            $c->go( $index_action );
        }
    }

    # redirect away from cgi-bin URLs
    elsif( $path =~ s!cgi-bin/!! ) {
        $c->log->debug("redirecting cgi-bin url to /$path$query");
        $c->res->redirect( "/$path$query", 301 );
        return 1;
    }

}

sub _find_cgi_action {
    my ($self,$c,$path) = @_;

    $path =~ s!/+!/!g;
     my $cgi = $c->controller('CGIAdaptor')
         or return;

    my $action_name = $cgi->cgi_action($path);
    $c->log->debug("checking for CGI index action $action_name");

    my $index_action = $cgi->action_for( $action_name )
        or return;

    $c->log->debug("found CGI index action '$index_action'");

    return $index_action;
}


=head2 auto

Run for every request to the site.

=cut

sub auto : Private {
    my ($self, $c) = @_;
    CatalystX::GlobalContext->set_context( $c );
    1;
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Robert Buels,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

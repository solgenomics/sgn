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

    my $path = $c->req->path;
    unless( $path =~ m|\.\w{2,4}$| ) {
        # look for an index.pl if not found
        $path =~ s!/+$!!;
        if( my $cgi = $c->controller('CGIAdaptor') ) {
            my $action_name = $cgi->cgi_action("$path/index.pl");
            $c->log->debug("checking for CGI index action $action_name");
            if( my $index_action = $cgi->action_for( $action_name ) ) {
                $c->log->debug("dispatching to CGI index action '$index_action'");
                $c->go( $index_action );
            }
        }
    }

    $c->response->body( 'Page not found' );
    $c->response->status(404);
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

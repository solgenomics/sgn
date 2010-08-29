package SGN::Controller::Project::Secretom;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

__PACKAGE__->config(
    namespace => 'secretom',
   );

=head1 NAME

SGN::Controller::Project::Secretom - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Does nothing, just forwards to the default template
(/secretom/index.mas), see L<Catalyst::Action::RenderView>.

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    #$c->response->body('Matched SGN::Controller::Project::Secretom in Project::Secretom.');
}

=head2 default

Just forwards to the template indicated by the request path.

=cut

sub default :Path {
    my ( $self, $c, @args ) = @_;
    my $path = join '/', $self->action_namespace, @args;
    if( $path =~ s/\.pl$// ) { #< attempt to su
        $c->res->redirect( $path, 301 );
    }
    $c->stash->{template} = "$path.mas"
}

=head2 auto

Sets some config needed by the templates.

=cut

sub auto :Private {
    my ( $self, $c, @args ) = @_;

    # set the root dir for secretom static files.  used by some of the
    # templates.
    $c->stash->{static_dir} = $c->path_to( $c->config->{root}, 'data' );
}


=head1 AUTHOR

Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;


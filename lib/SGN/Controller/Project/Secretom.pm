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

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    #$c->response->body('Matched SGN::Controller::Project::Secretom in Project::Secretom.');
}

sub default :Path {

}


=head1 AUTHOR

Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;


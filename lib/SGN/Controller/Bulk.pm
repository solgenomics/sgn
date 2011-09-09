package SGN::Controller::Bulk;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::Bulk - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub bulk_feature :Path('/bulk/feature') :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched SGN::Controller::Bulk in Bulk.');
}


=head1 AUTHOR

Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

package SGN::Controller::Bulk;
use Moose;
use namespace::autoclean;

BEGIN {extends 'SGN::Controller::Feature'; }

=head1 NAME

SGN::Controller::Bulk - Bulk Feature Controller

=head1 DESCRIPTION

Catalyst Controller which allows bulk download of features.

=head1 METHODS

=cut


=head2 index

=cut

sub bulk_feature :Path('/bulk/feature') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash( template => 'bulk.mason');
}

sub bulk_feature_download :Path('/bulk/feature/download') :Args(0) {
    my ( $self, $c ) = @_;

    my $req = $c->req;
    $c->stash( sequence_identifiers => $req->param('ids') );

    $c->forward('fetch_sequences');

    $c->stash( template => 'bulk_download.mason' );
}


=head1 AUTHOR

Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

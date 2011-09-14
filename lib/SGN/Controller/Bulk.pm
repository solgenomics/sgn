package SGN::Controller::Bulk;
use Moose;
use namespace::autoclean;
use Cache::File;
use Digest::SHA1 qw/sha1_hex/;

has cache => (
    isa        => 'Cache::File',
    lazy_build => 1,
    is         => 'ro',
);

use File::Path qw/mkpath/;

sub _build_cache {
    my $self = shift;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk feature/));
    my $lock_cache_dir = $app->path_to($app->tempfiles_subdir(qw/cache bulk feature lock/));

    # since the lock directory is deeper, this will autocreate the $cache_dir as well
    mkpath($lock_cache_dir) unless -d $lock_cache_dir;

    return Cache::File->new(
           cache_root       => $cache_dir,
           default_expires  => '2 days',
           # TODO: how big can the output of 10K identifiers be?
           size_limit       => 10_000_000,
           removal_strategy => 'Cache::RemovalStrategy::LRU',
          );
};

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

    my $req  = $c->req;
    my $ids  = $req->params('ids');
    my $sha1 = sha1_hex($ids);

    if( $self->cache->get( $sha1 ) ) {
        # bulk download is cached already
    } else {
        warn "setting ids to $ids";
        $c->stash( sequence_identifiers => $ids );

        $c->forward('Controller::Sequence', 'fetch_sequences');

        $self->cache->set( $sha1 => $c->stash->{sequences} );
    }

    $c->stash( template => 'bulk_download.mason', sha1 => $sha1 );
}


=head1 AUTHOR

Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

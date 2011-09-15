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

use File::Path qw/make_path/;

sub _build_cache {
    my $self = shift;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk feature/));

    $app->log->debug("Bulk: creating new cache in $cache_dir");

    return Cache::File->new(
           cache_root       => $cache_dir,
           default_expires  => 'never',
           # TODO: how big can the output of 10K identifiers be?
           size_limit       => 10_000_000,
           removal_strategy => 'Cache::RemovalStrategy::LRU',
           # temporary, until we figure out locking issue
           lock_level       => Cache::File::LOCK_NFS,
          );
};

BEGIN {extends 'Catalyst::Controller' }

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

    # trigger cache creation
    $self->cache->get("");
}

sub bulk_feature_download :Path('/bulk/feature/download') :Args(1) {
    my ( $self, $c, $sha1 ) = @_;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk feature/));

    $sha1 =~ s/\.fasta$//g;

    my $seqs = $self->cache->get($sha1);

    $c->stash( sequences => $seqs );

    $c->forward( 'View::SeqIO' );
}

sub bulk_feature_submit :Path('/bulk/feature/submit') :Args(0) {
    my ( $self, $c, $file ) = @_;

    my $req  = $c->req;
    my $ids  = $req->param('ids');
    my $sha1 = sha1_hex($ids);

    if( $self->cache->get( $sha1 ) ) {
        # bulk download is cached already
    } else {
        $c->stash( sequence_identifiers => [ split /\s+/, $ids ] );

        $c->forward('Controller::Sequence', 'fetch_sequences');

        $self->cache->set( $sha1 , $c->stash->{sequences} );
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

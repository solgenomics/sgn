package SGN::Controller::Bulk;
use Moose;
use 5.010;
use namespace::autoclean;
use Cache::File;
use Digest::SHA1 qw/sha1_hex/;
use File::Path qw/make_path/;
use CXGN::Page::FormattingHelpers qw/modesel/;
use CXGN::Tools::Text qw/trim/;
use SGN::View::Feature qw/mrna_and_protein_sequence/;

BEGIN { extends 'Catalyst::Controller' }

has feature_cache => (
    isa        => 'Cache::File',
    lazy_build => 1,
    is         => 'ro',
);

has gene_cache => (
    isa        => 'Cache::File',
    lazy_build => 1,
    is         => 'ro',
);


sub _build_feature_cache {
    my $self = shift;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk feature/));

    _new_cache_file($app, $cache_dir);
};

sub _build_gene_cache {
    my $self = shift;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk gene/));

    _new_cache_file($app, $cache_dir);
};

sub _new_cache_file {
    my ($app, $cache_dir) = @_;
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
}


=head1 NAME

SGN::Controller::Bulk - Bulk Download Controller

=head1 DESCRIPTION

Catalyst Controller which takes care of bulk downloads. Currently
supports features and genes.

=cut

sub bulk_download_stats :Local {
    my ( $self, $c ) = @_;

    my $seqs    = scalar @{$c->stash->{sequences} || []};
    my $seq_ids = scalar @{$c->stash->{sequence_identifiers} || []};
    my $stats   = <<STATS;
A total of $seqs out of $seq_ids sequence identifiers were found.
STATS

    $c->stash( bulk_download_stats   => $stats );
    $c->stash( bulk_download_success => $seqs );
}

sub bulk_js_menu :Local {
    my ( $self, $c ) = @_;

    my $mode = $c->stash->{bulk_js_menu_mode};
    # define urls of modes
    my @mode_links = (
        [ '/bulk/input.pl?mode=clone_search',    'Clone&nbsp;name<br />(SGN-C)' ],
        [ '/bulk/input.pl?mode=microarray',      'Array&nbsp;spot&nbsp;ID<br />(SGN-S)' ],
        [ '/bulk/input.pl?mode=unigene',         'Unigene&nbsp;ID<br />(SGN-U)' ],
        [ '/bulk/input.pl?mode=bac',             'BACs' ],
        [ '/bulk/input.pl?mode=bac_end',         'BAC&nbsp;ends' ],
        [ '/bulk/input.pl?mode=ftp',             'Full&nbsp;datasets<br />(FTP)' ],
        [ '/bulk/input.pl?mode=unigene_convert', 'Unigene ID Converter<br />(SGN-U)' ],
        [ '/bulk/feature',                       'Features' ],
        [ '/bulk/gene',                          'Genes' ],
    );

    ### figure out which mode we're in ###
    my $modenum =
      $mode =~ /clone_search/i    ? 0
    : $mode =~ /array/i           ? 1
    : $mode =~ /unigene_convert/i ? 6
    : $mode =~ /unigene/i         ? 2
    : $mode =~ /bac_end/i         ? 4
    : $mode =~ /bac/i             ? 3
    : $mode =~ /ftp/i             ? 5
    : $mode =~ /feature/i         ? 7
    : $mode =~ /gene/i            ? 8
    :                               0;    # clone search is default

    $c->stash( bulk_js_menu => modesel( \@mode_links, $modenum ) );

}

sub bulk_gene :Path('/bulk/gene') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('bulk_js_menu');

    $c->stash( template => 'bulk_gene.mason');
}

sub bulk_gene_submit :Path('/bulk/gene/submit') :Args(0) {
    my ( $self, $c, $file ) = @_;
    my $mode = $c->req->param('mode') || 'feature';

    $c->stash( bulk_js_menu_mode => $mode );
    $c->forward('bulk_js_menu');

    my $req  = $c->req;
    my $ids  = $req->param('ids');
    my $type = $req->param('gene_type');

    unless ($type ~~ [qw/cdna cds protein/]) {
        $c->throw_client_error(public_message => 'Invalid data type chosen');
    }

    if( $c->req->param('gene_file') ) {
        my ($upload) = $c->req->upload('gene_file');
        # always append contents of file with newline to form input to
        # prevent smashing identifiers together
        $ids        = "$ids\n" . $upload->slurp if $upload;
    }

    # Must calculate this after looking at file contents
    # Take into account data type, because different data types for the same sequence list
    # produce different results
    my $sha1 = sha1_hex("$type $ids");

    # remove leading and trailing whitespace
    $ids = trim($ids);

    unless ($ids) {
        $c->throw_client_error(public_message => 'At least one identifier must be given');
    }

    # TODO: this doesn't scale. Use a single OR clause?
    my $success = 0;
    my @mps;
    for my $gene_id (split /\s+/, $ids) {
        my $matching_features = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado')
                                     ->resultset('Sequence::Feature')
                                     ->search({ "me.name" => $gene_id },{
                                        prefetch => [ 'type', 'featureloc_features' ],
                                     });
        my $f     = $matching_features->next;
        $c->log->debug("found feature type " . $f->type->name);
        next unless $f->type->name eq 'gene';

        my @mrnas = grep $_->type->name eq 'mRNA', $f->child_features;
        $c->log->debug("Found " . scalar(@mrnas) . " mrna seq ids");
        $success++ if @mrnas;

        # depending on form values, push different data
        my @seqs = (map { mrna_and_protein_sequence($_) } @mrnas );

        push @mps, map {
            # TODO: this is hack. doesn't work for CDS
            my $o = $_->[$type eq 'protein' ? 1 : 0];
            Bio::PrimarySeq->new(
                -id => $o->name,
                -desc => $o->description,
                -seq  => $o->seq,
            );
        } @seqs;

    }
    $c->stash( sha1                  => $sha1 );

    # cache the sequences
    $self->gene_cache->freeze( $sha1 , [ @mps ] );

    $c->stash( bulk_download_success => $success );
    $c->stash( bulk_download_stats   => <<STATS);
Insert stats
STATS
    $c->stash( template              => 'bulk_gene_download.mason');
}

sub bulk_gene_download :Path('/bulk/gene/download') :Args(1) {
    my ( $self, $c, $sha1 ) = @_;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk gene/));

    $sha1 =~ s/\.(fasta|txt)$//g;

    my $seqs = $self->gene_cache->thaw($sha1);

    $c->stash->{sequences} = $seqs;
    $c->forward('View::SeqIO');
}

sub bulk_feature :Path('/bulk/feature') :Args(0) {
    my ( $self, $c ) = @_;
    my $mode = $c->req->param('mode') || 'feature';

    $c->stash( bulk_js_menu_mode => $mode );

    $c->forward('bulk_js_menu');

    $c->stash( template => 'bulk.mason');

    # trigger cache creation
    $self->feature_cache->get("");
}

sub bulk_feature_download :Path('/bulk/feature/download') :Args(1) {
    my ( $self, $c, $sha1 ) = @_;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk feature/));

    $sha1 =~ s/\.(fasta|txt)$//g;

    my $seqs = $self->feature_cache->thaw($sha1);

    $c->stash( sequences => $seqs->[1] );

    $c->forward( 'View::SeqIO' );
}

sub bulk_feature_submit :Path('/bulk/feature/submit') :Args(0) {
    my ( $self, $c, $file ) = @_;

    my $req  = $c->req;
    my $ids  = $req->param('ids') || '';
    my $mode = $req->param('mode') || 'feature';

    $c->stash( bulk_js_menu_mode => $mode );

    if( $c->req->param('feature_file') ) {
        my ($upload) = $c->req->upload('feature_file');
        # always append contents of file with newline to form input to
        # prevent smashing identifiers together
        $ids        = "$ids\n" . $upload->slurp if $upload;
    }

    # Must calculate this after looking at file contents
    my $sha1 = sha1_hex($ids);

    # remove leading and trailing whitespace
    $ids = trim($ids);

    unless ($ids) {
        $c->throw_client_error(public_message => 'At least one identifier must be given');
    }

    $c->stash( sequence_identifiers => [ split /\s+/, $ids ] );

    $c->stash( bulk_query => 1 );

    $c->forward('Controller::Sequence', 'fetch_sequences');

    $self->feature_cache->freeze( $sha1 , [ $c->stash->{sequence_identifiers}, $c->stash->{sequences} ] );

    $c->forward('bulk_js_menu');
    $c->forward('bulk_download_stats');

    $c->stash( template          => 'bulk_download.mason', sha1 => $sha1 );
}


=head1 AUTHOR

Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

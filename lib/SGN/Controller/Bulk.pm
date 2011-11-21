package SGN::Controller::Bulk;
use 5.010;
use Moose;
use namespace::autoclean;
use Cache::File;
use Digest::SHA1 qw/sha1_hex/;
use File::Path qw/make_path/;
use CXGN::Page::FormattingHelpers qw/modesel/;
use CXGN::Tools::Text qw/trim/;
use SGN::View::Feature qw/mrna_cds_protein_sequence get_descriptions/;
#use Carp::Always;

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
    $app->log->debug("Bulk: creating new cache in $cache_dir") if $app->debug;
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

    $c->log->debug("calculating bulk download stats") if $c->debug;

    my $seqs    = scalar @{$c->stash->{sequences} || []};
    my $seq_ids = scalar @{$c->stash->{sequence_identifiers} || []};
    my $stats   = <<STATS;
A total of $seqs matching features were found for $seq_ids identifiers provided.
STATS

    $c->stash( bulk_download_stats   => $stats );
    $c->stash( bulk_download_success => $seqs );
}

sub bulk_js_menu :Local {
    my ( $self, $c ) = @_;

    my $mode = $c->stash->{bulk_js_menu_mode} || '';
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

    $c->stash( bulk_js_menu =>
                   $c->view('BareMason')->render( $c, '/page/page_title.mas', { title => 'Bulk download' })
                   .<<EOH
<div style="margin-bottom: 1em">Download Unigene or BAC information using a list of identifiers, or complete datasets with FTP.</div>
EOH
                  .modesel( \@mode_links, $modenum ),
             );

}

sub bulk_gene :Path('/bulk/gene') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('bulk_js_menu');

    if( my $ids = $c->req->params->{'ids'} ) {
        $c->stash( prefill_ids => $ids );
    }

    $c->stash( template => 'bulk_gene.mas');
}

sub bulk_gene_type_validate :Local :Args(0) {
    my ( $self, $c ) = @_;
    my $req  = $c->req;
    my $type = $req->param('gene_type');

    unless ($type && $type ~~ [qw/cdna cds protein/]) {
        $c->throw_client_error(
            public_message => 'Invalid data type chosen',
            http_status    => 200,
        );
    }
}

sub bulk_gene_submit :Path('/bulk/gene/submit') :Args(0) {
    my ( $self, $c ) = @_;
    my $req  = $c->req;
    my $ids  = $req->param('ids');
    my $type = $req->param('gene_type');
    my $mode = $req->param('mode') || 'gene';

    $c->stash( bulk_js_menu_mode => $mode );
    $c->forward('bulk_js_menu');

    $c->log->debug("submitting query with type=$type") if $c->debug;

    $c->forward('bulk_gene_type_validate');

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
    $c->stash( sha1                  => $sha1 );

    # remove leading and trailing whitespace
    $ids = trim($ids);

    unless ($ids) {
        $c->throw_client_error(
            public_message => 'At least one identifier must be given',
            http_status    => 200,
        );
    }

    $c->forward('cache_gene_sequences');

    $c->stash( bulk_download_stats   => <<STATS);
Insert stats
STATS
    $c->stash( template              => 'bulk_gene_download.mas');
}

sub cache_gene_sequences :Local :Args(0) {
    my ($self, $c) = @_;
    my $req  = $c->req;
    my $ids  = $req->param('ids');
    my $type = $req->param('gene_type');
    my $sha1 = $c->stash->{sha1};

    my $success = 0;
    my @gene_ids = split /\s+/, $ids;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $genes_by_name =
        $schema->resultset('Sequence::Feature')
               ->search({
                   "me.name" => \@gene_ids,
                   'me.type_id' => $schema->get_cvterm_or_die('sequence:gene')->cvterm_id,
               });
    my $genes_by_synonym =
        $schema->resultset('Sequence::Synonym')
               ->search({ 'me.name' => \@gene_ids })
               ->search_related('feature_synonyms')
               ->search_related('feature',{
                   'feature.type_id' => $schema->get_cvterm_or_die('sequence:gene')->cvterm_id,
                 });

    my %seen_mrna;
    my @mrnas =
        grep !$seen_mrna{$_->feature_id}++,
        map {
            $_->search_related( 'feature_relationship_objects', {
                    'feature_relationship_objects.type_id' => $schema->get_cvterm_or_die('relationship:part_of')->cvterm_id,
                 })
              ->search_related( 'subject', {
                  'subject.type_id' => $schema->get_cvterm_or_die('sequence:mRNA')->cvterm_id,
                 },
                 { prefetch => 'featureprops' },
                )
        } ( $genes_by_name, $genes_by_synonym );

    $c->stash(
        gene_mrnas            => \@mrnas,
        bulk_download_success => scalar(@mrnas),
      );
    $c->forward('convert_sequences_to_bioperl_objects');
    $c->forward('populate_gene_sequences');
    $c->forward('freeze_sequences');
}

sub convert_sequences_to_bioperl_objects :Local {
    my ($self, $c) = @_;
    my @mrnas = @{$c->stash->{gene_mrnas}};
    my @seqs = (map { mrna_cds_protein_sequence($_) } @mrnas );
    $c->stash( gene_sequences => \@seqs );
}

sub freeze_sequences :Local {
    my ($self, $c) = @_;
    # cache the sequences
    $self->gene_cache->freeze( $c->stash->{sha1} , $c->stash->{gene_mps} || [ ] );
}

sub populate_gene_sequences :Local {
    my ($self, $c) = @_;
    my $req        = $c->req;
    my $type       = $req->param('gene_type');
    my $type_index = {
        cdna    => 0,
        cds     => 1,
        protein => 2,
    };
    my @mps;

    push @mps, map {
        my $index = $type_index->{$type};
        $c->log->debug("found $type with index $index") if $c->debug;

        unless (defined $index) {
            $c->throw_client_error(
                public_message => 'Invalid data type',
                http_status    => 200,
            );
        }

        my $o = $_->[$index];
        unless (defined $o) {
            ()  # if it's not defined, we don't have that type of seq for this gene
        } elsif( $o->isa('DBIx::Class::Row') ) {
            $c->log->debug("Downgrading from BCS to Bioperl object " . $o->name) if $c->debug;
            my @desc = get_descriptions($o,'plain');
            my $g    = Bio::PrimarySeq->new(
                -id   => $o->primary_id,
                -desc => join(', ', @desc),
                -seq  => $o->seq,
            );
        } else {
            $o
        }
    } @{ $c->stash->{gene_sequences} };
    $c->stash( gene_mps => [ @mps ] );
}

sub bulk_gene_download :Path('/bulk/gene/download') :Args(1) {
    my ( $self, $c, $sha1 ) = @_;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk gene/));

    $sha1 =~ s/\.(fasta|txt)$//g;

    my $seqs = $self->gene_cache->thaw($sha1)
        or $c->throw_404('Bulk dataset not found');

    $c->stash->{sequences} = $seqs;
    $c->forward('View::SeqIO');
}

sub bulk_feature :Path('/bulk/feature') :Args(0) {
    my ( $self, $c ) = @_;
    my $mode = $c->req->params->{'mode'} || 'feature';

    $c->stash( bulk_js_menu_mode => $mode );

    if( my $ids = $c->req->params->{'ids'} ) {
        $c->stash( prefill_ids => $ids );
    }

    $c->forward('bulk_js_menu');

    $c->stash( template => 'bulk.mas');

    # trigger cache creation
    $self->feature_cache->get("");
}

sub bulk_feature_download :Path('/bulk/feature/download') :Args(1) {
    my ( $self, $c, $sha1 ) = @_;

    my $app            = $self->_app;
    my $cache_dir      = $app->path_to($app->tempfiles_subdir(qw/cache bulk feature/));

    $sha1 =~ s/\.(fasta|txt)$//g;

    my $seqs = $self->feature_cache->thaw($sha1)
        or $c->throw_404('Bulk dataset not found');

    $c->stash( sequences => $seqs->[1] );

    $c->forward( 'View::SeqIO' );
}

sub bulk_feature_submit :Path('/bulk/feature/submit') :Args(0) {
    my ( $self, $c ) = @_;

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

    $c->log->debug("fetching sequences") if $c->debug;
    $c->forward('Controller::Sequence', 'fetch_sequences');

    $c->log->debug("freezing sequences") if $c->debug;
    $self->feature_cache->freeze( $sha1 , [ $c->stash->{sequence_identifiers}, $c->stash->{sequences} ] );

    $c->forward('bulk_js_menu');
    $c->forward('bulk_download_stats');

    $c->stash( template  => 'bulk_download.mas', sha1 => $sha1 );
}


=head1 AUTHOR

Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

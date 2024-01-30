package SGN::Controller::Sequence;

=head1 NAME

SGN::Controller::Sequence - Catalyst controller for dealing with sequences

=head1 DESCRIPTION

Right now, only knows how to fetch sequences from BCS features.

=cut

use Moose;
use namespace::autoclean;

use HTML::Entities;

BEGIN { extends 'Catalyst::Controller' }

=head1 PUBLIC ACTIONS

=head2 gmodrpc_fetch_seq

Public path: /gmodrpc/v1.1/fetch/seq/<name or id>.fasta?start..end

Just forwards to api_v1_single_sequence

=cut

sub gmodrpc_fetch_seq :Path('/gmodrpc/v1.1/fetch/seq') :Args(1) {
    my ( $self, $c, $name ) = @_;
    $c->forward( 'api_v1_single_sequence', [ $name ] );
}

=head2 api_v1_single_sequence

Public path: /api/v1/sequence/<name or id>.fasta?start..end

?start..end is optional.  If start E<gt> end, does reverse complement.

=cut

sub api_v1_single_sequence :Path('/api/v1/sequence/download/single') :Args(1) {
    my ( $self, $c, $name ) = @_;

    if( $name =~ s/\.([^\.]+)$// ) {
        $c->stash->{seqio_format} = $1;
    }

    if( my $kw = $c->request->query_keywords ) {
        $name .= ":$kw";
    }

    $c->stash->{sequence_identifiers} = [ $name ];
    $c->forward( 'fetch_sequences'    );
    $c->forward( 'download_sequences' );
}

=head2 api_v1_multi_sequence

Public path: /api/v1/sequence/download/multi

Query params:

    s: multi-valued, holds identifiers to download.  Each
       identifier may have a :start..end appended to take a
       subsequence. (Reverse complement if start > end).

=cut

sub api_v1_multi_sequence :Path('/api/v1/sequence/download/multi') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{sequence_identifiers} = $c->req->parameters->{'s'};
    $c->stash->{seqio_format} = $c->req->parameters->{'format'};

    $c->forward( 'fetch_sequences'    );
    $c->forward( 'download_sequences' );
}

=head1 PRIVATE ACTIONS

=head2 download_sequences

=cut

sub download_sequences :Private {
    my ( $self, $c ) = @_;

    # set an appropriate download filename, and the appropriate
    # headers to trigger a file download
    $c->stash->{download_filename} = $c->stash->{sequences} && @{$c->stash->{sequences}} == 1
        ? $c->stash->{sequences}->[0]->id.'.fasta'
        : 'SGN_sequence_download.fasta';
    $c->forward('/download/set_download_headers');

    $c->forward( 'View::SeqIO' );
}

=head2 fetch_sequences

=cut

sub fetch_sequences :Private {
    my ( $self, $c ) = @_;
    my $sequence_idents = $c->stash->{sequence_identifiers};
    $sequence_idents = [ $sequence_idents ] unless ref $sequence_idents;

    # parse out region descriptions in any of the sequence idents
    for my $id (@$sequence_idents) {
        # full format looks like myseqID1123:455..43255.  if start is
        # greater than end, means revcom
        if( $id =~ s/ : ([\d,]+) \.\. ([\d,]+) $ //x ) {
            my ( $start, $end ) = ( $1, $2 );
            s/,//g for $start, $end;
            my $strand = '+';
            if( $start > $end ) {
                ( $start, $end ) = ( $end, $start );
                $strand = '-';
            }
            $id = [ $id, $strand, $start, $end ];
        } else {
            $id = [ $id, undef, undef, undef ];
        }
    }

    # find the feature(s) for each ID and convert them to
    # Bio::PrimarySeqs
    my @sequences;
    for ( @$sequence_idents ) {
        my ( $id, $strand, $start, $end ) = @$_;
        my $rs = $self->_feature_rs( $c, $id );

        my $found = 0;
        while( my $feature = $rs->next ) {
            push @sequences, $self->_feature_to_primaryseq( $feature, $strand, $start, $end );
            $found = 1;
        }
        # if there is only one sequence identifier, not finding it should throw a 404
        # otherwise, ignore it so bulk downloads via the multi api still work
        # Bulk queries always ignore all invalid identifiers
        if( @$sequence_idents == 1 and !$c->stash->{bulk_query} ){
            $found or $c->throw_404( sprintf('No sequence found with id "%s"', encode_entities( $id )) );
        }
    }

    $c->stash->{sequences} = \@sequences;
}

######## HELPERS

# searches for features given a name or ID.  Assumes it's a feature ID
# if all-numeric.
sub _feature_rs {
    my ( $self, $c, $id ) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $features_rs =
        $c->dbic_schema('Bio::Chado::Schema','sgn_chado', $sp_person_id)
          ->resultset('Sequence::Feature');

    if( $id =~ /\D/ ) {
        $features_rs = $features_rs->search({ name => $id });
    } else {
        $features_rs = $features_rs->search({ feature_id => $id });
    }

    return $features_rs;
}

# converts a feature to a Bio::PrimarySeq, applying a subsequence and
# revcom if necessary
sub _feature_to_primaryseq {
    my ( $self, $feature, $strand, $start, $end ) = @_;

    my $seq_id = $feature->name || 'feature_'.$feature->feature_id;
    if( $start && $end ) {
        $seq_id .= $strand && $strand eq '-' ? ":$end..$start" : ":$start..$end";
    }

    my $seq = Bio::PrimarySeq->new(
        -id   => $seq_id,
        ( $feature->desc ? ( -desc => $feature->desc ) : () ),
        -seq  => $feature->subseq( ($start || 1), ($end || $feature->length) ),
      );
    $seq = $seq->revcom if $strand && $strand eq '-';

    return $seq;
}

__PACKAGE__->meta->make_immutable;

1;


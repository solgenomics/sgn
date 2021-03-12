use strict;
use warnings;

package Bio::BLAST2::Database::Seq;
BEGIN {
  $Bio::BLAST2::Database::Seq::AUTHORITY = 'cpan:RBUELS';
}
BEGIN {
  $Bio::BLAST2::Database::Seq::VERSION = '0.4';
}

# ABSTRACT: lazy-loading sequence from a BLAST database


use Carp;

use Bio::PrimarySeq;
use Bio::Seq::LargePrimarySeq;

use base 'Bio::PrimarySeqI';


sub new {
    my ( $class, %args ) = @_;
    my $self = bless {}, $class;

    # strip leading '-' on args
    for my $k ( keys %args ) {
        ( my $nk = $k ) =~ s/^-//;
        $self->{ $nk } = $args{$k}
    }

    $self->{$_} or croak "must give $_!"
       for 'bdb', 'id';

    #read the defline out of the bdb
    my $s = $self->trunc(1,1)
      or return;
    $self->{desc} = $s->desc;

    return $self;
}


sub seq {
    my $self = shift;
    croak ref($self)." objects are immutable, cannot set seq" if @_;

    return $self->whole_seq->seq;
}
sub length {
    my $self = shift;
    croak ref($self)." objects are immutable, cannot set length" if @_;

    return $self->whole_seq->length;
}


sub whole_seq {
    my ( $self ) = @_;

    return $self->{seq_obj} ||= do {
        my $ffbn    = $self->_bdb->full_file_basename;
        my $seqname = $self->id;
        CORE::open my $fc, "blastdbcmd -db '$ffbn' -entry '$seqname' 2>&1 |";

        # we can't know how big this sequence is.  blastdbcmd has no way (or
        # at least no documented way) to query seq lengths.  so we need to
        # treat the sequence as if it were big.  cause sometimes it is.
        # so we parse as if it is going to be large
        $self->_parse_large_seq( $fc )
    };
}

sub trunc {
    my ($self, $start, $end ) = @_;

    croak "start ($start) is greater than end ($end)" if $start > $end;

    $_ += 0 for $start, $end; # ensure numeric

    my $length = $end - $start + 1;

    my $ffbn    = $self->_bdb->full_file_basename;
    my $seqname = $self->id;
    open my $fc, "blastdbcmd -db '$ffbn' -entry '$seqname' -range $start-$end 2>&1 |";

    return $length > 4_000_000
                ? $self->_parse_large_seq( $fc )
                : $self->_parse_small_seq( $fc );
}

sub subseq {
    shift->trunc( @_ )->seq;
}

sub alphabet {
    my $self = shift;
    croak ref($self)." objects are immutable, cannot set seq" if @_;

    my $type = $self->_bdb->type
        or return;

    return 'dna'     if $type eq 'nucleotide';
    return 'protein' if $type eq 'protein';

    die "invalid type '$type' for blast database ".$self->_bdb->full_file_basename;
}


sub id               { $_[0]->{id}   }


sub desc             { $_[0]->{desc} }
*description = \&desc;

sub accession_number { 'unknown'     }
sub display_id       { $_[0]->id     }
sub primary_id       { $_[0]->id     }
sub _bdb             { $_[0]->{bdb}  }

########### helpers ################3

# takes blastdbcmd filehandle that is going to be emitting a big
# sequence and makes a LargePrimarySeq out of it
sub _parse_large_seq {
    my ( $self, $fc ) = @_;

    my ( $id, $defline ) = $self->_parse_defline( $fc ) or return;

    # stream the sequence into a LargePrimarySeq, read up to 4 MiB of
    # sequence at a time
    my $seq = Bio::Seq::LargePrimarySeq->new( -id => $id, -desc => $defline );
    local $/ = \4_000_000;
    while( my $seq_chunk = <$fc> ) {
        $seq_chunk =~ s/\s//g;
        $seq->add_sequence_as_string( $seq_chunk );
    }

    return $seq;
}

sub _parse_small_seq {
    my ( $self, $fc ) = @_;

    my ( $id, $defline ) = $self->_parse_defline( $fc ) or return;

    # slurp the rest of the sequence and return a PrimarySeq
    local $/;
    my $seq = <$fc>;
    $seq =~ s/\s//g;

    return Bio::PrimarySeq->new(
        -id   => $id,
        -desc => $defline,
        -seq  => $seq,
        );
}

sub _parse_defline {
    my ( $self, $fc ) = @_;

    my $defline = <$fc>;

    print STDERR "DEFLINE RETRIEVED = $defline\n";
    
    return if $defline =~ /ERROR:\s+Entry\s*"[^"]+"\s+not found/;
    ( my $id, $defline ) = $defline =~ m(
                                          >(?:lcl\|)?(\S+) \s+ (.*)
                                            )x
   #( my $id, $defline ) = $defline =~ m(
    #                                      >(\S+)\s+(.*)
     #                                       )x

    
    
               or die "could not parse blastdbcmd output\n:$defline";

    undef $defline if $defline =~ /^No definition line found\.?$/;

    return ( $id, $defline );
}


1;

__END__
=pod

=encoding utf-8

=head1 NAME

Bio::BLAST2::Database::Seq - lazy-loading sequence from a BLAST database

=head1 DESCRIPTION

Implements all methods in L<Bio::PrimarySeqI>.  Lazily loads its
sequence information from the BLAST database it comes from, meaning
that the sequence information is not actually loaded until you ask for
it.  Uses L<Bio::Seq::LargePrimarySeq> internally when sequences are
large, so can handle arbitrarily large sequences relatively well.

=head1 METHODS

=head2 new

For use by Bio::BLAST2::Database only.

Takes args -id and -bdb, which are the sequence's ID and the
Bio::BLAST2::Database object it's from, respectively.

=head2 whole_seq

Return a non-lazy L<Bio::PrimarySeqI>-implementing object containing
the entire sequence.  Most developers should not need this.

=head2 id

Read-only.  Return this sequence's identifier.

=head2 desc, description

Read only, return the description line, if any, for this sequence.

=head1 SEE ALSO

L<Bio::PrimarySeqI>

=head1 AUTHOR

Robert Buels <rmb32@cornell.edu>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Robert Buels.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


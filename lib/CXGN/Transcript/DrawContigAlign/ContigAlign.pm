=head1 NAME

CXGN::Transcript::DrawContigAlign::ContigAlign - stores alignment data for a strand in a unigene.

=head1 SYNOPSIS

Initialize it with all of the relevant values and use accessors to access the data.

 $contigAlign = ContigAlign->new('Source ID', 'Sequence ID', '+', 10, 400, 20, 33, 1);
 $sourceID = $contigAlign->sourceID; #returns 'Source ID'

=head1 DESCRIPTION

ContigAlign stores alignment data for a strand in a unigene, primarily for use with CXGN::Transcript::DrawContigAlign, which uses it to store data that is being used to produce a graph.

=head1 AUTHORS

Rafael Lizarralde <xarbiogeek@gmail.com> (July 2009)

=head1 MEMBER FUNCTIONS

=head2 constructor C<new>

=over 10

=item Usage:

$contigAlign = CXGN::Transcript::DrawContigAlign::ContigAlign->new('Source ID', 'Sequence ID', '+', 10, 400, 20, 33, 1);

=item Ret:

a CXGN::Transcript::DrawContigAlign::ContigAlign object

=item Args:

=over 18

=item Str  $sourceID

the ID tag for the strand

=item Str  $sequenceID

the ID tag for the unigene

=item Str  $strand

identifier if the strand is complementary or not (if not, it should be '+')

=item Int  $startLoc

the base pair in the unigene's sequence at which this strand starts

=item Int  $endLoc

the base pair at which this strand ends

=item Int  $startTrim

the number of base pairs at the beginning that do not match

=item Int  $endTrim

the number of base pairs at the end that do not match

=item Bool $highlight

whether or not the strand should be highlighted on the graph

=back

=back

=head2 accessors:

=over 12

=item sourceID

returns a string with the ID tag for the strand

=item sequenceID

returns a string with the ID tag for the unigene

=item strand

returns a string with an identifier indicating whether the strand is complementary or not

=item  startLoc

returns an integer indicating the base pair at which this strand starts

=item endLoc

returns an integer indicating the base pair at which this strand ends

=item startTrim

returns an integer indicating the number of base pairs that do not match at the start

=item endTrim

returns an integer indicating the number of base pairs that do not match at the end

=item start

returns an integer indicating the first matching base pair (startLoc + startTrim)

=item end

returns an integer indicating the last matching base pair (endLoc - endTrim)

=item highlight

returns a boolean indicating whether this strand is highlighted

=back

=cut

package CXGN::Transcript::DrawContigAlign::ContigAlign;

use Moose;
use MooseX::Method::Signatures;

has sourceID   => (is => 'ro', isa => 'Str');
has sequenceID => (is => 'ro', isa => 'Str');
has strand     => (is => 'ro', isa => 'Str');
has startLoc   => (is => 'ro', isa => 'Int');
has endLoc     => (is => 'ro', isa => 'Int');
has startTrim  => (is => 'ro', isa => 'Int');
has endTrim    => (is => 'ro', isa => 'Int');
has start      => (is => 'ro', isa => 'Int');
has end        => (is => 'ro', isa => 'Int');
has highlight  => (is => 'ro', isa => 'Bool', default => undef);

sub BUILDARGS {
    my $class = shift;
    if(@_ == 8) {
	return { sourceID => $_[0], sequenceID => $_[1], strand => $_[2],
		 startLoc => $_[3], endLoc => $_[4], startTrim => $_[5], endTrim => $_[6],
		 start => $_[3] + $_[5], end => $_[4] - $_[6], highlight => $_[7],
	};
    } else { return $class->SUPER::BUILDARGS(@_); }
}

=head2 accessor C<compare>

=over 10

=item Usage:

print "contig1 is less than contig2!" if($contig1->compare($contig2) < 0);

=item Ret:

a negative value if the instance from which the method is called is less than the argument, zero if they are equal, and a positive value if the argument is greater

=item Args:

$other    another ContigAlign object

=back

=cut

method compare (CXGN::Transcript::DrawContigAlign::ContigAlign $other!) {
    ($self->start - $other->start != 0) ?
	return $self->start - $other->start:
	return $self->end - $other->end;
}
no Moose;
__PACKAGE__->meta->make_immutable;
return 1;

=head1 SEE ALSO

This is primarily used by CXGN::Transcript::DrawContigAlign, which, in turn, is used by CXGN::Transcript::Unigene.
DrawContigAlign also uses CXGN::Transcript::DrawContigAlign::DepthData and CXGN::Transcript::DrawContigAlign::Pane.

=cut

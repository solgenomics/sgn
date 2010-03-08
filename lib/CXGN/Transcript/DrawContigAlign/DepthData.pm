=head1 NAME

CXGN::Transcript::DrawContigAlign::DepthData - stores depth (y) and position (x) for a histogram

=head1 SYNOPSIS

Instantiate it with the position, but the depth is optional. Then use the mutator to increment the depth and the accessors to retreive the position and depth.

 $depth = CXGN::Transcript::DrawContigAlign::DepthData->new(340);
 $depth->increment;
 $depth->increment;
 $depth->position;  #returns 340
 $depth->depth;     #returns 2

=head1 DESCRIPTION

DepthData stores data for blocks on a histogram. Position refers to the startpoint of the block, and depth to the thickness of the block. In the context of CXGN::Transcript::DrawContigAlign, depth refers to the number of strands that span the distance between this position and the position of the next DepthData in the list.

=head1 AUTHORS

Rafael Lizarralde <xarbiogeek@gmail.com> (July 2009)

=head1 MEMBER FUNCTIONS

=head2 constructor C<new>

=over 10

=item Usage:

$depth = CXGN::Transcript::DrawContigAlign::DepthData->new(273);

=item Ret:

a CXGN::Transcript::DrawContigAlign::DepthData object

=item Args:

=over 12

=item position

describes the position of the depth data

=item depth

(optional) describes the depth the data at that position

=back

=back

=head2 accessor C<position>

=over 10

=item Usage:

$position = $depth->position;

=item Ret:

the position of the DepthData object

=item Args:

none

=back

=head2 accessor C<depth>

=over 10

=item Usage:

$depth = $depth->depth;

=item Ret:

the depth of the DepthData object

=item Args:

none

=back

=head1 SEE ALSO

This is primarily used by CXGN::Transcript::DrawContigAlign, which, in turn, is used by CXGN::Transcript::Unigene.
DrawContigAlign also uses CXGN::Transcript::DrawContigAlign::ContigAlign and CXGN::Transcript::DrawContigAlign::Pane.

=cut

package CXGN::Transcript::DrawContigAlign::DepthData;

use Moose;
use MooseX::Method::Signatures;

has position => (is => 'ro', isa => 'Int');
has depth    => (is => 'rw', isa => 'Int', default => 0);

sub BUILDARGS {
    my $class = shift;

    if(@_ == 1) {
	if(ref($_[0]) eq "ARRAY") {
	    return {
		position => $_[0]->[0],
		depth    => $_[0]->[1],
	    };
	}
	if(ref($_[0]) eq "") {
	    return { position => $_[0] };
	}
    } else {
	if(@_ == 2) { return { position => $_[0], depth => $_[1] }; }
	else { return $class->SUPER::BUILDARGS(@_); }
    }
}

=head2 accessor C<compare>

=over 10

=item Usage:

print "depth2 is before depth1!" if($depth1->compare($depth2) < 0);

=item Ret:

a negative value if the argument is before the instance from which the method is called, zero if they are equal, and a positive value if the argument is after

=item Args:

$other    another DepthData object

=back

=cut

method compare (CXGN::Transcript::DrawContigAlign::DepthData $other!) { return $self->position <=> $other->position; }

method increment { $self->depth($self->depth + 1); }

no Moose;
__PACKAGE__->meta->make_immutable;
return 1;

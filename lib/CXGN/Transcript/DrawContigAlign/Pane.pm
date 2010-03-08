=head1 NAME

CXGN::Transcript::DrawContigAlign::Pane - stores the dimensions of a rectangle for use with graphics

=head1 SYNOPSIS

This must be instantiated with all of its attributes as arguments, which are then read-only.

 $pane = CXGN::Transcript::DrawContigAlign::Pane->new(200, 500, 100, 600);
 $north = $pane->north; #returns 200
 $south = $pane->south; #returns 500
 $west  = $pane->west;  #returns 100
 $east  = $pane->east;  #returns 600

=head1 DESCRIPTION

This class keeps track of the dimensions of a rectangle, to be used as a pane in a graphic.

=head1 AUTHORS

Rafael Lizarralde <xarbiogeek@gmail.com> (July 2009)

=head1 MEMBER FUNCTIONS

=head2 constructor C<new>

=over 10

=item Usage:

$pane = CXGN::Transcript::DrawContigAlign::Pane->new(200, 500, 100, 600);

=item Ret:

a CXGN::Transcript::DrawContigAlign::Pane object

=item Args:

=over 10

=item north

the height of the upper edge

=item south

the height of the lower edge

=item west

the horizontal position of the left edge

=item east

the horizontal position of the right edge

=back

=back

=head2 accessor C<north>

=over 10

=item Usage:

$north = $pane->north;

=item Ret:

the vertical position of the upper edge

=item Args:

none

=back

=head2 accessor C<south>

=over 10

=item Usage:

$south = $pane->south;

=item Ret:

the vertical position of the lower edge

=item Args:

none

=back

=head2 accessor C<west>

=over 10

=item Usage:

$west = $pane->west;

=item Ret:

the horizontal position of the left edge

=item Args:

none

=back

=head2 accessor C<east>

=over 10

=item Usage:

$east = $pane->east;

=item Ret:

the horizontal position of the right edge

=item Args:

none

=back

=cut

package CXGN::Transcript::DrawContigAlign::Pane;

use Moose;

has north => (is => 'ro', isa => 'Int');
has south => (is => 'ro', isa => 'Int');
has west  => (is => 'ro', isa => 'Int');
has east  => (is => 'ro', isa => 'Int');

sub BUILDARGS {
    my $class = shift;

    if(@_ == 1 and ref($_[0]) eq "ARRAY") {
	    return {
		north => $_[0]->[0],
		south => $_[0]->[1],
		west  => $_[0]->[2],
		east  => $_[0]->[3],
	    };
    } else {
	if(@_ == 4) {
	    return {
		north => $_[0],
		south => $_[1],
		west  => $_[2],
		east  => $_[3],
	    };
	} else { return $class->SUPER::BUILDARGS(@_); }
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

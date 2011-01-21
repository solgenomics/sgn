
=head1 NAME

SGN::Build::ChangeLog::Release - a release entry in the changelog

=head1 SYNOPSIS

  my $change = $changelog->release->[1];
  say "released on ".$change->release_date;
  say "changes:";
  say "  * $_" for @{ $change->changes };

=cut

package SGN::Build::ChangeLog::Release;
use Moose;
use namespace::autoclean;

use DateTime::Format::Flexible;

has 'changes' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
   );

{
  use Moose::Util::TypeConstraints;
  my $rd = subtype 'release_date', as 'DateTime';

  coerce $rd =>
      from 'Str', via {
          DateTime::Format::Flexible->parse_datetime( $_ )
                or die "could not parse release date '$_'\n"
      };

  has 'release_date' => (
      is => 'ro',
      isa => $rd,
      required => 1,
      coerce => 1,
     );
}

=head1 ATTRIBUTES

=head2 changes

Arrayref of change descriptions (strings).

=head2 release_date

L<DateTime> object for the date of that release.

=cut

__PACKAGE__->meta->make_immutable;
1;

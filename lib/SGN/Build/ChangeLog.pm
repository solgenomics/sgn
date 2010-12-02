=head1 NAME

SGN::Build::ChangeLog - data model for machine-readable changelog

=head1 SYNOPSIS

  my $changes = SGN::Build::ChangeLog->new( releases => 'myfile.yml' );

  say "there are ".$changes->release_count." releases in the file\n";
  say "last release was on ".$changes->releases->[0]->release_date;

=cut

package SGN::Build::ChangeLog;
use Moose;
use Storable 'dclone';
use namespace::autoclean;

use YAML::Any 'LoadFile';
use Moose::Util::TypeConstraints;

use SGN::Build::ChangeLog::Release;

{ my $r = subtype 'Releases',
          as 'ArrayRef[SGN::Build::ChangeLog::Release]';

  coerce $r =>
      from 'Str|Object', via {
          __PACKAGE__->_parse_file( $_ )
      };

  has 'releases' => (
      is => 'ro',
      isa => $r,
      coerce => 1,
      traits => ['Array'],
      handles => {
          release_count  => 'count',
          releases_list  => 'elements',
      },
     );

}

sub _parse_file {
    my ( $class, $file ) = @_;
    use Data::Dump;
    return [
        map {
            my $e = $class->_munge_entry( $_ );
            SGN::Build::ChangeLog::Release->new( $e );
        } LoadFile( "$file" )
       ];
}
sub _munge_entry {
    my ( $class, $entry ) = @_;

    my $new_entry = {
        map {
            my ($k,$v) = ( $_, $entry->{$_} );
            $k = lc $k;
            $k =~ s/\s/_/g;
            ( $k => $v )
        } keys %$entry
     };


    if( $new_entry->{release_date} eq 'NEXT' ) {
        $new_entry->{release_date} = DateTime->now;
    }

    return $new_entry;
}

=head1 ATTRIBUTES

=head2 releases

Arrayref of L<SGN::Build::ChangeLog::Release> objects.  Can pass a
filename (or object that stringifies to a file name, like a
L<Path::Class::File>) to the constructor and it will parse the
releases from the file.

=cut

=head2 release_count

Counts the number of releases.

=head2 releases_list

List of releases.  Same as dereferencing C<releases>.

=head1 SEE ALSO

L<SGN::Build::ChangeLog::Release> contains the documentation on the
contained release objects.

=cut

__PACKAGE__->meta->make_immutable;
1;


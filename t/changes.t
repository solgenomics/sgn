use strict;
use warnings;

use Test::More;

use Path::Class;
use YAML::Any 'LoadFile';

use SGN::Build::ChangeLog;

my $changes = SGN::Build::ChangeLog->new( releases => 'Changes' );
can_ok( $changes, 'releases');
# test construction with Path::Class::File objs
can_ok( SGN::Build::ChangeLog->new( releases => file('Changes') ), 'releases');

cmp_ok( $changes->release_count, '>', 1 , 'Changes file YAML-parses to a bunch of changes' );

my $last_date;
for my $change ( $changes->releases_list ) {
    if( $last_date ) {
        cmp_ok( $last_date, '>', $change->release_date, 'dates are in reverse chronological order' );
    }
    $last_date = $change->release_date;
    isa_ok( $change->release_date, 'DateTime' );
    cmp_ok( scalar( @{$change->changes} ), '>=', 1, 'at least one change in release '.$change->release_date );
}

done_testing;


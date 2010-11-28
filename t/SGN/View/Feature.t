package Test::SGN::View::Feature;
use strict;
use warnings;
use base 'Test::Class';

use Test::Class;
use lib 't/lib';
use SGN::Test::Data qw/create_test/;
use Test::More tests => 7;

use_ok('SGN::View::Feature', qw/feature_table related_stats/ );

sub make_fixture : Test(setup) {
    my $self = shift;
    $self->{feature} = create_test('Sequence::Feature');
}

sub teardown : Test(teardown) {
    my $self = shift;
    # SGN::Test::Data objects self-destruct, don't clean them up here!
}

sub TEST_RELATED_STATS : Tests {
    my $self = shift;
    my $feature = create_test('Sequence::Feature');

    my $name1 = $self->{feature}->type->name;
    my $name2 = $feature->type->name;
    my $stats = related_stats([ $self->{feature}, $feature, $feature ]);
    like($stats->[0][1],qr/$name1/);
    is($stats->[0][0] , 1);
    is($stats->[1][0] , 2);
    like($stats->[1][1],qr/$name2/);
    like($stats->[2][1] , qr'Total');
    is($stats->[2][0] , 3);
}

Test::Class->runtests;

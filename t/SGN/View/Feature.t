package Test::SGN::View::Feature;
use strict;
use warnings;
use base 'Test::Class';

use Test::More tests => 2;
use Test::MockObject;
use Test::Class;

use_ok('SGN::View::Feature', qw/feature_table gbrowse_link related_stats/ );

sub make_fixture : Test(setup) {
    my $self = shift;
    $self->{feature} = Test::MockObject->new;
    my $type = Test::MockObject->new;
    $type->mock('name', sub { 'Fiddlestix' } );
    $self->{feature}->mock('name', sub { 'Jabberwocky' });
    $self->{feature}->mock('type', sub { $type } );
}

sub teardown : Test(teardown) {
    my $self = shift;
}

sub TEST_RELATED_STATS : Tests {
    my $self = shift;
    my $feature = Test::MockObject->new;
    my $type = Test::MockObject->new;
    $type->mock('name', sub { 'Wonkytown' } );
    $feature->mock('type', sub { $type } );

    my $stats = related_stats([ $self->{feature}, $feature ]);
    is_deeply($stats, [
        [ 'Fiddlestix', 1 ],
        [ 'Wonkytown', 1  ],
        [ 'Total', 2      ],
    ], 'related_stats');
}

# sub TEST_GBROWSE_LINK : Tests {
#     my $self = shift;
#     my $link = gbrowse_link($self->{feature}, 10, 20);
#     is($link, '<a href="/gbrowse/bin/gbrowse/ITAG1_genomic/?ref=Jabberwocky;start=10;end=20">10,20</a>', 'gbrowse_link is generated correctly');

# }

Test::Class->runtests;

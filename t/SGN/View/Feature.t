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
    $self->{feature}->mock('name', sub { 'Jabberwocky' });
}

sub teardown : Test(teardown) {
    my $self = shift;
}

sub TEST_GBROWSE_LINK : Tests {
    my $self = shift;
    my $link = gbrowse_link($self->{feature}, 10, 20);
    is($link, '<a href="/gbrowse/bin/gbrowse/ITAG1_genomic/?ref=Jabberwocky;start=10;end=20">10,20</a>', 'gbrowse_link is generated correctly');

}

Test::Class->runtests;

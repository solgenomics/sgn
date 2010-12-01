package Test::SGN::View::Feature;
use strict;
use warnings;
use base 'Test::Class';

use Test::Class;
use lib 't/lib';
use SGN::Test::Data qw/create_test/;
use Test::More tests => 9;

use_ok('SGN::View::Feature', qw/
    feature_table related_stats cvterm_link
    feature_link
/ );

sub make_fixture : Test(setup) {
    my $self = shift;
    $self->{feature} = create_test('Sequence::Feature');
}

sub teardown : Test(teardown) {
    my $self = shift;
    # SGN::Test::Data objects self-destruct, don't clean them up here!
}

sub TEST_CVTERM_LINK : Tests {
    my $self = shift;
    my $f = $self->{feature};
    my ($id,$name) = ($f->type->cvterm_id,$f->type->name);
    $name =~ s/_/ /g;
    chomp(my $link = <<LINK);
<a href="/chado/cvterm.pl?cvterm_id=$id">$name</a>
LINK
    is(cvterm_link($f),$link, 'cvterm link');
}

sub TEST_RELATED_STATS : Tests {
    my $self = shift;
    my $feature = create_test('Sequence::Feature');

    my $name1 = cvterm_link( $self->{feature} );
    my $name2 = cvterm_link( $feature );
    my $stats = related_stats([ $self->{feature}, $feature, $feature ]);
    is($stats->[0][1], $name1);
    is($stats->[0][0] , 1);
    is($stats->[1][0] , 2);
    is($stats->[1][1], $name2);
    like($stats->[2][1] , qr'Total');
    is($stats->[2][0] , 3);
}

sub TEST_FEATURE_LINK : Tests {
    my $self = shift;
    my $f = $self->{feature};
    my ($id,$name) = ($f->feature_id,$f->name);
    chomp(my $link = <<LINK);
<a href="/feature/view/id/$id">$name</a>
LINK
    is(feature_link($f),$link, 'feature link');
}

Test::Class->runtests;

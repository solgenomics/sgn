use strict;
use warnings;

use Test::More;
use Test::MockObject;

use_ok( 'SGN::SiteFeatures::CrossReference' );

my $mock_feature = Test::MockObject->new;
$mock_feature->set_always( 'feature_name', 'fakefeature' );

my $cr1 = SGN::SiteFeatures::CrossReference->new({
    url  => '/foo/bar.txt',
    text => 'Noggin',
    feature => $mock_feature,
});

my $cr2 = SGN::SiteFeatures::CrossReference->new({
    url  => '/foo/bar.txt',
    text => 'Noggin',
    feature => $mock_feature,
});

my $cr3 = SGN::SiteFeatures::CrossReference->new({
    url  => '/foo/baz.txt',
    text => 'Noggin',
    feature => $mock_feature,
});

ok(   $cr2->cr_eq( $cr1 ), 'cr eq finds equal'     );
ok( ! $cr2->cr_eq( $cr3 ), 'cr eq finds not equal' );

is( $cr2->cr_cmp( $cr1 ),  0, 'cr cmp for eq' );
is( $cr2->cr_cmp( $cr3 ), -1, 'cr cmp 1' );
is( $cr3->cr_cmp( $cr1 ),  1, 'cr cmp 2' );

my @u = $cr1->uniq( $cr2, $cr3 );
is( scalar(@u), 2, 'uniq seems to work 0' );
is( $cr1,   $u[0], 'uniq seems to work 1' );
is( $cr3,   $u[1], 'uniq seems to work 2' );

my $js_hash = $cr3->TO_JSON;
is( $js_hash->{text}, 'Noggin' );
can_ok( $js_hash->{url}, 'scheme', 'path' );
is( $js_hash->{feature}, 'fakefeature' );



done_testing;

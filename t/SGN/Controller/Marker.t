use strict;
use warnings;

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get("/marker/SGN-M538/rflp_image/view");
ok( $mech->status == 404 || $mech->status == 200, 'rflp image status is either 404 or 200' );
$mech->with_test_level( local => sub {
    if( -e File::Spec->catdir( $mech->context->config->{image_path}, 'rflp' ) ) {
        is( $mech->status, 200, 'we have an rflp images dir, request should have succeeded' );
    } else {
        is( $mech->status, 404, 'without an rflp images dir, request should have been Not Found' );
    }
});

done_testing;

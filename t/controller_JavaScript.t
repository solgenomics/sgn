use strict;
use warnings;
use Test::More;
use Data::Dumper;

BEGIN { use_ok 'Catalyst::Test', 'SGN' }
BEGIN { use_ok 'SGN::Controller::JavaScript' }

my $controller = SGN->controller('JavaScript');

my ($res, $c) = ctx_request('/');

my $test_uri = $c->uri_for( $controller->action_for_js( 'sgn.js', 'jquery.js' ));
like( $test_uri, qr! js_pack/[a-z\d]+$ !x, 'got a kosher-looking pack URI' );

($res, $c) = ctx_request( $test_uri );
cmp_ok( length($res->content), '>', 8000, 'got a big-looking response' )
    or diag "response was actually:\n", explain $res;

done_testing();

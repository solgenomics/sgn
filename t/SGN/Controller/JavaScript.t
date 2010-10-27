use strict;
use warnings;
use Test::More;
use Test::Warn;
use Data::Dumper;

use lib 't/lib';

use SGN::Test::WWW::Mechanize;
use Catalyst::Test 'SGN';

BEGIN { $ENV{SGN_SKIP_CGI} = 1 } #< don't need to compile all the CGIs

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->with_test_level( process => sub {
   my $controller = SGN->controller('JavaScript');
   my ($res, $c) = ctx_request('/');

   # test serving a JS package
   my $test_uri = $c->uri_for( $controller->action_for_js_package([ 'sgn.js', 'jquery.js', 'Text.Markup' ]));
   like( $test_uri, qr! js/pack/[a-z\d]+$ !x, 'got a kosher-looking pack URI' );

   ($res, $c) = ctx_request( $test_uri );
   cmp_ok( length($res->content), '>', 8000, 'got a big-looking response' )
       or diag "response was actually:\n", explain $res;

   like( $res->content, qr/jQuery/, 'there is some jquery in it' );
   like( $res->content, qr/Text\.Markup/, 'there is some Text.Markup in it' );
});


{ # test serving a single JS file

    like( get( '/js/Text/Markup.js' ), qr/function\s*\(/,
          'served a single JS file',
         );

    my $res;
    if( $mech->can_test_level('process') ) {
        warning_like {
            $res = request( '/js/Nonexistent.js' );
        } qr/Can't open .+Nonexistent.js/, 'got a warning about the missing file';
    } else {
        $res = request( '/js/Nonexistent.js' );
    }

    like( $res->content, qr/not found/i,
          'nonexistent js says not found',
       );
    #die "$res";
    is( $res->code, 404, 'gives a 404' );

}

done_testing();

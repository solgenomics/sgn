use strict;
use warnings;
use Test::More;
use Test::Warn;
use Data::Dumper;

use lib 't/lib';

BEGIN { $ENV{SGN_SKIP_CGI} = 1 } #< don't need to compile all the CGIs
use SGN::Test::WWW::Mechanize;
use SGN::Test qw/ request /;

my $mech = SGN::Test::WWW::Mechanize->new;


$mech->get_ok( '/bare_mason/site/header/body' );
$mech->content_like( qr/toolbar/i, 'seems to have a toolbar' );
$mech->content_unlike( qr/Cite SGN using/i, 'no footer seen' );
$mech->content_unlike( qr/<html>/i, 'no html opening' );
$mech->content_unlike( qr|</html>|i, 'no html closing' );

$mech->get_ok( '/bare_mason/site/header/head' );
$mech->content_like( qr/<title>/, 'got a title' );
$mech->content_unlike( qr/INSERT_JS_PACK/, 'js insertion seems to have happened' );
$mech->content_unlike( qr/<html>/i, 'no html opening' );

$mech->get_ok( '/bare_mason/site/header/head.mas', 'request with a .mas extension works' );
$mech->content_like( qr/<title>/, 'got a title' );
$mech->content_unlike( qr/INSERT_JS_PACK/, 'js insertion seems to have happened' );
$mech->content_unlike( qr/<html>/i, 'no html opening' );



{ # test download_static
  my $res = request( '/download/documents/inc/sgn.css' );
  is( $res->header('Content-disposition'), 'attachment, filename=sgn.css',
      'got the right disposition header from the static downloader' );

  like( $res->content, qr/text-align\s*:/, 'content looks like css' );
  is( $res->content_type, 'text/css', 'got a CSS content type' );
}

done_testing;


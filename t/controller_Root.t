use strict;
use warnings;
use Test::More;

use File::Find;


BEGIN {
    $ENV{SGN_SKIP_CGI} = 1; #< don't need to compile all the CGIs

    use_ok 'Catalyst::Test', 'SGN';
    use_ok 'SGN::Controller::Root';
}

{ # test download_static
  my $res = request( '/download/documents/inc/sgn.css' );
  is( $res->header('Content-disposition'), 'attachment, filename=sgn.css',
      'got the right disposition header from the static downloader' );

  like( $res->content, qr/text-align\s*:/, 'content looks like css' );
  is( $res->content_type, 'text/css', 'got a CSS content type' );
}


done_testing;

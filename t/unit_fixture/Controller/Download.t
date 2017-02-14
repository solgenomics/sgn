use strict;
use warnings;
use Test::More;
use Test::Warn;
use Data::Dumper;

use lib 't/lib';

use SGN::Test::WWW::Mechanize skip_cgi => 1;
my $mech = SGN::Test::WWW::Mechanize->new;

{ # test download_static
  my $res = $mech->get( '/download/css/sgn.css' );
  is( $res->header('Content-disposition'), 'attachment; filename=sgn.css',
      'got the right disposition header from the static downloader' );

  like( $res->content, qr/text-align\s*:/, 'content looks like css' );
  is( $res->content_type, 'text/css', 'got a CSS content type' );
}

done_testing;

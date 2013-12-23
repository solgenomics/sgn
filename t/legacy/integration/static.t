use strict;
use warnings;
use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok($_) for
    qw(
          /static/ext-4.0/ext.js
          /img/sgn_logo_icon.png
          /js/sgn.js
      );

done_testing;

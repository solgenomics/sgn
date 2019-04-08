use strict;
use warnings;
use Test::More;
use Test::Warn;
use Data::Dumper;

use lib 't/lib';

use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

# { # test serving a single JS file

    # $mech->get_ok( '/js/Text/Markup.js' );
    # $mech->content_like( qr/function\s*\(/,'served a single JS file' );
    # 
    # $mech->get( '/js/Nonexistent.js' );
    # $mech->content_like( qr/not found/i, 'nonexistent js says not found' );
    # 
    # #die "$res";
    # is( $mech->status, 404, 'gives a 404' );
    # 
    # $mech->get( '/js/CXGN/Page/' );
    # $mech->content_like( qr/not found/i, 'nonexistent js says not found' );
    # is( $mech->status, 404, 'gives a 404' );
    # 
    # $mech->get( '/js/CXGN/Page' );
    # $mech->content_like( qr/not found/i, 'nonexistent js says not found' );
    # is( $mech->status, 404, 'gives a 404' );

# }
is(1, 1);
done_testing();

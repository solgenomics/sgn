use strict;
use warnings;

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->with_test_level( local => sub {
    my $c = $mech->context;

    my $gb2 = $c->feature('gbrowse2')
        or plan skip_all => 'gbrowse2 feature not available';

    eval { $gb2->setup }; #< may fail if web server has done it already

    my @sources = $gb2->data_sources;

    can_ok( $_, 'view_url', 'name', 'description') for @sources;


    for ( @sources ) {
        like( $_->_url( 'gbrowse_img', { foo => 'bar' }), qr!/[^/]+$!, '_url path ends with a trailing slash' );
        my @dbs      = do {
            local $SIG{__WARN__} = sub {};
            $_->databases;
        };
        for (@dbs) {
            can_ok( $_, 'features' );
        }
    }
});

done_testing;

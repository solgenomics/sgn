use strict;
use warnings;

BEGIN { $ENV{SGN_SKIP_CGI} = 1 }

use Carp;
use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;
$SIG{__DIE__} = \&Carp::confess;


$mech->with_test_level( process => sub {
    my $c = $mech->context;

    can_ok( $c, 'feature' );

    my $fp = $c->feature('featurepages')
        or plan skip_all => 'featurepages feature not available';

    can_ok( $fp, 'feature_name' );

    my @xrefs = $fp->xrefs('Solyc05g005070'), $fp->xrefs('Serine/threonine protein kinase');

    my @methods = qw/ is_empty text url feature /;

    can_ok( $_, @methods ) for @xrefs;

});



done_testing;

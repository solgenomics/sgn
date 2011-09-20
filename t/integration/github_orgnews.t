use strict;
use warnings;

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok( '/github/org_news/solgenomics' );

$mech->content_contains('github.com');
$mech->content_contains('reltime');

done_testing;


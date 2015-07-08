
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();


$d->get_ok('/search/stocks');
ok($d->driver()->get_page_source() =~ /Search Accessions/, "Search page title presence");
ok($d->driver()->get_page_source() =~ /Project location/, "Search options present");
ok($d->driver()->get_page_source() =~ /KASESE/, "KASESE stock present in search results");

done_testing();


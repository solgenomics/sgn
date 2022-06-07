
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok('/search/locus');
ok($d->driver()->get_page_source() =~ /Search Genes and Loci/, "Search page title presence");
ok($d->driver()->get_page_source() =~ /Advanced Search Options/, "Advanced search options button present");
sleep(2);
ok($d->driver()->get_page_source() =~ /test2/, "Test2 locus present in search results");

done_testing();

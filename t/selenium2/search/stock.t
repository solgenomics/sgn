
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();


$d->get_ok('/search/stocks');
ok($d->driver()->get_page_source() =~ /Search Accessions/, "Search page title presence");
ok($d->driver()->get_page_source() =~ /Project location/, "Search options present");

$d->find_element_ok("any_name", "id", "find any_name html input element")->send_keys("test_accession1");

$d->find_element_ok("stock_type_select", "id", "find stock type input element")->send_keys("accession");

$d->find_element_ok("submit_stock_search", "id", "submit search")->click();

sleep(5);

$d->find_element_ok("test_accession1", "partial_link_text", "verify search")->click();

done_testing();


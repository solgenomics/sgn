
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok('/search/phenotypes/stock');

my $stock_name_input = $d->find_element_ok('stock_name', 'id', 'find stock name input');

$stock_name_input->send_keys('test_accession1');

$stock_name_input->submit();

my $link = $d->find_element_ok('test_accession1', 'link_text', 'result overview page');

$link->click();

my $detail_page = $d->driver->get_page_source();
ok($detail_page =~ m/Accession\: test_accession1/, "detail page 1");
ok($detail_page =~ m/test_accession1_synonym/, "detail page 2");

done_testing();

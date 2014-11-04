
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok('/search/phenotypes/stock');

my $stock_name_input = $d->find_element_ok('stock_name', 'id', 'find stock name input');

$stock_name_input->send_keys('test_accession1');

$stock_name_input->submit();


done_testing();

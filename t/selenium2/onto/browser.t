
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver -> new();

$t->get_ok('/tools/onto');

sleep(2);

my $mc = $t->find_element_ok("open_cvterm_67202", "id", "get ontology browser link for opening cellular_component");

$mc->click(); # open the link

sleep(2); 

#print STDERR $t->driver->get_page_source();

my $cell = $t->find_element_ok("cvterm_id_67546", "id", "get ontology browser link for cvterm detail page for a cell");

sleep(2);

$cell->click();

sleep(2);

ok($t->driver()->get_page_source() =~ m/The basic structural and functional unit of all organisms/, "find data on cell on detail page");

done_testing();

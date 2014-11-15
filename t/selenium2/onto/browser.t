
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver -> new();

$t->get_ok('/tools/onto');

my $mc = $t->get_element_ok("open_cvterm_67202", "id", "get ontology browser link for opening cellular_component");

$mc->click(); # open the link

my $cell = $t->get_element_ok("cvterm_67546", "id", "get ontology browser link for cvterm detail page for a cell");

$cell->click();

ok($t->get_page_source() =~ s/The basic structural and functional unit of all organisms/, "find data on cell on detail page");

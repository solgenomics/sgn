
use strict;

use lib 't/lib';

use Test::More 'tests' => 8;
use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver -> new();

$t->while_logged_in_as("submitter", sub {
    sleep(2);

    $t->get_ok('/tools/onto');
    sleep(3);

    $t->find_element_ok("ontology_browser_input", "id", "check if 'Find ID' input exist");

    $t->find_element_ok("ontology_browser_submit", "id", "check if 'Find' button exist");

    $t->find_element_ok("reset_hiliting", "id", "check if 'Clear Highlight' button exist");

    $t->find_element_ok("reset_tree", "id", "check if 'Reset View' button exist");

    $t->find_element_ok("ontology_term_input", "id", "check if 'Search for text' input exist");

    $t->find_element_ok("cv_select", "name", "check if 'Ontology' select exist");

    $t->find_element_ok("term_search", "id", "check if 'Search' button exist");
});

$t->driver->close();
done_testing();

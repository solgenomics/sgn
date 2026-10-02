use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Remote::WDKeys 'KEYS';
use Selenium::Remote::WebElement;
use Data::Dumper;

use strict;

my $f = SGN::Test::Fixture->new();

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("curator", sub {
    sleep(2);

    $t->get_ok('/traits/design');

    sleep(3);

    $t->find_element_ok('new_trait_name', 'id', 'fill trait name field')->send_keys("test trait");

    sleep(0.5);
    
    $t->find_element_ok('new_trait_definition', 'id', 'fill trait definition field')->send_keys("A fake test trait to see if the trait designer can make new traits during selenium tests.");

    sleep(0.5);

    my $ontology_select = $t->find_element_ok('new_trait_ontology_select', 'id', 'open trait ontology select')->click();

    $t->driver->find_element('//select[@id="new_trait_ontology_select"]/option[@value="CO_334"]', 'xpath')->click();

    sleep(0.5);

    my $format_select = $t->find_element_ok('new_trait_format_select', 'id', 'select categorical trait format')->click();

    $t->driver->find_element('//select[@id="new_trait_format_select"]/option[@value="categorical"]', 'xpath')->click();

    sleep(1);

    $t->find_element_ok('new_trait_add_category', 'id', 'name first category')->send_keys("control");

    $t->find_element_ok('new_trait_category_ordinal', 'id', 'assign first category as 0')->send_keys("0");

    $t->find_element_ok('new_trait_add_category_btn', 'id', 'create first category')->click();

    sleep(1);

    $t->find_element_ok('new_trait_add_category', 'id', 'name second category')->send_keys("high");

    $t->find_element_ok('new_trait_category_ordinal', 'id', 'assign second category as 1')->send_keys("1");

    $t->find_element_ok('new_trait_add_category_btn', 'id', 'create second category')->click();

    sleep(1);

    $t->find_element_ok('new_trait_add_category', 'id', 'name bad category')->send_keys("testtesttest");

    $t->find_element_ok('new_trait_category_ordinal', 'id', 'assign bad category as 33')->send_keys("33");

    $t->find_element_ok('new_trait_add_category_btn', 'id', 'create bad category')->click();

    sleep(1);

    $t->find_element_ok('new_trait_remove_category_btn', 'id', 'delete bad category')->click();

    sleep(1);

    $t->find_element_ok('new_trait_submit_btn', 'id', 'submit new trait')->click();

    sleep(2);

    $t->driver->accept_alert();

    sleep(1);
});

$t->driver->close();
$f->clean_up_db();
done_testing();
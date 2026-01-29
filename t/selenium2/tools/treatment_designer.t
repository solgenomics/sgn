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

    $t->get_ok('/treatments/design');

    sleep(3);

    $t->find_element_ok('new_treatment_name', 'id', 'fill treatment name field')->send_keys("test treatment");

    sleep(0.5);
    
    $t->find_element_ok('new_treatment_definition', 'id', 'fill treatment definition field')->send_keys("A fake test treatment to see if the treatment designer can make new treatments during selenium tests.");

    sleep(0.5);

    my $format_select = $t->find_element_ok('new_treatment_format_select', 'id', 'select categorical trait format')->click();

    $t->driver->find_element('//select[@id="new_treatment_format_select"]/option[@value="categorical"]', 'xpath')->click();

    sleep(1);

    $t->find_element_ok('new_treatment_add_category', 'id', 'name first category')->send_keys("control");

    $t->find_element_ok('new_treatment_category_ordinal', 'id', 'assign first category as 0')->send_keys("0");

    $t->find_element_ok('new_treatment_add_category_btn', 'id', 'create first category')->click();

    sleep(1);

    $t->find_element_ok('new_treatment_add_category', 'id', 'name second category')->send_keys("high");

    $t->find_element_ok('new_treatment_category_ordinal', 'id', 'assign second category as 1')->send_keys("1");

    $t->find_element_ok('new_treatment_add_category_btn', 'id', 'create second category')->click();

    sleep(1);

    $t->find_element_ok('new_treatment_add_category', 'id', 'name bad category')->send_keys("testtesttest");

    $t->find_element_ok('new_treatment_category_ordinal', 'id', 'assign bad category as 33')->send_keys("33");

    $t->find_element_ok('new_treatment_add_category_btn', 'id', 'create bad category')->click();

    sleep(1);

    $t->find_element_ok('new_treatment_remove_category_btn', 'id', 'delete bad category')->click();

    sleep(1);

    $t->find_element_ok('new_treatment_submit_btn', 'id', 'submit new treatment')->click();

    sleep(2);

    $t->driver->accept_alert();

    sleep(1);
});

done_testing();
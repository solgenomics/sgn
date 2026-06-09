
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';
use SGN::Test::Fixture;
use Selenium::Waiter qw(wait_until);

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("curator", sub {
    # Note: Use the fuzzy search to match similar names to prevent uploading of duplicate accessions. Fuzzy searching is much slower than regular search. Only a curator can disable the fuzzy search.
    $t->get_ok('/breeders/accessions');

    sleep(1); # FIXME Need to wait for button click handler to be registered
    $t->click_ok("lists_link", "name", "find lists_link");
    $t->find_element_ok("add_list_input", "id", "find add list input");

    my $random_val = int(rand(1000));
    my $list_name = sprintf("new_test_list_accessions_%d", $random_val);

    $t->send_keys_ok("add_list_input", "id", $list_name, "find add list input test");

    $t->click_ok("add_list_button", "id", "find add list button test");

    $t->click_ok("view_list_$list_name", "id", "view list test");

    $t->click_ok("type_select", "id", "add type of list");
    $t->click_ok('option[name="accessions"]', "css", "select type 'accessions' from a list");

    $t->send_keys_ok("dialog_add_list_item", "id", "element1\nelement2\nelement3\n", "add test list items");

    $t->click_ok("dialog_add_list_item_button", "id", "find add_list_item_button and click");

    $t->click_ok("close_list_item_dialog", "id", "find close_list_item_dialog button and click");

    $t->click_ok("close_list_dialog_button", "id", "find close dialog button and click");

    # first try with fuzzy search on test_stocks // before tests were run on test_list' but is not available for
    # jane doe user as curator - only for submitter john doe

    $t->get_ok('/breeders/accessions');

    sleep(1); # FIXME Need to wait for button click handler to be registered
    $t->click_ok("add_accessions_link", "name", "find element add accessions link as curator");
    $t->click_ok("list_div_list_select", "id", "find and open list select input");
    $t->click_ok('//option[text()="test_stocks"]', "xpath", "select new_list name 'test_stock'");

    my $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy and uncheck it");
    unless($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };

    $t->click_ok("new_accessions_submit", "id", "submit new accessions");
    $t->click_ok("review_found_matches_hide", "id", "review found matches test");
    $t->accept_alert();

    # then we add new_test_list_accessions not using fuzzy search should be added as first without problems
    # with a name of organism Manihot esculenta
    $t->get_ok('/breeders/accessions');

    sleep(1); # FIXME Need to wait for button click handler to be registered
    $t->click_ok("add_accessions_link", "name", "find element add accessions link as curator");
    $t->click_ok("list_div_list_select", "id", "select new list test");
    $t->click_ok("//option[text()=\"$list_name\"]", "xpath", "select new_list");

    # fuzzy checkbox if checked then click (uncheck)
    $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy and uncheck it");
    if ($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };

    $t->click_ok("new_accessions_submit", "id", "submit new accessions");

    $t->click_ok("review_found_matches_hide", "id", "review found matches test");

    $t->send_keys_ok("species_name_input", "id", [KEYS->{'control'}, 'a'], "input species name clear");
    $t->send_keys_ok("species_name_input", "id", KEYS->{'backspace'}, "input species name backspace");
    $t->send_keys_ok("species_name_input", "id", "Manihot esculenta", "input species name");

    $t->click_ok("review_absent_accessions_submit", "id", "review matches and submit");

    $t->find_element_ok("close_add_accessions_saved_message_modal", "id", "close add accessions saved message modal");

    # then we add new_test_list_accession again, not using fuzzy search to see if it sees them in the db.
    # there should be in DB ain we shouldn't have a option to add them
    $t->get_ok('/breeders/accessions');

    sleep(1); # FIXME Need to wait for button click handler to be registered
    $t->click_ok("add_accessions_link", "name", "find element add accessions link as curator");
    $t->click_ok("list_div_list_select", "id", "select new list test");
    $t->click_ok("//option[text()=\"$list_name\"]", "xpath", "select new_list");

    # fuzzy checkbox if checked then click
    $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy and uncheck it");
    if ($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };

    $t->click_ok("new_accessions_submit", "id", "submit new accessions");

    $t->click_ok(
        "review_found_matches_hide",
        "id",
        "review found matches in db, close modal");

    $t->accept_alert();

    # then we add new_test_list_accessions again, using fuzzy search to see if it sees them in the db.
    # with fuzzy logic results should be a same - cannot be added to DB
    $t->get_ok('/breeders/accessions');

    sleep(1); # FIXME Need to wait for button click handler to be registered
    $t->click_ok("add_accessions_link", "name", "find element add accessions link as curator");
    $t->click_ok("list_div_list_select", "id", "select new list test");
    $t->click_ok("//option[text()=\"$list_name\"]", "xpath", "select new_list");

    $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy checkbox");
    unless ($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };

    $t->click_ok("new_accessions_submit", "id", "submit new accessions");
    $t->click_ok("review_found_matches_hide", "id", "review found matches, close modal");

    $t->accept_alert();
    }
);

$t->while_logged_in_as("submitter", sub {
    # log as submitter and check if fuzzy logic is always checked and disable to change
    $t->get_ok('/breeders/accessions');

    sleep(1); # FIXME Need to wait for button click handler to be registered
    $t->click_ok("add_accessions_link", "name", "find element add accessions link as submitter");

    my $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "find fuzzy checkbox");
#    is $fuzzy_checkbox->get_attribute('checked'), 1, 'fuzzy logic checkbox is checked for submitter';
#    is $fuzzy_checkbox->get_attribute('disabled'), 1, 'fuzzy logic checkbox is disabled for submitter';
});

$t->driver->close();
$f->clean_up_db();
done_testing();

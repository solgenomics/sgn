
use strict;

use lib 't/lib';

use Test::More 'tests' => 46;

use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';
use SGN::Test::Fixture;

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("curator", sub {
    sleep(2);

    # Note: Use the fuzzy search to match similar names to prevent uploading of duplicate accessions. Fuzzy searching is much slower than regular search. Only a curator can disable the fuzzy search.
    $t->get_ok('/breeders/accessions');
    sleep(2);

    $t->find_element_ok("lists_link", "name", "find lists_link")->click();
    $t->find_element_ok("add_list_input", "id", "find add list input");

    my $random_val = int(rand(1000));
    my $list_name = sprintf("new_test_list_accessions_%d", $random_val);

    $t->find_element_ok("add_list_input", "id", "find add list input test")->send_keys($list_name);

    $t->find_element_ok("add_list_button", "id", "find add list button test")->click();

    $t->find_element_ok("view_list_$list_name", "id", "view list test")->click();
    sleep(2);

    $t->find_element_ok("type_select", "id", "add type of list")->click();
    $t->find_element_ok('option[name="accessions"]', "css", "select type 'accessions' from a list")->click();
    sleep(1);

    $t->find_element_ok("dialog_add_list_item", "id", "add test list items")->send_keys("element1\nelement2\nelement3\n");
    sleep(1);

    $t->find_element_ok("dialog_add_list_item_button", "id", "find add_list_item_button and click")->click();

    $t->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button and click")->click();

    $t->find_element_ok("close_list_dialog_button", "id", "find close dialog button and click")->click();

    # first try with fuzzy search on test_stocks // before tests were run on test_list' but is not available for
    # jane doe user as curator - only for submitter john doe

    $t->get_ok('/breeders/accessions');
    sleep(2);
    
    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as curator")->click();
    $t->find_element_ok("list_div_list_select", "id", "find and open list select input")->click();
    $t->find_element_ok('//option[text()="test_stocks"]', "xpath", "select new_list name 'test_stock'")->click();
    sleep(2);

    my $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy and uncheck it");
    unless($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
    $submit_accessions->click();
    sleep(7);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
    $review_found_matches->click();
    sleep(1);

    $t->driver->accept_alert();

    # then we add new_test_list_accessions not using fuzzy search should be added as first without problems
    # with a name of organism Manihot esculenta
    $t->get_ok('/breeders/accessions');

    sleep(1);
    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as curator")->click();

    $t->find_element_ok("list_div_list_select", "id", "select new list test")->click();
    $t->find_element_ok("//option[text()=\"$list_name\"]", "xpath", "select new_list")->click();
    sleep(2);

    # fuzzy checkbox if checked then click (uncheck)
    $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy and uncheck it");
    if ($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
    $submit_accessions->click();
    sleep(5);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
    $review_found_matches->click();

    my $species_name_input = $t->find_element_ok("species_name_input", "id", "input species name");
    $species_name_input->send_keys(KEYS->{'control'}, 'a');
    $species_name_input->send_keys(KEYS->{'backspace'});
    $species_name_input->send_keys("Manihot esculenta");

    my $review_matches = $t->find_element_ok("review_absent_accessions_submit", "id", "review matches and submit");
    $review_matches->click();
    sleep(10);

    $t->find_element_ok("close_add_accessions_saved_message_modal", "id", "close add accessions saved message modal");

    # then we add new_test_list_accession again, not using fuzzy search to see if it sees them in the db.
    # there should be in DB ain we shouldn't have a option to add them
    $t->get_ok('/breeders/accessions');
    sleep(1);

    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as curator")->click();
    $t->find_element_ok("list_div_list_select", "id", "select new list test")->click();
    $t->find_element_ok("//option[text()=\"$list_name\"]", "xpath", "select new_list")->click();
    sleep(2);

    # fuzzy checkbox if checked then click
    $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy and uncheck it");
    if ($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };
    sleep(1);

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
    $submit_accessions->click();
    sleep(5);

    my $review_matches = $t->find_element_ok(
        "review_found_matches_hide",
        "id",
        "review found matches in db, close modal");
    $review_matches->click();
    sleep(1);

    $t->driver->accept_alert();

    # then we add new_test_list_accessions again, using fuzzy search to see if it sees them in the db.
    # with fuzzy logic results should be a same - cannot be added to DB
    $t->get_ok('/breeders/accessions');
    sleep(1);

    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as curator")->click();
    $t->find_element_ok("list_div_list_select", "id", "select new list test")->click();
    $t->find_element_ok("//option[text()=\"$list_name\"]", "xpath", "select new_list")->click();
    sleep(2);

    $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "check fuzzy checkbox");
    unless ($fuzzy_checkbox->get_attribute('checked')) {
        $fuzzy_checkbox->click();
    };

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
    $submit_accessions->click();
    sleep(7);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches, close modal");
    $review_found_matches->click();

    $t->driver->accept_alert();
    }
);

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    # log as submitter and check if fuzzy logic is always checked and disable to change
    $t->get_ok('/breeders/accessions');
    sleep(2);

    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as submitter")->click();

    my $fuzzy_checkbox = $t->find_element_ok("fuzzy_check", "id", "find fuzzy checkbox");
#    is $fuzzy_checkbox->get_attribute('checked'), 1, 'fuzzy logic checkbox is checked for submitter';
#    is $fuzzy_checkbox->get_attribute('disabled'), 1, 'fuzzy logic checkbox is disabled for submitter';
});

$t->driver->close();
$f->clean_up_db();
done_testing();

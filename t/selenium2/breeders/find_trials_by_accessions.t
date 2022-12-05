use lib 't/lib';

use Test::More 'tests' => 17;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/breeders/accessions');
    sleep(2);

    # Add a test list
    $t->find_element_ok("lists_link", "name", "find lists_link")->click();

    $t->find_element_ok("add_list_input", "id", "find add list input");

    $t->find_element_ok("add_list_input", "id", "find add list input test")->send_keys("find_trials_in_common");

    $t->find_element_ok("add_list_button", "id", "find add list button test")->click();

    $t->find_element_ok("view_list_find_trials_in_common", "id", "view list test")->click();

    sleep(2);

    $t->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("UG120001\nUG120002\nUG120003\n");

    sleep(1);

    $t->find_element_ok("type_select", "id", "set type accessions test")->click();
    $t->find_element_ok('option[name="accessions"]', "css", "select type 'accessions' from a list")->click();

    $t->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();
    sleep(1);

    $t->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test")->click();
    sleep(1);

    $t->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

    #use test list to test find trials in common tool
    $t->get_ok('/breeders/accessions');
    sleep(4);

    $t->find_element_ok("accession_list_list_select", "id", "select accession list test")->click();
    $t->find_element_ok(
        "//select[\@id='accession_list_list_select']/option[contains(text(),'find_trials_in_common')]",
        'xpath',
        "Select find_trials_in_common on list select")->click();
    sleep(2);

    $t->find_element_ok("find_trials", "id", "find trials test")->click();
    sleep(4);

    $t->find_element_ok("trial_summary_data", "id", "trial summary data test");
  }
);

$t->driver->close();
done_testing();

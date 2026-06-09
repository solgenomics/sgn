use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    $t->get_ok('/breeders/accessions');
    sleep(1); # FIXME Need to wait for button click handler to be registered

    # Add a test list
    $t->click_ok("lists_link", "name", "find and click lists_link");

    $t->find_element_ok("add_list_input", "id", "find add list input");

    $t->send_keys_ok("add_list_input", "id", "find_trials_in_common", "find add list input test and send keys");

    $t->click_ok("add_list_button", "id", "click add list button test");

    $t->click_ok("view_list_find_trials_in_common", "id", "click view list test");

    $t->send_keys_ok("dialog_add_list_item", "id", "UG120001\nUG120002\nUG120003\n", "add test list and send keys");

    $t->click_ok("type_select", "id", "click set type accessions test");
    $t->click_ok('option[name="accessions"]', "css", "select type 'accessions' from a list and click");
    $t->click_ok("dialog_add_list_item_button", "id", "click dialog_add_list_item_button test");
    $t->click_ok("close_list_item_dialog", "id", "click close_list_item_dialog button test");
    $t->click_ok("close_list_dialog_button", "id", "click close dialog button");

    #use test list to test find trials in common tool
    $t->get_ok('/breeders/accessions');
    sleep(1); # FIXME Need to wait for button click handler to be registered

    $t->click_ok("accession_list_list_select", "id", "select accession list test and click");
    $t->click_ok(
        "//select[\@id='accession_list_list_select']/option[contains(text(),'find_trials_in_common')]",
        'xpath',
        "Select find_trials_in_common on list select and click");

    $t->click_ok("find_trials", "id", "find trials test and click");

    $t->find_element_ok("trial_summary_data", "id", "trial summary data test");
  }
);

$t->driver()->close();
done_testing();

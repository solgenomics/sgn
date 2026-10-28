
use strict;

use lib 't/lib';

use Test::More 'tests' => 24;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->while_logged_in_as('submitter', sub {

    $d->get_ok('/tools');  # something else than the index page, which has a dialog that messes up the test
    sleep(2);

    # Create a new trail list for comparison test
    my $lists = $d->find_element_ok('navbar_lists', 'id', 'find navbar list button');
    $lists->click();
    sleep(2);
    my $add_list_input = $d->find_element_ok('add_list_input', 'id', 'find add list input');
    $add_list_input->send_keys('new_trial_list');

    my $add_list_button = $d->find_element_ok('add_list_button', 'id', 'find add list button');
    $add_list_button->click();

    $d->find_element_ok(
         '//div[@id="private_list_data_table_filter"]//input[@type="search"]',
         "xpath",
         "find search in table and find 'new_trial_list'")->send_keys('new_trial_list');
    sleep(3);

    $d->find_element_ok("view_list_new_trial_list", "id", "view new list test")->click();
    sleep(3);

    $d->find_element_ok("updateListDescField", "id", "add trial test list description")->send_keys("new_trial_list_description");
    sleep(1);

    $d->find_element_ok("updateListDescButton", "id", "find update List Desc Button")->click();
    sleep(1);
    $d->driver()->accept_alert();
    sleep(1);


    $d->find_element_ok("dialog_add_list_item", "id", "add trial test list")->send_keys("Kasese solgs trial\ntrial2 NaCRRI");

    sleep(1);

    $d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    sleep(3);

    $d->find_element_ok("type_select", "id", "find select of type list")->click();
    sleep(1);
    $d->find_element_ok(
        '//select[@id="type_select"]/option[@name="trials"]',
        "xpath",
        "select 'trials' as type list")->click();
    sleep(1);

    $d->find_element_ok("list_item_dialog_validate", "id", "find and click validate 'trails' type list")->click();
    sleep(5);

    $d->driver()->accept_alert();
    sleep(1);

    $d->find_element_ok("close_list_item_dialog", "id", "find close list item dialog")->click();

    sleep(1);

    $d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

    sleep(1);

    # Change page to trial comparison
    $d->get_ok('/tools/trial/comparison/list');

    sleep(10);

    $d->find_element("trials_list_select", "id", "find trials select")->click();
    sleep(1);

    $d->find_element_ok(
        '//select[@id="trials_list_select"]/option[contains(text(), "new_trial_list")]',
        "xpath",
        "select 'new_trial_list' as list")->click();
    sleep(6);

    $d->find_element_ok("unit_select", "id", "find select plot observation level")->click();
    sleep(1);

    $d->find_element_ok(
        '//select[@id="unit_select"]/option[@value="plot"]',
        "xpath",
        "select plot observation level")->click();
    sleep(20);

    $d->find_element_ok("trait_select", "id", "find trait select");
    sleep(1);
    $d->find_element_ok(
        '//select[@id="trait_select"]/option[contains(text(), "dry matter content percentage|CO_334:0000092")]',
        "xpath",
        "select 'new_trial_list' as list")->click();
    sleep(4);

    # Check trial names on axis of created plot
    my $plot_view = $d->find_element_ok(
        '//div[@id="tc-grid"]',
        'xpath',
        'find a content of plot')->get_attribute('innerHTML');
    sleep(1);

    ok($plot_view =~ /trial2 NaCRRI/, "Verify if test_accession1 on pedigree panel");
    ok($plot_view =~ /Kasese solgs trial/, "Verify if 'Kasese solgs trial' on pedigree panel");

});

$d->driver->close();
done_testing();

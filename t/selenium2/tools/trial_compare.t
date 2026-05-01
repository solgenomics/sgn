
use strict;

use lib 't/lib';

use Test::More 'tests' => 26;
use SGN::Test::WWW::WebDriver;

use Selenium::Waiter qw(wait_until);

my $d = SGN::Test::WWW::WebDriver->new();

$d->while_logged_in_as('submitter', sub {
    $d->get_ok('/tools');  # something else than the index page, which has a dialog that messes up the test

    # Create a new trail list for comparison test
    my $lists = $d->find_element_ok("navbar_lists", "id", "find navbar list button");
    $lists->click();

    my $add_list_input = $d->find_element_ok("add_list_input", "id", "find add list input");
    $add_list_input->send_keys("new_trial_list");

    my $add_list_button = $d->find_element_ok("add_list_button", "id", "find add list button");
    $add_list_button->click();

    $d->find_element_ok(
         '//div[@id="private_list_data_table_filter"]//input[@type="search"]',
         "xpath",
         "find search in table and find 'new_trial_list'")->send_keys("new_trial_list");

    $d->find_element_ok("view_list_new_trial_list", "id", "view new list test")->click();

    $d->find_element_ok("updateListDescField", "id", "add trial test list description")->send_keys("new_trial_list_description");

    $d->find_element_ok("updateListDescButton", "id", "find update List Desc Button")->click();
    wait_until { $d->driver()->accept_alert(); };
    $d->wait_for_alert_dismissed();

    my $textarea = $d->find_element_ok("dialog_add_list_item", "id", "add trial test list");
    my $trials_list = "Kasese solgs trial\ntrial2 NaCRRI";
    $textarea->send_keys($trials_list);
    wait_until { $textarea->get_attribute("value") eq $trials_list; };

    $d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();
    wait_until { 
        my @rows = $d->driver->find_elements('//table[@id="list_item_dialog_datatable"]/tbody/tr', "xpath");
        return scalar @rows == 2;
    };

    $d->find_element_ok("type_select", "id", "find select of type list")->click();
    $d->find_element_ok(
        '//select[@id="type_select"]/option[@name="trials"]',
        "xpath",
        "select 'trials' as type list")->click();

    $d->find_element_ok("list_item_dialog_validate", "id", "find and click validate 'trails' type list")->click();
    wait_until { $d->accept_alert_ok("accept validation alert"); };

    $d->wait_for_working_dialog();

    $d->find_element_ok("close_list_item_dialog", "id", "find close list item dialog")->click();

    $d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

    # Change page to trial comparison
    $d->get_ok("/tools/trial/comparison/list");

    $d->find_element_ok("trials_list_select", "id", "find trials select")->click();

    $d->find_element_ok(
        '//select[@id="trials_list_select"]/option[contains(text(), "new_trial_list")]',
        "xpath",
        "select 'new_trial_list' as list")->click();
    
    $d->wait_for_spinner("trials-loading-spinner", "id");

    $d->find_element_ok("unit_select", "id", "find select plot observation level")->click();

    $d->find_element_ok(
        '//select[@id="unit_select"]/option[@value="plot"]',
        "xpath",
        "select plot observation level")->click();
    
    $d->wait_for_spinner("trials-loading-spinner", "id");

    $d->find_element_ok("trait_select", "id", "find trait select");
    $d->find_element_ok(
        '//select[@id="trait_select"]/option[contains(text(), "dry matter content percentage|CO_334:0000092")]',
        "xpath",
        "select 'new_trial_list' as list")->click();
    
    # Check trial names on axis of created plot
    my $plot_view = $d->find_element_ok(
        '//div[@id="tc-grid"]',
        'xpath',
        'find a content of plot')->get_attribute('innerHTML');

    ok($plot_view =~ /trial2 NaCRRI/, "Verify if test_accession1 on pedigree panel");
    ok($plot_view =~ /Kasese solgs trial/, "Verify if 'Kasese solgs trial' on pedigree panel");

});

$d->driver->close();
done_testing();

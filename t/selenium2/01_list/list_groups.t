
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use Selenium::Firefox;
use Selenium::Firefox::Profile;

my $profile = Selenium::Firefox::Profile->new;
$profile->set_preference( 'browser.download.folderList', 2 ); # Use custom download folder
$profile->set_preference( 'browser.download.dir', '/tmp/download.txt' );
$profile->set_preference( 'browser.download.manager.showWhenStarting', 0 );
$profile->set_preference( 'browser.helperApps.neverAsk.saveToDisk', 'application/octet-stream,text/csv,application/zip,text/plain' );

my $driver = Selenium::Remote::Driver->new(firefox_profile => $profile, base_url => $ENV{SGN_TEST_SERVER}, remote_server_addr => $ENV{SGN_REMOTE_SERVER_ADDR} || 'localhost');

my $d = SGN::Test::WWW::WebDriver->new();
$driver->set_timeout('implicit', $d->implicit_wait);
$driver->set_timeout('page load', $d->implicit_wait);
$d->driver($driver);

$d->while_logged_in_as("submitter", sub {
    # sleep(1);

    $d->get_ok("/about/index.pl", "get root url test");
    sleep(2);

    $d->click_ok("lists_link", "name", "find lists_link");

    sleep(2);

    # Revert to original sorting: by list name, ascending
    $d->click_ok("(//div[\@id='private_list_data_table_wrapper']//thead/tr/th)[1]", "xpath", "Sort table by List Name");
    $d->click_ok("list_select_checkbox_808", "id", "checkbox select list");
    $d->click_ok("list_select_checkbox_810", "id", "checkbox select list");
    $d->click_ok("make_public_selected_list_group", "id", "make public selected list group");

    $d->accept_alert_ok();

    $d->click_ok("view_public_lists_button", "id", "view public lists");

    sleep(1);

    $d->find_element_ok("view_public_list_johndoe_1_private", "id", "check view public lists");

    $d->click_ok("close_public_list_item_dialog", "id", "close public lists");
    $d->click_ok("list_select_checkbox_808", "id", "checkbox select list");
    $d->click_ok("list_select_checkbox_810", "id", "checkbox select list");
    $d->click_ok("make_private_selected_list_group", "id", "make private selected list group");

    $d->accept_alert_ok();

    ## Combine two lists using union

    $d->click_ok("list_select_checkbox_808", "id", "checkbox select list 808");
    $d->click_ok("list_select_checkbox_810", "id", "checkbox select list 810");
    $d->send_keys_ok("new_combined_list_name", "id", "combined_list_union", "name selected list group - union");
    $d->click_ok("combine_selected_list_group_union", "id", "combine selected list group - union");

    $d->accept_alert_ok();

    sleep(1);
    ok($d->driver->get_alert_text() =~ m/Added 4 items to the new List combined_list_union/i, 'created selected list group - union');
    $d->accept_alert_ok();

    $d->find_element_ok("view_list_combined_list_union", "id", "check view combined list - union");

    ## Combine two lists using intersection

    $d->click_ok("list_select_checkbox_808", "id", "checkbox select list 808");
    $d->click_ok("list_select_checkbox_4", "id", "checkbox select list 4");
    $d->send_keys_ok("new_combined_list_name", "id", "combined_list_intersection", "name selected list group - intersection");
    $d->click_ok("combine_selected_list_group_intersection", "id", "combine selected list group - intersection");

    $d->accept_alert_ok();

    # Accept alert about mismatched list types (one list doesn't have it's type set)
    $d->accept_alert_ok();

    sleep(1);
    ok($d->driver->get_alert_text() =~ m/Added 2 items to the new List combined_list_intersection/i, 'created selected list group - intersection');
    $d->accept_alert_ok();

    $d->find_element_ok("view_list_combined_list_intersection", "id", "check view combined list - intersection");

    # Compare two lists
    $d->click_ok("list_select_checkbox_808", "id", "checkbox select list 808");
    $d->click_ok("list_select_checkbox_810", "id", "checkbox select list 810");
    $d->click_ok("compare_selected_list_group", "id", "compare selected list group");
    $d->click_ok("download_comparison_column", "id", "find download comparison column button");
    $d->click_ok("close_list_comparison_modal", "id", "find close comparison dialog button");

    ## Delete list group
    $d->click_ok("delete_selected_list_group", "id", "delete selected list group");

    $d->accept_alert_ok();
    $d->click_ok("close_list_dialog_button", "id", "find close dialog button");
});

$d->driver->close();
done_testing();


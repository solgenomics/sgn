
use strict;

use lib 't/lib';

use Test::More 'tests' => 22;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();


$d->while_logged_in_as("submitter", sub {

	$d->get_ok('/breeders/trial/137');
	sleep(3);

	$d->find_element_ok("lists_link", "name", "find lists_link")->click();

	$d->find_element_ok("add_list_input", "id", "find add list input");

	my $add_list_input = $d->find_element_ok("add_list_input", "id", "find add list input test");
	sleep(1);

	my $random_val = int(rand(1000));
	my $list_name = sprintf("selenium_test_list_datacollector_%d", $random_val);

	$add_list_input->send_keys($list_name);
	sleep(1);

	$d->find_element_ok("add_list_button", "id", "find add list button test")->click();
	sleep(1);

	$d->find_element_ok("view_list_$list_name", "id", "view list test")->click();
	sleep(2);

	$d->find_element_ok("updateListDescField", "id", "find list type")->send_keys($list_name);

	$d->find_element_ok("type_select", "id", "find list type")->click();
	$d->find_element_ok('option[name="traits"]', "css", "select type 'traits' from a list")->click();
	sleep(1);

	$d->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("dry matter content percentage|CO_334:0000092\nfresh root weight|CO_334:0000012\nfresh shoot weight measurement in kg|CO_334:0000016\nharvest index variable|CO_334:0000015\n");
	sleep(1);

	$d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

	my $button = $d->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test");

	$button->click();
	sleep(1);

	$d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

	$d->get_ok('/breeders/trial/137');
	sleep(5);

	my $trail_files_onswitch = $d->find_element_ok("trial_upload_files_onswitch",  "id",  "find and open 'trial upload files onswitch' and click");
	$trail_files_onswitch->click();
	sleep(2);

 	my $create_DataCollector_link = $d->find_element_ok('create_DataCollector_link', 'id', "find create data collector spreadsheet link");
	$create_DataCollector_link->click();
	sleep(1);

	$d->find_element_ok('trait_list_dc_list_select', 'id', "find and open list select input")->click();
	sleep(1);

	$d->find_element_ok("//select[\@id='trait_list_dc_list_select']//option[contains(text(),\"$list_name\")]", 'xpath', "Select a new $list_name from list select")->click();
	sleep(1);

	$d->find_element_ok('download_datacollector_data_level', 'id', "find and open list of 'data levels' select input")->click();
	sleep(1);

	$d->find_element_ok('//select[@id="download_datacollector_data_level"]//option[@value="plots"]', 'xpath', "Select plants as value for select data levels input")->click();
	sleep(1);

	$d->find_element_ok('create_DataCollector_submit_button', 'id', "find create excel file button and click")->click();
	sleep(3);

	$d->logout_ok();
});

$d->driver->close();
done_testing();





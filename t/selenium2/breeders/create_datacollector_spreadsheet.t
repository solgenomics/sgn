
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();


$d->while_logged_in_as("submitter", sub {
	
	$d->get_ok('/breeders/trial/137');

	sleep(1); # FIXME Waiting for click handler to be registered
	$d->click_ok("lists_link", "name", "find lists_link");

	$d->find_element_ok("add_list_input", "id", "find add list input");

	my $random_val = int(rand(1000));
	my $list_name = sprintf("selenium_test_list_datacollector_%d", $random_val);

	$d->send_keys_ok("add_list_input", "id", $list_name, "find add list input test");

	$d->click_ok("add_list_button", "id", "find add list button test");

	$d->click_ok("view_list_$list_name", "id", "view list test");

	$d->send_keys_ok("updateListDescField", "id", $list_name, "find list type");

	$d->click_ok("type_select", "id", "find list type");
	$d->click_ok('option[name="traits"]', "css", "select type 'traits' from a list");

	$d->send_keys_ok("dialog_add_list_item", "id", "dry matter content percentage|CO_334:0000092\nfresh root weight|CO_334:0000012\nfresh shoot weight measurement in kg|CO_334:0000016\nharvest index variable|CO_334:0000015\n", "add test list");

	$d->click_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test");

	$d->click_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test");

	$d->click_ok("close_list_dialog_button", "id", "find close dialog button");

	$d->get_ok('/breeders/trial/137');

	sleep(1); # FIXME Waiting for click handler to be registered
	$d->click_ok("trial_upload_files_onswitch",  "id",  "find and open 'trial upload files onswitch' and click");

 	$d->click_ok('create_DataCollector_link', 'id', "find create data collector spreadsheet link");

	$d->click_ok('trait_list_dc_list_select', 'id', "find and open list select input");

	$d->click_ok("//select[\@id='trait_list_dc_list_select']//option[contains(text(),\"$list_name\")]", 'xpath', "Select a new $list_name from list select");

	$d->click_ok('download_datacollector_data_level', 'id', "find and open list of 'data levels' select input");

	$d->click_ok('//select[@id="download_datacollector_data_level"]//option[@value="plots"]', 'xpath', "Select plants as value for select data levels input");

	$d->click_ok('create_DataCollector_submit_button', 'id', "find create excel file button and click");
	$d->wait_for_working_dialog();

	$d->logout_ok();
});

$d->driver->close();
$f->clean_up_db();
done_testing();



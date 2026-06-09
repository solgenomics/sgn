use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$d->while_logged_in_as("submitter", sub {

	$d->get_ok('/breeders/trial/137');

	sleep(1); # FIXME Need to wait for click handler to be registered
	$d->click_ok("lists_link", "name", "find lists_link");

	my $random_val = int(rand(1000));
	my $list_name = sprintf("selenium_test_pheno_spreadsheet_%d", $random_val);

	$d->send_keys_ok("add_list_input", "id", $list_name, "find add list input test");

	$d->click_ok("add_list_button", "id", "find add list button test");

	$d->click_ok("view_list_$list_name", "id", "view list test");

	$d->send_keys_ok("updateListDescField", "id", $list_name, "find list type");

	$d->click_ok("type_select", "id", "find list type");
	$d->click_ok('option[name="traits"]', "css", "select type 'traits' from a list");

	$d->send_keys_ok("dialog_add_list_item", "id", "dry matter content|CO_334:0000092\nfresh root weight|CO_334:0000012\nfresh shoot weight|CO_334:0000016\nharvest index|CO_334:0000015\n", "add test list");

	$d->click_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test");

	$d->click_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test");

	$d->click_ok("close_list_dialog_button", "id", "find close dialog button");

	$d->get_ok('/breeders/trial/137');

	sleep(1); # FIXME Waiting for click handler to be registered
	$d->click_ok(
		"trial_upload_files_onswitch",
		"id",
		"find and open 'trial upload files onswitch' and click");

	$d->click_ok(
		'button[name="create_spreadsheet_link"]',
		'css',
		"find create spreadsheet link");

	$d->click_ok(
		'trait_list_spreadsheet_list_select',
		'id',
		"find list select select box");

	$d->click_ok(
		"//select[\@id='trait_list_spreadsheet_list_select']//option[contains(text(),\"$list_name\")]",
		'xpath',
		"Select a new $list_name from list select");

	$d->click_ok('include_notes_column', 'id', "find include notes column checkbox and click");

	$d->click_ok(
		'create_spreadsheet_phenotype_file_format',
		'id',
		"find and open 'phenotype file format' select input");

	$d->click_ok(
		'//select[@id="create_spreadsheet_phenotype_file_format"]//option[@value="ExcelBasicSimple"]',
		'xpath',
		"Select 'value: ExcelBasicSimple (name: Simple)' as file format");

	$d->click_ok(
		'create_spreadsheet_data_level',
		'id',
		"find and open list of 'data levels' select input");

	$d->click_ok(
		'//select[@id="create_spreadsheet_data_level"]//option[@value="plots"]',
		'xpath',
		"Select plants as value for select data levels input");

	$d->click_ok('create_phenotyping_ok_button', 'id', "find create excel file button and click");

	$d->wait_for_working_dialog();

	$d->logout_ok();
});

$d->driver->close();
$f->clean_up_db();
done_testing();

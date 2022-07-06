use strict;

use lib 't/lib';

use Test::More 'tests' => 25;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$d->while_logged_in_as("submitter", sub {
	sleep(2);

	$d->get_ok('/breeders/trial/137');
	sleep(3);

	$d->find_element_ok("lists_link", "name", "find lists_link")->click();

	$d->find_element_ok("add_list_input", "id", "find add list input");

	my $add_list_input = $d->find_element_ok("add_list_input", "id", "find add list input test");

	my $random_val = int(rand(1000));
	my $list_name = sprintf("selenium_test_pheno_spreadsheet_%d", $random_val);

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

	$d->find_element_ok("dialog_add_list_item", "id", "add test list")
		->send_keys("dry matter content|CO_334:0000092\nfresh root weight|CO_334:0000012\nfresh shoot weight|CO_334:0000016\nharvest index|CO_334:0000015\n");
	sleep(1);

	$d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

	$d->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test")->click();
	sleep(1);

	$d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

	$d->get_ok('/breeders/trial/137');
	sleep(5);

	my $trail_files_onswitch = $d->find_element_ok(
		"trial_upload_files_onswitch",
		"id",
		"find and open 'trial upload files onswitch' and click");
	$trail_files_onswitch->click();
	sleep(2);

	$d->find_element_ok(
		'button[name="create_spreadsheet_link"]',
		'css',
		"find create spreadsheet link")->click();
	sleep(2);

	$d->find_element_ok(
		'trait_list_spreadsheet_list_select',
		'id',
		"find list select select box")->click();
	sleep(1);

	$d->find_element_ok(
		"//select[\@id='trait_list_spreadsheet_list_select']//option[contains(text(),\"$list_name\")]",
		'xpath',
		"Select a new $list_name from list select")->click();

	$d->find_element_ok('include_notes_column', 'id', "find include notes column checkbox and click")->click();

	$d->find_element_ok(
		'create_spreadsheet_phenotype_file_format',
		'id',
		"find and open 'phenotype file format' select input")->click();
	sleep(1);

	$d->find_element_ok(
		'//select[@id="create_spreadsheet_phenotype_file_format"]//option[@value="ExcelBasicSimple"]',
		'xpath',
		"Select 'value: ExcelBasicSimple (name: Simple)' as file format")->click();
	sleep(1);

	$d->find_element_ok(
		'create_spreadsheet_data_level',
		'id',
		"find and open list of 'data levels' select input")->click();
	sleep(1);

	$d->find_element_ok(
		'//select[@id="create_spreadsheet_data_level"]//option[@value="plots"]',
		'xpath',
		"Select plants as value for select data levels input")->click();
	sleep(1);

	$d->find_element_ok('create_phenotyping_ok_button', 'id', "find create excel file button and click")->click();

	sleep(3);
	$d->logout_ok();
});

$d->driver->close();
$f->clean_up_db();
done_testing();



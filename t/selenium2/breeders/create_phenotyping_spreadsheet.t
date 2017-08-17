use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->login_as("submitter");

$d->get_ok('/breeders/trial/137');

sleep(3);

my $out = $d->find_element_ok("lists_link", "name", "find lists_link")->click();

$d->find_element_ok("add_list_input", "id", "find add list input");

my $add_list_input = $d->find_element_ok("add_list_input", "id", "find add list input test");
   
$add_list_input->send_keys("new_test_list_pheno_spreadsheet");

sleep(1);

$d->find_element_ok("add_list_button", "id", "find add list button test")->click();

sleep(1);

$d->find_element_ok("view_list_new_test_list_pheno_spreadsheet", "id", "view list test")->click();

sleep(2);

my $type_select = $d->find_element_ok("type_select", "id", "find list type");

$type_select->send_keys("traits");

sleep(1);

$d->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("dry matter content|CO_334:0000092\nfresh root weight|CO_334:0000012\nfresh shoot weight|CO_334:0000016\nharvest index|CO_334:0000015\n");


sleep(1);

$d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

my $button = $d->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test");

$button->click();

sleep(1);


$d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();


	$d->get_ok('/breeders/trial/137');
	
	sleep(3);

	my $create_spreadsheet_link = $d->find_element_ok('create_spreadsheet_link', 'id', "find create spreadsheet link");

	$create_spreadsheet_link->click();

	sleep(5);

	$d->find_element_ok('trait_list_list_select', 'id', "find list select select box")->send_keys('new_test_list_pheno_spreadsheet');

	my $button = $d->find_element_ok('create_phenotyping_ok_button', 'id', "create");

	$button->click();

	sleep(5);

	
    
$d->logout_ok();

done_testing();

$d->driver->close();


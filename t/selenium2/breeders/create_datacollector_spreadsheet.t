
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->login_as("submitter");

$d->get_ok("/", "get root url test");

my $out = $d->find_element_ok("lists_link", "name", "find lists_link")->click();

$d->find_element_ok("add_list_input", "id", "find add list input");

my $add_list_input = $d->find_element_ok("add_list_input", "id", "find add list input test");
   
$add_list_input->send_keys("new_test_list");

$d->find_element_ok("add_list_button", "id", "find add list button test")->click();

$d->find_element_ok("view_list_new_test_list", "id", "view list test")->click();

sleep(2);

my $type_select = $d->find_element_ok("type_select", "id", "find list type");

$type_select->send_keys("traits");

sleep(1);

$d->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("dry matter content|CO:0000092\nfresh root weight|CO:0000012\nfresh shoot weight|CO:0000016\nharvest index|CO:0000015\n");


sleep(1);

$d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

my $button = $d->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test");

$button->click();

sleep(1);

print "Deleted the list\n";

$d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

$d->logout_ok();


my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as(
    "submitter", 


 sub { 
	$t->get_ok('/breeders/trial/137');
	
	sleep(2);

	my $create_DataCollector_link = $t->find_element_ok('create_DataCollector_link', 'id', "find create data collector spreadsheet link");

	$create_DataCollector_link->click();

	sleep(10);

#	my $trait_list_list_select = $t->find_element_ok("trait_list_list_select", "id", "find list select select box");

#	$trait_list_list_select->send_keys("new_test_list");

	$t->find_element_ok('trait_list_list_select', 'id', "find list select select box")->send_keys('new_test_list');

	my $button = $t->find_element_ok('create_DataCollector_submit_button', 'id', "create");

	$button->click();

	sleep(10);

	
    });
    
	

done_testing();

$d->driver->close();




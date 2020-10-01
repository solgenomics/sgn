
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as(
    "submitter", 


    sub { 
	$t->get_ok('/breeders/trials');
    my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
    sleep(3);
	my $add_project_link = $t->find_element_ok('add_project_link', 'id', "find add trial link");

	$add_project_link->click();

	sleep(1);

	$t->find_element_ok('new_trial_name', 'id', "find new trial name input box")->send_keys("Test trial 1");

	$t->find_element_ok('add_project_year', 'id', "find trial year input box")->send_keys("2015");

	$t->find_element_ok('add_project_location', 'id', "find project location input box")->send_keys("test_location");

	$t->find_element_ok('add_project_description', 'id', "find project description input box")->send_keys("test test test");

	$t->find_element_ok('select_design_method', 'id', "find field layout design method")->click('Completely Randomized');

	$t->find_element_ok('select_list_list_select', 'id', "find list select select box")->click('test_stocks');

	$t->find_element_ok('rep_count', 'id', "find replicate count input box")->send_keys("3");

	$t->find_element_ok('new_trial_submit', 'id', "find Add button")->click();
	sleep(15);

	$t->find_element_ok('new_trial_confirm_submit', 'id', "find trial design confirm button")->click();
	
	sleep(10);

	$t->find_element_ok('trial_saved_dialog_message_ok_button', 'id', "find trial saved dialog")->click();

	sleep(1);

    });


done_testing();

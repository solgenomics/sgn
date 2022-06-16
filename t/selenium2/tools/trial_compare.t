
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();


# check if the page forwards to login page without login
#
$d->get_ok('/tools/trial/comparison/list');

sleep(2);
$d->find_element_ok('username', 'id', "find username input field");

$d->while_logged_in_as('submitter', sub {
    $d->get_ok('/tools');  # something else than the index page, which has a dialog that messes up the test

    sleep(2);

    my $lists = $d->find_element_ok('navbar_lists', 'id', 'find navbar list button');
    $lists->click();
    sleep(2);
    my $add_list_input = $d->find_element_ok('add_list_input', 'id', 'find add list input');
    $add_list_input->send_keys('new_trial_list');

    my $add_list_button = $d->find_element_ok('add_list_button', 'id', 'find add list button');
    $add_list_button->click();

    $d->find_element_ok("view_list_new_trial_list", "id", "view new list test")->click();

sleep(1);

    $d->find_element_ok("dialog_add_list_item", "id", "add trial test list")->send_keys("Kasese solgs trial\ntrial2 NaCRRI");

sleep(1);

    $d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    sleep(3);

    $d->find_element_ok("trials", "name", "find type select")->click();
    sleep(3);

    $d->find_element_ok("close_list_item_dialog", "id", "find close list item dialog")->click();

    sleep(1);

    $d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

    sleep(1);

    $d->get_ok('/tools/trial/comparison/list');

    sleep(6);

    $d->find_element("trials_list_select", "id", "find trials select")->click();

    sleep(2);

    $d->find_element("trials_list_select", "id", "find trials select")->send_keys('new_trial_list');

    sleep(6);
    $d->find_element_ok("unit_select", "id", "select plot observation level")->click();

    sleep(12);

  #  $d->find_element_ok("unit_select", "id", "select plot observation level")->send_keys("Plot");

  #  sleep(2);

    my $trait_select = $d->find_element_ok("trait_select", "id", "find trait select");

    sleep(2);

    $trait_select->click();

    sleep(1);

    $trait_select->send_keys("dry matter content percentage|CO_334:0000092");

    sleep(1);

    #my $submit_trial_list = $d->find_element_ok("submit_trial_list", "id", "find submit trial list button");

    #sleep(12);

    my $source = $d->driver()->get_page_source();

    like($source, qr/427/, "total accession count");
    like($source, qr/254/, "common accession count");

		       });





$d->get_ok('/tools/trial/comparison/params?trial_name=Kasese+solgs+trial&trial_name=trial2+NaCRRI&cvterm_id=70666');
sleep(1);

$d->find_element_ok('result_image', 'id', "find result image");


done_testing();

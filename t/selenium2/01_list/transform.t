
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->while_logged_in_as('submitter', sub {
    sleep(1);
    $d->get_ok("/about/index.pl", "get root url test");

    sleep(2);

    my $out = $d->find_element_ok("lists_link", "name", "find lists_link")->click();

    sleep(1);

    print "Adding new list...\n";

    $d->find_element_ok("add_list_input", "id", "find add list input");
    sleep(1);
    my $add_list_input = $d->find_element_ok("add_list_input", "id", "find add list input test");

    sleep(1);

    $add_list_input->send_keys("new_test_list_transform");

    sleep(1);

    $d->find_element_ok("add_list_button", "id", "find add list button test")->click();
    sleep(1);
    $d->find_element_ok("view_list_new_test_list_transform", "id", "view list test")->click();

    sleep(1);

    $d->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("test_accession1\ntest_accession2\ntest_accession3_synonym1\n");

    sleep(1);

    $d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    print "Close list content dialog...\n";

    sleep(2);

    my $button = $d->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test");

    $button->click() if ($button);

    print "Delete test list...\n";

    my $delete_link = $d->find_element_ok("delete_list_new_test_list_transform", "id", "find delete test list button");

    $delete_link->click() if $delete_link;

    sleep(1);

    my $text = $d->driver->get_alert_text();

    $d->accept_alert_ok();

    sleep(1);

    $d->accept_alert_ok();

    print "Deleted the list\n";

    $d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

});

done_testing();

$d->driver->close();

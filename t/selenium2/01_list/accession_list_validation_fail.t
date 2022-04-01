use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;
use CXGN::List;
use SimulateC;

my $d = SGN::Test::WWW::WebDriver->new();

$d->while_logged_in_as(
    "submitter",
    sub {
        sleep(1);
        $d->get_ok( "/search", "get root url test" );
        sleep(1);
        my $out = $d->find_element_ok( "lists_link", "name", "find lists_link" )
          ->click();
        sleep(1);
        print "Adding new list...\n";

        $d->find_element_ok( "add_list_input", "id", "find add list input" );
        sleep(1);
        my $add_list_input = $d->find_element_ok( "add_list_input", "id",
            "find add list input test" );
        sleep(1);
        $add_list_input->send_keys("new_test_list_accession_validation_fail");
        sleep(1);
        $d->find_element_ok( "add_list_button", "id",
            "find add list button test" )->click();
        sleep(1);
        $d->find_element_ok(
            "view_list_new_test_list_accession_validation_fail",
            "id", "view list test" )->click();

        sleep(1);

        $d->find_element_ok( "dialog_add_list_item", "id", "add test list" )
          ->send_keys("element11\nelement22\nelement33\n");

        sleep(2);

        $d->find_element_ok( "dialog_add_list_item_button", "id",
            "find dialog_add_list_item_button test" )->click();
        sleep(2);
        $d->find_element_ok( "type_select", "id", "validate list select" )
          ->send_keys("accessions");
        sleep(2);
        $d->find_element_ok( "list_item_dialog_validate", "id",
            "submit list validate" )->click();
        sleep(1);

        # $d->find_element_ok(
        #     '//*[contains(text(), " List did not pass validation")]',
        #     'xpath', 'check validation report dialog' )->click();
        # sleep(1);
        $d->driver->dismiss_alert();

        sleep(1);

        $d->find_element_ok( "close_list_item_dialog", "id",
            "find close accession dialog button" )->click();
        sleep(2);
        $d->find_element_ok( "close_list_dialog_button", "id",
            "find close dialog button" )->click();
        sleep(1);
    }
);

done_testing();

$d->driver->close();

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/accessions');

    my $add_accessions_link = $t->find_element_ok("add_accessions_link", "id", "find element add accessions link as submitter");

    $add_accessions_link->click();
    

    # Add a test list
    my $out = $t->find_element_ok("lists_link", "name", "find lists_link")->click();

    $t->find_element_ok("add_list_input", "id", "find add list input");

    my $add_list_input = $t->find_element_ok("add_list_input", "id", "find add list input test");
   
    $add_list_input->send_keys("new_test_list");

    $t->find_element_ok("add_list_button", "id", "find add list button test")->click();

    $t->find_element_ok("view_list_new_test_list", "id", "view list test")->click();

    sleep(2);

    $t->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("element1\nelement2\nelement3\n");

    sleep(1);

    $t->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    $t->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test")->click();

    $t->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

    #first try without fuzzy search
    my $fuzzy = $t->find_element_ok("fuzzy_check", "id", "select fuzzy check test")->click();

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
   
    $submit_accessions->click();

    sleep(7);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
   
    $review_found_matches->click();

    sleep(1);

    my $review_fuzzy_matches = $t->find_element_ok("review_fuzzy_matches_hide", "id", "review fuzzy matches test");
   
    $review_fuzzy_matches->click();

    sleep(1);

    $t->driver->accept_alert();

    my $review_matches = $t->find_element_ok("review_absent_accessions_submit", "id", "review matches submit");
   
    $review_matches->click();

    sleep(1);

    }

);


$t->driver->close();

$t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/accessions');

    }

);

done_testing();

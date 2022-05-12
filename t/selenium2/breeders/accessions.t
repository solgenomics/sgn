use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/accessions');

    sleep(2);

    # Add a test list
    $t->find_element_ok("lists_link", "name", "find lists_link")->click();

    $t->find_element_ok("add_list_input", "id", "find add list input");

    my $add_list_input = $t->find_element_ok("add_list_input", "id", "find add list input test")->send_keys("new_test_list_accessions");

    $t->find_element_ok("add_list_button", "id", "find add list button test")->click();

    $t->find_element_ok("view_list_new_test_list_accessions", "id", "view list test")->click();

    sleep(2);

    $t->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("element1\nelement2\nelement3\n");

    sleep(1);

    $t->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    $t->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test")->click();

    $t->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();


    #first try with fuzzy search. test_list will cause fuzzy search to return hits
    $t->get_ok('/breeders/accessions');

    sleep(2);
    
    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as submitter")->click();

    $t->find_element_ok("list_div_list_select", "id", "select new list test")->send_keys("test_list");

    sleep(2);

    my $fuzzy = $t->find_element_ok("fuzzy_check", "id", "select fuzzy check test")->click();

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
   
    $submit_accessions->click();

    sleep(7);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
   
    $review_found_matches->click();

    sleep(1);
    $t->driver->accept_alert();

    
    #then we add new_test_list_accessions not using fuzzy search

    $t->get_ok('/breeders/accessions');

    sleep(1);

    my $add_accessions_link = $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as submitter")->click();

    #then try without fuzzy search.
    $t->find_element_ok("list_div_list_select", "id", "select new list test")->send_keys("new_test_list_accessions");

    sleep(2);

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
   
    $submit_accessions->click();

    sleep(5);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
   
    $review_found_matches->click();

    sleep(1);

    $t->driver->accept_alert();

    sleep(1);


    #then we add new_test_list_accession again, not using fuzzy search to see if it sees them in the db.

    $t->get_ok('/breeders/accessions');

    sleep(1);

    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as submitter")->click();

    #then try without fuzzy search.
    $t->find_element_ok("list_div_list_select", "id", "select new list test")->send_keys("new_test_list_accessions");

    sleep(2);

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
   
    $submit_accessions->click();

    sleep(5);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
   
    $review_found_matches->click();

    sleep(1);

    $t->driver->accept_alert();


    #then we add new_test_list_accessions again, using fuzzy search to see if it sees them in the db.

    $t->get_ok('/breeders/accessions');

    sleep(1);

    $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as submitter")->click();

    my $fuzzy = $t->find_element_ok("fuzzy_check", "id", "select fuzzy check test")->click();

    $t->find_element_ok("list_div_list_select", "id", "select new list test")->send_keys("new_test_list_accessions");

    sleep(2);

    my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
   
    $submit_accessions->click();

    sleep(7);

    my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
   
    $review_found_matches->click();
    
    $t->driver->accept_alert();


    sleep(1);

    

    }

);

done_testing();

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

 #   $t->get_ok('/breeders/downloads');

$t->get_ok('/breeders/accessions');

    sleep(2);

 # Add a test list (pedigree_accessions)
    $t->find_element_ok("lists_link", "name", "find lists_link")->click();

    $t->find_element_ok("add_list_input", "id", "find add list input");

    my $add_list_input = $t->find_element_ok("add_list_input", "id", "find add list input test")->send_keys("pedigree_accessions");

    $t->find_element_ok("add_list_button", "id", "find add list button test")->click();

    $t->find_element_ok("view_list_pedigree_accessions", "id", "view list test")->click();


    sleep(2);

   $t->find_element_ok("type_select", "id", "add type of list")->send_keys("accessions");

   sleep(2);

    $t->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("TMS14F1001P0001\nTMS14F1006P0001\nTMS14F1008P0004\nTMS14F1011P0002\nTMS14F1013P0005\nTMS13F1303P0001\nTMS13F1020P0002\nTMS13F1307P0011\nTMS13F1307P0020\nTMS13F1288P0009\nTMS13F1108P0007\n");

    sleep(1);

    $t->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    $t->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test")->click();

    $t->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

 
#Then add pedigree_accessions list to db without using fuzzy search

    $t->get_ok('/breeders/accessions');

sleep(1);

my $add_accessions_link = $t->find_element_ok("add_accessions_link", "name", "find element add accessions link as submitter");

  $add_accessions_link->click();
 
  sleep(1);

$t->find_element_ok("accessions_list_select", "id", "select new list test")->send_keys("pedigree_accessions");

    sleep(1);

my $submit_accessions = $t->find_element_ok("new_accessions_submit", "id", "submit new accessions");
   
    $submit_accessions->click();

    sleep(1);

my $review_found_matches = $t->find_element_ok("review_found_matches_hide", "id", "review found matches test");
   
    $review_found_matches->click();

    sleep(1);

    $t->driver->accept_alert();

    sleep(1);

    $t->find_element_ok("species_name_input", "id", "input species name")->send_keys("Manihot esculenta");

    sleep(1);

    my $review_matches = $t->find_element_ok("review_absent_accessions_submit", "id", "review matches submit");

    sleep(1);   

    $review_matches->click();

    sleep(1);

    $t->driver->accept_alert();


    sleep(1);

#pedigree upload

 $t->get_ok('/breeders/accessions');

    sleep(1);

    $t->find_element_ok("upload_pedigrees_link", "id", "click on upload_pedigrees_link ")->click();

    sleep(1);

    my $upload_input = $t->find_element_ok("pedigrees_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/pedigree_upload/pedigree_upload.txt";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    my $upload_pedigrees = $t->find_element_ok("upload_pedigrees_dialog_submit", "id", "submit upload pedigrees file ");
    
    $upload_pedigrees->click();

    sleep(3);

    $t->find_element_ok("pedigrees_upload_success_dismiss", "id", "dismiss success modal ")->click();

    sleep(2);

#pedigree download

    $t->get_ok('/breeders/download');
   
    sleep(1);


    $t->find_element_ok("pedigree_accession_list_list_select", "id", "select pedigrees")->send_keys("pedigree_accessions");

    sleep(1);
  
    $t->find_element_ok("pedigree", "id", "click pedigree download button")->click();

 sleep(2);


    }

);

done_testing();

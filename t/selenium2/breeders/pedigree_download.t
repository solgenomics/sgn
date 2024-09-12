use lib 't/lib';

use Test::More 'tests' => 31;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Remote::WDKeys 'KEYS';

my $f = SGN::Test::Fixture->new();

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/breeders/accessions');
    sleep(2);

    $t->find_element_ok("lists_link", "name", "find lists_link")->click();

    my $random_val = int(rand(1000));
    my $list_name = sprintf("pedigree_accessions_%d", $random_val);
    $t->find_element_ok("add_list_input", "id", "find add list input test")->send_keys($list_name);

    $t->find_element_ok("add_list_button", "id", "find add list button test")->click();

    $t->find_element_ok("view_list_$list_name", "id", "view list test")->click();
    sleep(2);

    $t->find_element_ok(
        "updateListDescField",
        "id",
        "add type of list")->send_keys("pedigree_accessions_for_selenium_tests");

    $t->find_element_ok("type_select", "id", "add type of list")->click();
    sleep(2);

    $t->find_element_ok('option[name="accessions"]', "css", "select type 'accessions' from a list")->click();
    sleep(2);

    $t->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("TMS14F1001P0001\nTMS14F1006P0001\nTMS14F1008P0004\nTMS14F1011P0002\nTMS14F1013P0005\nTMS13F1303P0001\nTMS13F1020P0002\nTMS13F1307P0011\nTMS13F1307P0020\nTMS13F1288P0009\nTMS13F1108P0007\n");
    sleep(1);

    $t->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    $t->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test")->click();

    $t->find_element_ok("close_list_dialog_button", "id", "find close dialog button and click")->click();

    $t->get_ok('/breeders/accessions');
    sleep(1);

    my $add_accessions_link = $t->find_element_ok(
        "add_accessions_link",
        "name",
        "find element add accessions link as submitter");
    $add_accessions_link->click();
    sleep(1);

    $t->find_element_ok("list_div_list_select", "id", "select new list test")->click();
    $t->find_element_ok("//select[\@id='list_div_list_select']//option[contains(text(),\"$list_name\")]", 'xpath', "select $list_name option")->click();
    sleep(1);

    $t->find_element_ok("new_accessions_submit", "id", "submit new accessions")->click();
    sleep(7);

    $t->find_element_ok("review_found_matches_hide", "id", "review found matches test")->click();
    sleep(1);

    my $species_name_input = $t->find_element_ok("species_name_input", "id", "input species name");
    $species_name_input->send_keys(KEYS->{'control'}, 'a');
    $species_name_input->send_keys(KEYS->{'backspace'});
    $species_name_input->send_keys("Manihot esculenta");
    sleep(2);

    my $review_matches = $t->find_element_ok("review_absent_accessions_submit", "id", "review matches submit");
    $review_matches->click();

    sleep(10);

    $t->find_element_ok("close_add_accessions_saved_message_modal", "id", "close add accessions saved message modal");

    # PEDIGREE UPLOAD FROM FILE FOR LIST
    $t->get_ok('/breeders/accessions');
    sleep(1);

    $t->find_element_ok("upload_pedigrees_link", "id", "click on upload_pedigrees_link ")->click();
    sleep(1);

    my $upload_input = $t->find_element_ok("pedigrees_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/pedigree_upload/pedigree_upload_selenium.txt";

    $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);
    sleep(3);

    my $upload_pedigrees = $t->find_element_ok("upload_pedigrees_dialog_submit", "id", "submit upload pedigrees file ");
    $upload_pedigrees->click();

    sleep(3);

    $t->find_element_ok("upload_pedigrees_store", "id", "find and upload pedigrees store")->click();
    sleep(3);
    $t->find_element_ok("pedigrees_upload_success_dismiss", "id", "dismiss success modal ")->click();
    sleep(1);

    # PEDIGREE LIST DOWNLOAD
    $t->get_ok('/breeders/download');
    sleep(10);

    $t->find_element_ok("pedigree_accession_list_list_select", "id", "select pedigrees accession download list")->click();
    sleep(4);

    $t->find_element_ok(
        "//select[\@id='pedigree_accession_list_list_select']/option[contains(text(),\"$list_name\")]",
        "xpath",
        "Confirm $list_name pedigrees accession list to download")->click();
    sleep(1);

    $t->find_element_ok("pedigree", "id", "click pedigree download button")->click();
    sleep(3);

});
$t->driver->close();
done_testing();

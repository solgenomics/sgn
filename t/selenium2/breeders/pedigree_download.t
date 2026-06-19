use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Remote::WDKeys 'KEYS';
use Selenium::Firefox::Profile;

my $f = SGN::Test::Fixture->new();

my $t = SGN::Test::WWW::WebDriver->new();

# Create firefox profile for download options
my $profile = Selenium::Firefox::Profile->new;
$profile->set_preference( 'browser.download.folderList', 2 ); # Use custom download folder
$profile->set_preference( 'browser.download.dir', '/downloads' ); # Path to custom download folder on selenium host
$profile->set_preference( 'browser.helperApps.neverAsk.saveToDisk', 'plain/text', 'application/text' ); # Automatically download to disk

# Create web driver
my $driver = Selenium::Remote::Driver->new(firefox_profile => $profile, base_url => $ENV{SGN_TEST_SERVER}, remote_server_addr => $ENV{SGN_REMOTE_SERVER_ADDR} || 'localhost');
$t->driver($driver);

$t->while_logged_in_as("submitter", sub {
    $t->get_ok('/breeders/accessions');
    sleep(1); # FIXME Need to wait for button click handler to be registered

    $t->click_ok("lists_link", "name", "find lists_link");

    my $random_val = int(rand(1000));
    my $list_name = sprintf("pedigree_accessions_%d", $random_val);
    $t->send_keys_ok("add_list_input", "id", $list_name, "find add list input test");

    $t->click_ok("add_list_button", "id", "find add list button test");

    $t->click_ok("view_list_$list_name", "id", "view list test");

    $t->send_keys_ok(
        "updateListDescField",
        "id",
        "pedigree_accessions_for_selenium_tests",
        "add type of list");

    $t->click_ok("type_select", "id", "add type of list");

    $t->click_ok('option[name="accessions"]', "css", "select type 'accessions' from a list");

    $t->send_keys_ok("dialog_add_list_item", "id", "TMS14F1001P0001\nTMS14F1006P0001\nTMS14F1008P0004\nTMS14F1011P0002\nTMS14F1013P0005\nTMS13F1303P0001\nTMS13F1020P0002\nTMS13F1307P0011\nTMS13F1307P0020\nTMS13F1288P0009\nTMS13F1108P0007\n", "add test list");

    $t->click_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test");

    $t->click_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test");

    $t->click_ok("close_list_dialog_button", "id", "find close dialog button and click");

    $t->get_ok('/breeders/accessions');
    sleep(1); # FIXME Need to wait for button click handler to be registered

    $t->click_ok("add_accessions_link", "name", "find element add accessions link as submitter");

    $t->click_ok("list_div_list_select", "id", "select new list test");
    $t->click_ok("//select[\@id='list_div_list_select']//option[contains(text(),\"$list_name\")]", 'xpath', "select $list_name option");

    $t->click_ok("new_accessions_submit", "id", "submit new accessions");
    $t->wait_for_working_dialog();

    $t->click_ok("review_found_matches_hide", "id", "review found matches test");

    $t->send_keys_ok("species_name_input", "id", [KEYS->{'control'}, 'a'], "input species name clear");
    $t->send_keys_ok("species_name_input", "id", KEYS->{'backspace'}, "input species name backspace");
    $t->send_keys_ok("species_name_input", "id", "Manihot esculenta", "input species name");

    $t->click_ok("review_absent_accessions_submit", "id", "review matches submit");
    $t->wait_for_network_idle();
    $t->find_element_ok("close_add_accessions_saved_message_modal", "id", "close add accessions saved message modal");

    # PEDIGREE UPLOAD FROM FILE FOR LIST
    $t->get_ok('/breeders/accessions');
    sleep(1); # FIXME Need to wait for button click handler to be registered

    $t->click_ok("upload_pedigrees_link", "id", "click on upload_pedigrees_link ");

    my $filename = $f->config->{basepath}."/t/data/pedigree_upload/pedigree_upload_selenium.txt";

    $t->driver()->upload_file($filename);

    $t->send_keys_ok("pedigrees_uploaded_file", "id", $filename, "input file name");

    $t->click_ok("upload_pedigrees_dialog_submit", "id", "submit upload pedigrees file ");
    $t->wait_for_network_idle();

    $t->click_ok("upload_pedigrees_store", "id", "find and upload pedigrees store");
    $t->click_ok("pedigrees_upload_success_dismiss", "id", "dismiss success modal ");
    $t->wait_for_network_idle();

    # PEDIGREE LIST DOWNLOAD
    $t->get_ok('/breeders/download');
    sleep(3); # FIXME Need to wait for page to settle / elements to register

    $t->click_ok("download_pedigrees_onswitch", "id", "open download pedigrees section");
    $t->click_ok("pedigree_accession_list_list_select", "id", "select pedigrees accession download list");

    $t->click_ok(
        "//select[\@id='pedigree_accession_list_list_select']/option[contains(text(),\"$list_name\")]",
        "xpath",
        "Confirm $list_name pedigrees accession list to download");

    $t->click_ok("pedigree", "id", "click pedigree download button");
    sleep(1);

});
$t->driver->close();
done_testing();

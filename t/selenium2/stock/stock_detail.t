use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();
use Selenium::Remote::WDKeys 'KEYS';

$t->while_logged_in_as("submitter", sub {

    $t->get_ok('stock/38879/view');

    # Test edit / cancel button for stock / accession
    $t->click_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Edit")]', "xpath", "find edit link");
    $t->click_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Cancel")]', "xpath", "find edit link");
    $t->click_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Edit")]', "xpath", "find edit link");

    # Test edit form for stock / accession
    my $species_name_input = $t->find_element_ok("species_name", "id", "edit stock organism");
    $species_name_input->send_keys(KEYS->{'control'}, 'a');
    $species_name_input->send_keys(KEYS->{'backspace'});
    $species_name_input->send_keys('Manihot esculenta');

    $t->click_ok("stockForm_reset_button", "id", "find reset edit button");

    $species_name_input = $t->find_element_ok("species_name", "id", "edit stock organism");
    $species_name_input->send_keys(KEYS->{'control'}, 'a');
    $species_name_input->send_keys(KEYS->{'backspace'});
    $species_name_input->send_keys('Manihot esculenta');

    $t->click_ok("type_id", "name", "edit stock type");
    $t->click_ok(
        '//select[@name="type_id"]/option[contains(text(), "tissue_sample")]',
        "xpath",
        "select stock type as 'tissue_sample'");

    my $unique_name = $t->find_element_ok("uniquename", "name", "edit stock uniquename");
    $unique_name->send_keys(KEYS->{'control'}, 'a');
    $unique_name->send_keys(KEYS->{'backspace'});
    $unique_name->send_keys('UG120001_Testedit');

    $t->send_keys_ok("description", "name", 'Test description edit.', "edit stock description");
    $t->click_ok("stockForm_submit_button", "id", "find submit edit button");
    $t->wait_for_network_idle();

    # Test adding and removing synonyms from stock additional info section
    # my $synonym_onswitch = $t->find_element_ok("stock_additional_info_section_onswitch",  "id",  "click to open image panel");
    # $synonym_onswitch->click();
    # sleep(3);

    $t->click_ok("stock_add_synonym", "id", "find add synonym link");
    $t->click_ok("synonyms_select", "id", "find add synonym select");
    $t->click_ok(
        '//select[@id="synonyms_select"]/option[@title="stock_synonym"]',
        "xpath",
        "select 'stock_synonym' as value");

    $t->send_keys_ok("synonyms_prop", "id", 'test_synonym', "find add synonym input");

    $t->wait_for_network_idle();
    $t->click_ok("synonyms_addProp_submit", "id", "add synonym submit");
    $t->accept_alert();
    $t->wait_for_network_idle();

    $t->click_ok('//div[@id="synonyms_content"]/a[text() = "X"]', "xpath", "find delete synonym link");

    $t->accept_alert_ok('accept alert');
    $t->accept_alert_ok('accept alert');
    $t->wait_for_network_idle();

    # Test adding parents from pedigree info section
    $t->get_ok('stock/38879/view');

    my $pedigree_section = $t->find_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    sleep(2);
    $pedigree_section->click();
    sleep(2);

    $t->click_ok('add_parent_link', 'id', 'find add parent link');

    my $stock_name = $t->find_element_ok("stock_autocomplete", "id", "add parent input");
    $stock_name->send_keys('test_wrong_stock_name');

    $t->click_ok("male", "id", "find male input");
    $t->click_ok("female", "id", "find female input");
    $t->click_ok("add_parent_cross_type", "id", "add parent input");

    $t->click_ok(
        '//select[@id="add_parent_cross_type"]/option[@value="biparental"]',
        "xpath",
        "add parent input");
    $t->click_ok("add_parent_submit", "id", "submit add parent");

    $t->accept_alert();

    $stock_name->send_keys(KEYS->{'control'}, 'a');
    $stock_name->send_keys(KEYS->{'backspace'});
    $stock_name->send_keys('test_accession1');

    $t->click_ok("add_parent_submit", "id", "submit add parent");
    $t->accept_alert();
    $t->wait_for_network_idle();

    $t->get_ok('stock/38879/view');

    my $pedigree_section = $t->find_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    sleep(2);
    $pedigree_section->click();
    sleep(2);

    $t->click_ok('add_parent_link', 'id', 'find add parent link');

    $stock_name = $t->find_element_ok("stock_autocomplete", "id", "add parent input");

    $t->click_ok("male", "id", "find male input");

    $stock_name->send_keys(KEYS->{'control'}, 'a');
    $stock_name->send_keys(KEYS->{'backspace'});
    $stock_name->send_keys('test_accession2');
  
    $t->click_ok("add_parent_submit", "id", "submit add parent");
    $t->accept_alert();

    # Test if parents were added to database and now in a view
    $t->get_ok('stock/38879/view');

    my $pedigree_section = $t->find_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    sleep(2);
    $pedigree_section->click();
    sleep(2);

    my $pedigree_view = $t->find_element_ok(
        '//div[@id="pdgv-wrap"]',
        'xpath',
        'find a content of pedigree view')->get_attribute('innerHTML');

    ok($pedigree_view =~ /test_accession1/, "Verify if test_accession1 on pedigree panel");
    ok($pedigree_view =~ /test_accession2/, "Verify if test_accession2 on pedigree panel");

    my $pedigree_string = $t->find_element_ok("pedigree_string", "id", "verify pedigree string")->get_text();

    ok($pedigree_string =~ /test_accession1\/test_accession2/, "Verify if pedigree string contain 'test_accession1/test_accession2'");

    $t->click_ok("remove_parent_link", "id", "find delete parent link");

    # Test removing parents from pedigree info section
    $t->click_ok(
        '//div[@id="remove_parent_list"]/a[1]',
        "xpath",
        "find delete parent link");

    $t->accept_alert();
    $t->accept_alert();
    $t->wait_for_network_idle();

    my $pedigree_section = $t->find_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    sleep(2);
    $pedigree_section->click();
    sleep(2);

    $t->click_ok("remove_parent_link", "id", "find delete parent link");
    $t->click_ok(
        '//div[@id="remove_parent_list"]/a[1]',
        "xpath",
        "find delete parent link");

    $t->accept_alert();
    $t->accept_alert();
    }
);

$t->driver->close();
done_testing();

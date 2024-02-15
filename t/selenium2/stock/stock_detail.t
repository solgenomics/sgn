use lib 't/lib';

use Test::More 'tests' => 46;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();
use Selenium::Remote::WDKeys 'KEYS';

$t->while_logged_in_as("submitter", sub {
    sleep(2);

    $t->get_ok('stock/38879/view');
    sleep(2);

    # Test edit / cancel button for stock / accession
    $t->find_element_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Edit")]', "xpath", "find edit link")->click();
    sleep(2);

    $t->find_element_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Cancel")]', "xpath", "find edit link")->click();
    sleep(2);

    $t->find_element_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Edit")]', "xpath", "find edit link")->click();
    sleep(2);

    # Test edit form for stock / accession
    my $species_name_input = $t->find_element_ok("species_name", "id", "edit stock organism");
    $species_name_input->send_keys(KEYS->{'control'}, 'a');
    $species_name_input->send_keys(KEYS->{'backspace'});
    $species_name_input->send_keys('Manihot esculenta');

    $t->find_element_ok("stockForm_reset_button", "id", "find reset edit button")->click();
    sleep(1);

    $species_name_input = $t->find_element_ok("species_name", "id", "edit stock organism");
    $species_name_input->send_keys(KEYS->{'control'}, 'a');
    $species_name_input->send_keys(KEYS->{'backspace'});
    $species_name_input->send_keys('Manihot esculenta');

    $t->find_element_ok("type_id", "name", "edit stock type")->click();
    sleep(1);

    $t->find_element_ok(
        '//select[@name="type_id"]/option[contains(text(), "tissue_sample")]',
        "xpath",
        "select stock type as 'tissue_sample'")->click();
    sleep(1);

    my $unique_name = $t->find_element_ok("uniquename", "name", "edit stock uniquename");
    $unique_name->send_keys(KEYS->{'control'}, 'a');
    $unique_name->send_keys(KEYS->{'backspace'});
    $unique_name->send_keys('UG120001_Testedit');

    $t->find_element_ok("description", "name", "edit stock description")->send_keys('Test description edit.');

    $t->find_element_ok("stockForm_submit_button", "id", "find submit edit button")->click();
    sleep(1);

    # Test adding and removing synonyms from stock additional info section
    # my $synonym_onswitch = $t->find_element_ok("stock_additional_info_section_onswitch",  "id",  "click to open image panel");
    # $synonym_onswitch->click();
    # sleep(3);

    $t->find_element_ok("stock_add_synonym", "id", "find add synonym link")->click();
    sleep(1);

    $t->find_element_ok("synonyms_select", "id", "find add synonym select")->click();
    sleep(1);

    $t->find_element_ok(
        '//select[@id="synonyms_select"]/option[@title="stock_synonym"]',
        "xpath",
        "select 'stock_synonym' as value")->click();
    sleep(1);

    $t->find_element_ok("synonyms_prop", "id", "find add synonym input")->send_keys('test_synonym');

    $t->find_element_ok("synonyms_addProp_submit", "id", "add synonym submit")->click();
    sleep(10);

    $t->driver->accept_alert();
    sleep(5);

    $t->find_element_ok('//div[@id="synonyms_content"]/a[text() = "X"]', "xpath", "find delete synonym link")->click();

    $t->driver->accept_alert();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);

    # Test adding parents from pedigree info section
    $t->get_ok('stock/38879/view');
    sleep(2);

    my $pedigree_section = $t->find_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    sleep(2);
    $pedigree_section->click();
    sleep(2);

    my $add_parent_link = $t->find_element_ok('add_parent_link', 'id', 'find add parent link');
    $add_parent_link->click();
    sleep(1);

    my $stock_name = $t->find_element_ok("stock_autocomplete", "id", "add parent input");
    $stock_name->send_keys('test_wrong_stock_name');

    $t->find_element_ok("male", "id", "find male input")->click();
    $t->find_element_ok("female", "id", "find female input")->click();

    $t->find_element_ok("add_parent_cross_type", "id", "add parent input")->click();
    sleep(1);

    $t->find_element_ok(
        '//select[@id="add_parent_cross_type"]/option[@value="biparental"]',
        "xpath",
        "add parent input")->click();
    sleep(1);
    
    $t->find_element_ok("add_parent_submit", "id", "submit add parent")->click();
    sleep(1);

    $t->driver->accept_alert();
    sleep(1);

    $stock_name->send_keys(KEYS->{'control'}, 'a');
    $stock_name->send_keys(KEYS->{'backspace'});
    $stock_name->send_keys('test_accession1');

    $t->find_element_ok("add_parent_submit", "id", "submit add parent")->click();
    sleep(1);

    $t->driver->accept_alert();
    sleep(4);

    $t->get_ok('stock/38879/view');
    sleep(5);

    my $pedigree_section = $t->find_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    sleep(2);
    $pedigree_section->click();
    sleep(2);

    my $add_parent_link = $t->find_element_ok('add_parent_link', 'id', 'find add parent link');
    $add_parent_link->click();
    sleep(1);

    $stock_name = $t->find_element_ok("stock_autocomplete", "id", "add parent input");

    $t->find_element_ok("male", "id", "find male input")->click();

    $stock_name->send_keys(KEYS->{'control'}, 'a');
    $stock_name->send_keys(KEYS->{'backspace'});
    $stock_name->send_keys('test_accession2');
  
    $t->find_element_ok("add_parent_submit", "id", "submit add parent")->click();
    sleep(1);

    $t->driver->accept_alert();
    sleep(2);

    # Test if parents were added to database and now in a view
    $t->get_ok('stock/38879/view');
    sleep(5);

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

    $t->find_element_ok("remove_parent_link", "id", "find delete parent link")->click();
    sleep(1);

    # Test removing parents from pedigree info section
    $t->find_element_ok(
        '//div[@id="remove_parent_list"]/a[1]',
        "xpath",
        "find delete parent link")->click();
    sleep(1);

    $t->driver->accept_alert();
    sleep(1);

    $t->driver->accept_alert();
    sleep(3);

    my $pedigree_section = $t->find_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    sleep(2);
    $pedigree_section->click();
    sleep(2);

    $t->find_element_ok("remove_parent_link", "id", "find delete parent link")->click();
    sleep(1);

    $t->find_element_ok(
        '//div[@id="remove_parent_list"]/a[1]',
        "xpath",
        "find delete parent link")->click();

    $t->driver->accept_alert();
    sleep(1);

    $t->driver->accept_alert();
    sleep(3);

    }
);

$t->driver->close();
done_testing();

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('stock/38879/view');

    $t->find_element_ok("[Edit]", "partial_link_text", "find edit link")->click();

    sleep(1);

    $t->find_element_ok("[Cancel]", "partial_link_text", "find cancel edit link")->click();

    sleep(1);

    $t->find_element_ok("[Edit]", "partial_link_text", "find edit link")->click();

    sleep(1);

    $t->find_element_ok("species_name", "id", "edit stock organism")->send_keys('Manihot esculenta');

    $t->find_element_ok("stockForm_reset_button", "id", "find reset edit button")->click();

    my $species_name = $t->find_element_ok("species_name", "id", "edit stock organism");
    $species_name->clear();
    $species_name->send_keys('Manihot esculenta');

    $t->find_element_ok("type_id", "name", "edit stock type")->send_keys('tissue_sample');

    $t->find_element_ok("name", "name", "edit stock name")->send_keys('UG120001_Testedit');

    $t->find_element_ok("uniquename", "name", "edit stock uniquename")->send_keys('UG120001_Testedit');

    $t->find_element_ok("description", "name", "edit stock description")->send_keys('Test description edit.');

    $t->find_element_ok("stockForm_submit_button", "id", "find submit edit button")->click();

    sleep(1);

    $t->find_element_ok("stock_add_synonym", "id", "find add synonym link")->click();

    sleep(1);

    $t->find_element_ok("synonyms_select", "id", "find add synonym select")->send_keys('synonym');

    sleep(1);

    $t->find_element_ok("synonyms_prop", "id", "find add synonym input")->send_keys('test_synonym');

    $t->find_element_ok("synonyms_addProp_submit", "id", "add synonym submit")->click();

    sleep(1);
    $t->driver->accept_alert();

    $t->get_ok('stock/38879/view');

    sleep(1);

    $t->find_element_ok("X", "partial_link_text", "find delete synonym link")->click();

    $t->driver->accept_alert();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);

    $t->find_element_ok("[New]", "partial_link_text", "find new stock link")->click();

    sleep(3);

    $t->find_element_ok("species_name", "id", "edit stock organism")->send_keys('Manihot esculenta');

    $t->find_element_ok("stockForm_reset_button", "id", "find reset edit button")->click();

    $t->find_element_ok("species_name", "id", "edit stock organism")->send_keys('Manihot esculenta');

    $t->find_element_ok("type_id", "name", "edit stock type")->send_keys('accession');

    $t->find_element_ok("name", "name", "edit stock name")->send_keys('New_Test');

    $t->find_element_ok("uniquename", "name", "edit stock uniquename")->send_keys('New_Test');

    $t->find_element_ok("description", "name", "edit stock description")->send_keys('New Test description.');

    $t->find_element_ok("stockForm_submit_button", "id", "find submit edit button")->click();

    sleep(1);

    $t->find_element_ok("[Delete]", "partial_link_text", "find delete link")->click();

    sleep(1);

    $t->find_element_ok("[Cancel Delete]", "partial_link_text", "find cancel edit link")->click();

    sleep(1);

    $t->find_element_ok("[Delete]", "partial_link_text", "find delete link")->click();

    sleep(1);

    $t->find_element_ok("stockForm_delete_button", "id", "find submit delete button")->click();

    }

);

done_testing();

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('stock/38879/view');

    $t->find_element_ok("[Edit]", "partial_link_text", "find edit link")->click();

    sleep(2);

    $t->find_element_ok("[Cancel]", "partial_link_text", "find cancel edit link")->click();

    sleep(1);

    $t->find_element_ok("[Edit]", "partial_link_text", "find edit link")->click();

    sleep(1);

    $t->find_element_ok("species_name", "id", "edit stock organism")->send_keys('Manihot esculenta');

    $t->find_element_ok("stockForm_reset_button", "id", "find reset edit button")->click();

    sleep(1);
    
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

    $t->get_ok('stock/38879/view');

    sleep(2);

    $t->find_element_ok("Additional information", "partial_link_text", "find additional info link")->click();

    $t->find_element_ok("Associated loci", "partial_link_text", "find associated loci link")->click();

    $t->find_element_ok("Experimental data", "partial_link_text", "find experimental data link")->click();

    $t->find_element_ok("add_parent_link", "id", "find add parent link")->click();

    sleep(1);

    my $stock_name = $t->find_element_ok("stock_autocomplete", "id", "add parent input");
    $stock_name->send_keys('test_wrong_stock_name');

    $t->find_element_ok("male", "id", "find male input")->click();
    $t->find_element_ok("female", "id", "find female input")->click();
    
    $t->find_element_ok("add_parent_dialog_submit_button", "id", "submit add parent")->click();

    sleep(1);
    $t->driver->accept_alert();
    sleep(1);

    $stock_name->clear();
    $stock_name->send_keys('test_accession1');
  
    $t->find_element_ok("add_parent_dialog_submit_button", "id", "submit add parent")->click();

    sleep(1);
    $t->driver->accept_alert();
    sleep(2);

    $t->find_element_ok("add_parent_link", "id", "find add parent link")->click();

    sleep(1);

    my $stock_name = $t->find_element_ok("stock_autocomplete", "id", "add parent input");

    $t->find_element_ok("male", "id", "find male input")->click();
    
    $stock_name->clear();
    $stock_name->send_keys('test_accession2');
  
    $t->find_element_ok("add_parent_dialog_submit_button", "id", "submit add parent")->click();

    sleep(1);
    $t->driver->accept_alert();
    sleep(2);

    $t->find_element_ok("test_accession1", "partial_link_text", "find added parent in pedigree tree diagram");

    $t->find_element_ok("test_accession2", "partial_link_text", "find added parent in pedigree tree diagram");

    my $pedigree_string = $t->find_element_ok("pedigree_string", "id", "verify pedigree string")->get_text();

    if ($pedigree_string ne 'test_accession1/test_accession2') {
      die;
    }

    my $num_related_stock_sections = 4;
    my $list_name;
    my $list_item_div;
    for (my $section_num = 0; $section_num < $num_related_stock_sections; $section_num = $section_num+1) {

        $list_name = "item_list_".$section_num."_new_list_name";
	$list_item_div = "item_list_".$section_num."_add_to_new_list";

        $t->find_element_ok($list_name, "id", "add items to new list name")->send_keys($list_name);

    	$t->find_element_ok($list_item_div, "id", "add items to new list")->click();

    	sleep(1);
    	$t->driver->accept_alert();
    	sleep(1);

    }




    $t->find_element_ok("remove_parent_link", "id", "find delete parent link")->click();

    sleep(1);

    $t->find_element_ok("X", "partial_link_text", "find delete parent link")->click();


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

    sleep(2);

    $t->find_element_ok("[Delete]", "partial_link_text", "find delete link")->click();

    sleep(1);

    $t->find_element_ok("[Cancel Delete]", "partial_link_text", "find cancel edit link")->click();

    sleep(2);

    $t->find_element_ok("[Delete]", "partial_link_text", "find delete link")->click();

    sleep(1);

    $t->find_element_ok("stockForm_delete_button", "id", "find submit delete button")->click();

    }

);

done_testing();

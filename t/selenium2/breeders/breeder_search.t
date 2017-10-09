use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use CXGN::BreederSearch;

my $f = SGN::Test::Fixture->new();

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });

my $refresh = 'SELECT refresh_materialized_views()';
my $h = $f->dbh->prepare($refresh);
$h->execute();

my $t = SGN::Test::WWW::WebDriver->new();
#$t->driver->set_implicit_wait_timeout(5);

$t->get_ok('/breeders/search');

$t->find_element_ok("c1_to_list_menu", "id", "check if login prompt appears for c1")->send_keys('breeding programs');

sleep(1);

$t->while_logged_in_as("submitter", sub {
    $t->get_ok('/breeders/search');

    $t->find_element_ok("select1", "id", "retrieve traits")->send_keys('traits');

    sleep(1);

    $t->find_element_ok("c1_data", "id", "select specific trait")->send_keys('dry matter content|CO_334:0000092');

    sleep(1);

    $t->find_element_ok("c1_select_all", "id", "select all traits")->click();

    sleep(1);

    $t->find_element_ok("select2", "id", "retrieve trials")->send_keys('trials');

    sleep(3);

    $t->find_element_ok("c2_data", "id", "select specific trial")->send_keys('Kasese solgs trial');

    sleep(1);

    $t->find_element_ok("c2_select_all", "id", "select all trials")->click();

    sleep(1);

    $t->find_element_ok("select3", "id", "retrieve years")->send_keys('years');

    sleep(3);

    $t->find_element_ok("c3_data", "id", "select specific year")->send_keys('2014');

    sleep(1);

    $t->find_element_ok("c3_select_all", "id", "select all years")->click();

    sleep(1);

    $t->find_element_ok("wizard_save_dataset_button", "id", "save dataset")->click();

    sleep(1);

    $t->find_element_ok("save_wizard_dataset_name", "id", "find dataset name input box")->send_keys("another dataset");
    
    sleep(1);

    $t->find_element_ok("wizard_save_dataset_submit_button", "id", "find wizard save dataset submit button")->click();

    sleep(1);

    $t->driver->accept_alert();
    
    sleep(1);

    $t->find_element_ok("select4", "id", "retrieve accessions")->send_keys('accessions');

    sleep(3);

    $t->find_element_ok("c4_data", "id", "select specific accession")->send_keys('UG120001');

    sleep(1);

    $t->find_element_ok("c4_select_all", "id", "select all accessions")->click();

    sleep(1);

    $t->find_element_ok("c1_data_new_list_name", "id", "new list")->send_keys('trait_list');

    $t->find_element_ok("c1_data_add_to_new_list", "id", "create trait list")->click();

    sleep(3);

    $t->driver->accept_alert();

    $t->find_element_ok("c2_data_new_list_name", "id", "new list")->send_keys('trial_list');

    $t->find_element_ok("c2_data_add_to_new_list", "id", "create trial list")->click();

    sleep(1);

    $t->driver->accept_alert();

    $t->find_element_ok("c3_data_new_list_name", "id", "new list")->send_keys('year_list');

    $t->find_element_ok("c3_data_add_to_new_list", "id", "create year list")->click();

    sleep(1);

    $t->driver->accept_alert();

    $t->find_element_ok("c4_data_new_list_name", "id", "new list")->send_keys('acc_list');

    $t->find_element_ok("c4_data_add_to_new_list", "id", "create accession list")->click();

    sleep(1);

    $t->driver->accept_alert();

    $t->find_element_ok("paste_list_select", "id", "paste test acc list")->send_keys('test_list');

    sleep(2);

    $t->find_element_ok("c1_data", "id", "select pasted test accession")->send_keys('test_accession1');

    $t->find_element_ok("c1_select_all", "id", "select all pasted accessions")->click();

    ## add test for '0 results' error here?

    $t->find_element_ok("c1_data_list_select", "id", "select acc_list")->send_keys('acc_list');

    $t->find_element_ok("c1_data_button", "id", "add c1_data to acc_list")->click();

    sleep(1);

    $t->driver->accept_alert();

    my $refresh_lists = $t->find_element_ok("paste_list_refresh", "id", " refresh lists");
    sleep(1);
    $refresh_lists->click();

    sleep(1);

    $t->find_element_ok("paste_list_select", "id", "paste test acc list")->send_keys('acc_list');

    sleep(5);

    $t->find_element_ok("c1_data", "id", "select pasted test accession")->send_keys('test_accession1');

    $t->find_element_ok("c1_data", "id", "select pasted list accession")->send_keys('UG120001');

    sleep(1);

    $t->find_element_ok("select1", "id", "retrieve breeding programs")->send_keys('breeding_programs');

    sleep(2);

    $t->find_element_ok("c1_data", "id", "select specific breeding_program")->send_keys('test');

    $t->find_element_ok("c2_querytype_or", "id", "toggle c2_querytype to intersect")->click();

    sleep(1);

    $t->find_element_ok("c1_select_all", "id", "select all breeding programs")->click();

    $t->find_element_ok("select2", "id", "retrieve genotyping protocols")->send_keys('genotyping_protocols');

    sleep(1);

    $t->find_element_ok("c2_data", "id", "select specific genotyping protocol")->send_keys('GBS ApeKI genotyping v4');

    $t->find_element_ok("c3_querytype_or", "id", "toggle c3_querytype to intersect")->click();

    $t->find_element_ok("c2_select_all", "id", "select all breeding programs")->click();

    $t->find_element_ok("select3", "id", "retrieve locations")->send_keys('locations');

    sleep(1);

    $t->find_element_ok("c3_data", "id", "select specific location")->send_keys('test_location');

    $t->find_element_ok("c4_querytype_or", "id", "toggle c4_querytype to intersect")->click();

    $t->find_element_ok("c3_select_all", "id", "select all locations")->click();

    $t->find_element_ok("select4", "id", "retrieve plots")->send_keys('plots');

    sleep(2);

    $t->find_element_ok("c4_data", "id", "select specific plot")->send_keys('KASESE_TP2013_1000');

    $t->find_element_ok("c2_querytype_and", "id", "toggle c2_querytype to union")->click();

    $t->find_element_ok("c3_querytype_and", "id", "toggle c3_querytype to union")->click();

    $t->find_element_ok("c4_querytype_and", "id", "toggle c4_querytype to union")->click();

    }

);

done_testing();

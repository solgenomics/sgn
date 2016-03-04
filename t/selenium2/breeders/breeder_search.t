use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->get_ok('/breeders/search');

$t->find_element_ok("c1_to_list_menu", "id", "check if login prompt appears for c1")->send_keys('breeding programs');

sleep(1);

$t->while_logged_in_as("submitter", sub {
    $t->get_ok('/breeders/search');

    $t->find_element_ok("select1", "id", "retrieve traits")->send_keys('traits');

    sleep(1);

    $t->find_element_ok("c1_data", "id", "select specific trait")->send_keys('dry matter content|CO:0000092');

    sleep(1);

    $t->find_element_ok("c1_select_all", "id", "select all traits")->click();

    sleep(1);

    $t->find_element_ok("select2", "id", "retrieve trials")->send_keys('trials');

    sleep(2);

    $t->find_element_ok("c2_data", "id", "select specific trial")->send_keys('Kasese solgs trial');

    sleep(1);

    $t->find_element_ok("c2_select_all", "id", "select all trials")->click();

    sleep(1);

    $t->find_element_ok("select3", "id", "retrieve years")->send_keys('years');

    sleep(2);

    $t->find_element_ok("c3_data", "id", "select specific year")->send_keys('2014');

    sleep(1);

    $t->find_element_ok("c3_select_all", "id", "select all years")->click();

    sleep(1);

    $t->find_element_ok("select4", "id", "retrieve accessions")->send_keys('accessions');

    sleep(1);

    $t->find_element_ok("c4_data", "id", "select specific accession")->send_keys('UG120001');

    sleep(1);

    $t->find_element_ok("c4_select_all", "id", "select all accessions")->click();

    sleep(1);

    $t->find_element_ok("c1_data_new_list_name", "id", "new list")->send_keys('trait_list');

    $t->find_element_ok("c1_data_add_to_new_list", "id", "create trait list")->click();

    sleep(1);

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

    sleep(1);

    $t->find_element_ok("c1_select_all", "id", "select all pasted accessions")->click();

    sleep(1);

    $t->find_element_ok("c1_data_list_select", "id", "select acc_list")->send_keys('acc_list');

    $t->find_element_ok("c1_data_button", "id", "add c1_data to acc_list")->click();

    sleep(2);

    $t->driver->accept_alert();

    $t->find_element_ok("refresh_lists", "id", " refresh lists")->click();

    sleep(1);

    $t->find_element_ok("paste_list_select", "id", "paste test acc list")->send_keys('acc_list');

    sleep(5);

    $t->find_element_ok("c1_data", "id", "select pasted test accession")->send_keys('test_accession1');

    sleep(1);

    $t->find_element_ok("c1_data", "id", "select pasted list accession")->send_keys('UG120001');

    sleep(1);

    $t->find_element_ok("c1_select_all", "id", "select all pasted accessions")->click();

    sleep(1);

    $t->find_element_ok("c2_querytype_or", "id", "toggle querytype to intersect")->click();

    sleep(1);

    $t->find_element_ok("select2", "id", "retrieve breeding programs")->send_keys('breeding_programs');

    sleep(1);

    $t->find_element_ok("select3", "id", "test select error message with retrieve genotyping protocols")->send_keys('genotyping_protocols');

    sleep(1);

    $t->find_element_ok("//div[contains(., 'Error: Select at least one option from each preceding panel')]", "xpath", "verify select error message")->get_text();

    sleep(1);

    $t->find_element_ok("c2_select_all", "id", "select all breeding programs")->click();

    sleep(1);

    $t->find_element_ok("select3", "id", "test 0 results error message with retrieve genotyping protocols")->send_keys('genotyping_protocols');

    sleep(1);

    $t->find_element_ok("//div[contains(., '0 matches. No results to display')]", "xpath", "verify 0 matches error message")->get_text();

    sleep(1);

    $t->find_element_ok("c2_querytype_and", "id", "toggle querytype to union")->click();

    sleep(1);

    $t->find_element_ok("select3", "id", "retrieve locations")->send_keys('locations');

    sleep(1);

    $t->find_element_ok("c3_select_all", "id", "select all locations")->click();

    sleep(1);

    $t->find_element_ok("select4", "id", "retrieve plots")->send_keys('plots');

    sleep(1);

    $t->find_element_ok("c4_data", "id", "select specific plot")->send_keys('test_trial21');

    sleep(1);

    $t->find_element_ok("select3", "id", "retrieve genotyping protocols")->send_keys('genotyping_protocols');

    sleep(1);

    $t->find_element_ok("c3_select_all", "id", "select all genotyping protocols")->click();

    sleep(1);

    $t->find_element_ok("select4", "id", "retrieve plots")->send_keys('plots');

    sleep(1);

    $t->find_element_ok("c4_data", "id", "select specific plot")->send_keys('KASESE_TP2013_1000');

    }

);

done_testing();

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->get_ok('/breeders/search');

$t->find_element_ok("c1_to_list_menu", "id", "check if login prompt appears for c1")->send_keys('breeding programs');

sleep(1);

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/search');

    $t->find_element_ok("select1", "id", "select breeding programs")->send_keys('breeding programs');

    sleep(1);

    $t->find_element_ok("c1_data", "id", "select test breeding program")->send_keys('test');

    sleep(1);

    $t->find_element_ok("c1_select_all", "id", "select all breeding programs")->click();

    sleep(1);

    $t->find_element_ok("select2", "id", "select trials")->send_keys('trials');

    sleep(2);

    $t->find_element_ok("c2_data", "id", "select test trial")->send_keys('test_trial');

    sleep(1);

    $t->find_element_ok("c2_select_all", "id", "select all trials")->click();

    sleep(1);

    $t->find_element_ok("select3", "id", "select years")->send_keys('years');

    sleep(2);

    $t->find_element_ok("c3_data", "id", "select test year")->send_keys('2014');

    sleep(1);

    $t->find_element_ok("c3_select_all", "id", "select all years")->click();

    sleep(1);

    $t->find_element_ok("retrieve_stocklist_button", "id", "select accessions")->click();

    sleep(1);

    $t->find_element_ok("stock_data", "id", "select test accession")->send_keys('test_accession1');

    sleep(1);

    $t->find_element_ok("stock_select_all", "id", "select all accessions")->click();

    sleep(1);

    $t->find_element_ok("c1_data_new_list_name", "id", "new list")->send_keys('bp_list');

    $t->find_element_ok("c1_data_add_to_new_list", "id", "add bp to list")->click();

    sleep(1);

    $t->driver->accept_alert();

    $t->find_element_ok("c2_data_new_list_name", "id", "new list")->send_keys('trial_list');

    $t->find_element_ok("c2_data_add_to_new_list", "id", "add trials to list")->click();

    sleep(1);

    $t->driver->accept_alert();

    $t->find_element_ok("c3_data_new_list_name", "id", "new list")->send_keys('year_list');

    $t->find_element_ok("c3_data_add_to_new_list", "id", "add trials to list")->click();

    sleep(1);

    $t->driver->accept_alert();

    $t->find_element_ok("stock_data_new_list_name", "id", "new list")->send_keys('acc_list');

    $t->find_element_ok("stock_data_add_to_new_list", "id", "add accs to list")->click();

    sleep(1);

    $t->driver->accept_alert();

    }

);

done_testing();

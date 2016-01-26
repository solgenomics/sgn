use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("curator", sub { 

    $t->get_ok('breeders/manage_programs');

    $t->find_element_ok("new_breeding_program_link", "id", "find new breeding program")->click();

    sleep(1);

    $t->find_element_ok("new_breeding_program_name", "id", "find name")->send_keys('Test BP1');

    $t->find_element_ok("new_breeding_program_desc", "id", "find description")->send_keys('Test BP1 Desc');

    $t->find_element_ok("new_breeding_program_submit", "id", "submit new breeding program")->click();

    sleep(1);
    $t->driver->accept_alert();
    sleep(1);

    $t->get_ok('breeders/trial/135');

    sleep(10);

    $t->find_element_ok("//div[contains(., 'test (test)')]", "xpath", "verify breeding program")->get_text();
    $t->find_element_ok("//div[contains(., 'new_test_cross')]", "xpath", "verify trial name")->get_text();
    $t->find_element_ok("//div[contains(., '[type not set]')]", "xpath", "verify trial type")->get_text();
    $t->find_element_ok("//div[contains(., 'new_test_cross')]", "xpath", "verify description")->get_text();

    $t->find_element_ok("show_change_breeding_program_link", "id", "find edit breeding program")->click();
    $t->find_element_ok("breeding_program_select", "id", "edit breeding program")->send_keys('Test BP1');
    $t->find_element_ok("edit_trial_breeding_program_submit", "id", "submit edit breeding program")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'Test BP1')]", "xpath", "verify breeding program")->get_text();

    $t->find_element_ok("edit_trial_name", "id", "find edit trial name")->click();
    $t->find_element_ok("trial_name_input", "id", "edit trial name")->send_keys('New Trial Name');
    $t->find_element_ok("edit_name_save_button", "id", "submit edit trial name")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'New Trial Name')]", "xpath", "verify trial name")->get_text();

    $t->find_element_ok("edit_trial_type", "id", "find edit trial type")->click();
    $t->find_element_ok("trial_type_select", "id", "edit trial type")->send_keys('AYT');
    $t->find_element_ok("edit_type_save_button", "id", "submit edit trial type")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'AYT')]", "xpath", "verify trial type")->get_text();

    $t->find_element_ok("change_year_link", "id", "find edit year")->click();
    $t->find_element_ok("year_select", "id", "edit year")->send_keys('2014');
    $t->find_element_ok("change_trial_year_save_button", "id", "submit edit year")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., '2014')]", "xpath", "verify trial type")->get_text();

    $t->find_element_ok("change_trial_location_link", "id", "find edit location")->click();
    $t->find_element_ok("location_select", "id", "edit location")->send_keys('test_location');
    $t->find_element_ok("edit_trial_location_submit", "id", "submit edit location")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'test_location')]", "xpath", "verify trial location")->get_text();

    #$t->find_element_ok("change_planting_date_link", "id", "find edit planting date")->click();
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->click();
    #sleep(1);
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->send_keys('01/26/2016');
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->send_keys(KEYS->{'enter'});
    #sleep(1);
    #$t->find_element_ok("change_planting_date_button", "id", "submit edit date")->click();
    #sleep(1);
    #$t->driver->accept_alert();
    #sleep(1);
    #$t->find_element_ok("//div[contains(., '2016/01/26')]", "xpath", "verify date")->get_text();

    #$t->find_element_ok("change_harvest_date_link", "id", "find edit harvest date")->click();
    #$t->find_element_ok("harvest_date_picker", "id", "edit date")->click();
    #sleep(1);
    #$t->find_element_ok("harvest_date_picker", "id", "edit date")->send_keys('01/27/2016');
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->send_keys(KEYS->{'enter'});
    #sleep(1);
    #$t->find_element_ok("change_harvest_date_button", "id", "submit edit date")->click();
    #sleep(1);
    #$t->driver->accept_alert();
    #sleep(1);
    #$t->find_element_ok("//div[contains(., '2016/01/27')]", "xpath", "verify date")->get_text();

    $t->find_element_ok("edit_trial_description", "id", "find edit description")->click();
    $t->find_element_ok("trial_description_input", "id", "edit description")->send_keys('test_description');
    $t->find_element_ok("edit_description_save_button", "id", "submit edit desc")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'trial_description')]", "xpath", "verify desc")->get_text();


    }


);

done_testing();

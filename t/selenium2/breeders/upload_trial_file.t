use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

use strict;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();


$t->while_logged_in_as("submitter", sub {


    for my $extension ("xls", "xlsx") {
        $t->get_ok('/breeders/trials');
        $t->wait_for_network_idle();

        $t->click_ok("refresh_jstree_html", "name", "click on refresh_jstree_html");
        $t->wait_for_network_idle();

        sleep(2);
        $t->click_ok("upload_trial_link", "name", "click on upload_trial_link");

        # SCREEN 1 /Intro/
        $t->click_ok("next_step_upload_intro_button", "id", "click on next_step_upload_intro_button");

        # SCREEN 2 /File formatting/
        $t->click_ok("upload_single_trial_design_tab", "id", "choose a single trial design tab (default)");
        $t->click_ok('next_step_file_formatting_button', 'id', 'go to next screen - Intro');

        # SCREEN 3 /Enter trial information/
        my $trial_name = "selenium_test_upload_trial_file";
        $t->send_keys_ok("trial_upload_name", "id", $trial_name, "find trial name input");

        $t->click_ok("trial_upload_breeding_program", "id", "find breeding program select");
        $t->click_ok('//select[@id="trial_upload_breeding_program"]/option[@value="test"]', 'xpath', "Select 'test' as value for breeding program");

        $t->click_ok("trial_upload_location", "id", "find location select");
        $t->click_ok('//select[@id="trial_upload_location"]/option[@value="test_location"]', 'xpath', "Select 'test_location' as value for trial location");

        $t->click_ok("trial_upload_trial_type", "id", "find trial type select");
        $t->click_ok('//select[@id="trial_upload_trial_type"]/option[@title="phenotyping_trial"]', 'xpath', "Select 'phenotyping_trial' as value for type of trial");

        $t->click_ok("trial_upload_year", "id", "find trial year input");
        $t->click_ok('//select[@id="trial_upload_year"]/option[@value="2015"]', 'xpath', "Select '2015' as value for year");

        $t->send_keys_ok('trial_upload_plot_width', 'id', "10", "find trial plot width input");
        $t->send_keys_ok('trial_upload_plot_length', 'id', "10", "find trial plot length input");
        $t->send_keys_ok('trial_upload_field_size', 'id', "5", "find trial field size input");
        $t->send_keys_ok('trial_upload_plant_entries', 'id', "10", "find trial plants per plot input");

        $t->send_keys_ok("trial_upload_description", "id", 'Test test upload trial file - description', "find trial description input");

        $t->click_ok("trial_upload_trial_stock_type", "id", "find trial design select");
        $t->click_ok('//select[@id="trial_upload_trial_stock_type"]/option[@value="accession"]', 'xpath', "Select 'accession' as value for stock type");

        $t->click_ok("trial_upload_design_method", "id", "find trial design select");
        $t->click_ok('//select[@id="trial_upload_design_method"]/option[@value="CRD"]', 'xpath', "Select 'CRD' as value for design method");

        my $filename = $f->config->{basepath} . "/t/data/trial/trial_layout_example_other_plots.$extension";

        $t->driver()->upload_file($filename);
        $t->send_keys_ok("trial_uploaded_file", "id", $filename, "find file input");

        $t->click_ok('next_step_trial_information_button', 'id', 'go to next screen - Intro');
        # SCREEN 4 /Trial Linkage/

        $t->click_ok("upload_trial_trial_sourced", "id", "find trial sourced select");
        $t->click_ok('//select[@id="upload_trial_trial_sourced"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial sourced");

        $t->click_ok("upload_trial_trial_will_be_genotyped", "id", "find 'trial will be genotyped' select");
        $t->click_ok('//select[@id="upload_trial_trial_will_be_genotyped"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial will be genotyped");

        $t->click_ok("upload_trial_trial_will_be_crossed", "id", "find 'trial will be crossed' select");
        $t->click_ok('//select[@id="upload_trial_trial_will_be_crossed"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial will be crossed");

        $t->click_ok("upload_trial_validate_form_button", "id", "find and click trial validate form button");
        $t->wait_for_network_idle();

        $t->click_ok("upload_trial_submit_first", "name", "find and click upload trial submit button");
        $t->wait_for_working_dialog();
        $t->wait_for_network_idle();
        sleep(10); # The above 2 waits are insufficient to give the backend enough time to finish processing

        $t->click_ok("close_trial_upload_dialog", "id", "find and click close trial upload button");

        $t->get_ok('/breeders/trials');
        sleep(1); # FIXME Need to wait for click handler to be registered

        $t->click_ok("refresh_jstree_html", "name", "refresh tree");
        $t->wait_for_network_idle();

        $t->click_ok("test", "partial_link_text", "check program in tree");
        sleep(1);

        $t->click_ok("jstree-icon", "class", "view drop down for program");
        sleep(1);

        $t->click_ok("$trial_name", "partial_link_text", "check program in tree");
        sleep(1);

        $f->clean_up_db();
    }
});

$t->driver->close();
done_testing();

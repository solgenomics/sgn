
use strict;
use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    # test for both excel formats xls and xlsx
    for my $file ("crosses_plots_upload.xls", "crosses_plots_upload_selenium.xlsx") {

        $t->get_ok('/breeders/crosses');
        sleep(1); # FIXME Need to wait for button click handler to be registered

        $t->click_ok("upload_crosses_link", "name", "click on upload_crosses_link ");

        # SCREEN 1 /Intro/
        $t->click_ok('next_step_intro_button', 'id', 'go to next screen - Intro');

        # SCREEN 2 /Crossing experiment/
        # with normal find_by_name method element cannot be find - that is why that strange double xpath structure
        $t->click_ok('//div[@id="manage_page_section_1"]//button[@name="create_crossingtrial_link"]', 'xpath', 'find button to create a new experiment and click');

        # Add New Crossing Experiment Intro/ modal
        $t->click_ok('next_step_add_new_intro', 'id', 'go to next screen in Add New Experiment modal');

        # Add New Crossing Experiment Information/ modal
        my $experiment_name = "Selenium_upload_cross_trial_$file";
        $t->send_keys_ok('crossingtrial_name', 'id', $experiment_name, 'find "crossing trial name" input and give a name');

        $t->click_ok('crossingtrial_program', 'id', 'find "crossing trial program" select input and click');
        $t->click_ok('//select[@id="crossingtrial_program"]/option[text()="test"]', 'xpath', 'select "test" as value for crossing trial program');

        $t->click_ok('crossingtrial_location', 'id', 'find "crossing trial location" select input and click');
        $t->click_ok('//select[@id="crossingtrial_location"]/option[@value="test_location"]', 'xpath', 'select "test_location" as value for crossing trial location');

        $t->click_ok('crosses_add_project_year_select', 'id', 'find "crossing trial year" select input and click');
        $t->click_ok('//select[@id="crosses_add_project_year_select"]/option[@value="2018"]', 'xpath', 'select "2018" as value for crossing trial year');

        $t->send_keys_ok('crosses_add_project_description', 'id', "Selenium_upload_cross_trial_description", 'find "crossing trial description" input and give a description');

        $t->click_ok('create_crossingtrial_submit', 'id', 'find and click "crossing trial submit" input and give a description');

        # check if added successfully
        my $trial_submit_info = $t->get_attribute_ok(
            '//div[@id="add_crossing_trial_workflow"]//div[contains(@class, "workflow-complete-message")]',
            'xpath',
            'innerHTML',
            'find feedback info after trial submition');

        ok($trial_submit_info =~ /Crossing experiment was added successfully/, "Verify feedback after submission, looking for: 'Crossing experiment was added successfully'");

        $t->click_ok('add_crossing_experiment_dismiss_button_2', 'id', 'find and close "Add New Experiment" modal');

        $t->click_ok('next_step_crossing_trial_button', 'id', 'go to next screen - Crossing experiment');

        # SCREEN 3 /Upload your crosses/
        $t->click_ok('upload_crosses_breeding_program_id', 'id', 'find "crossing trial program" select input and click');
        $t->click_ok('//select[@id="upload_crosses_breeding_program_id"]/option[@title="test"]', 'xpath', 'select "test" as value for crossing experiment');

        $t->click_ok('upload_crosses_crossing_experiment_id', 'id', 'find "crossing trial program" select input and click');
        $t->click_ok("//select[\@id='upload_crosses_crossing_experiment_id']/option[\@title='$experiment_name']", 'xpath', "select '$experiment_name' as value for crossing experiment");

        # File
        my $filename = $f->config->{basepath} . "/t/data/cross/$file";
        $t->driver()->upload_file($filename);
        $t->send_keys_ok("upload_crosses_file", "id", $filename, "find file input");

        $t->click_ok('upload_crosses_submit', 'id', 'find and "submit" uploaded cross file');

        # Check if added successfully
        my $cross_submit_info = $t->get_attribute_ok(
            '//div[@id="crosses_upload_workflow"]',
            'xpath',
            'innerHTML',
            'find feedback info after trial submition');

        ok($cross_submit_info =~ /The crosses file was uploaded successfully/, "Verify feedback after cross submission, looking for: 'The crosses file was uploaded successfully'");

        $t->click_ok('upload_crosses_dismiss_button', 'name', 'find "close" modal button and click');

        $t->click_ok("refresh_crosses_jstree_html_trialtree_button", "id", "find and click 'refresh crosses trial jstree'");
        $t->wait_for_network_idle();

        $t->click_ok('//div[@id="crosses_list"]//i[contains(@class, "jstree-icon")]', 'xpath', 'open a tree with crosses trial list');
        $t->wait_for_network_idle();

        my $href_to_trial = $t->get_attribute_ok("//div[\@id='crosses_list']//a[contains(text(), '$experiment_name')]", 'xpath', 'href', 'find created cross and take link href');

        $t->get_ok($href_to_trial);
        sleep(1); # FIXME Need to wait for page to settle

        my $cross_table_content = $t->get_attribute_ok('parent_information', 'id', 'innerHTML', 'find table with parent information');

        ok($cross_table_content =~ /UG120001xUG120002/, "Verify info in the table: UG120001xUG120002");
        ok($cross_table_content =~ /KASESE_TP2013_842/, "Verify info in the table: KASESE_TP2013_842");
        ok($cross_table_content =~ /KASESE_TP2013_1591/, "Verify info in the table: KASESE_TP2013_1591");
    }
});

$t->driver()->close();
done_testing();

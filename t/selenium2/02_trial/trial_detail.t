use lib 't/lib';
use strict;

use Test::More 'tests' => 178;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("curator", sub {
    sleep(2);

    for my $file ("T100_trial_layout.xls", "T100_trial_layout_selenium_second_file.xlsx") {

        #Upload New Trial
        $t->get_ok('/breeders/trials');
        sleep(3);

        $t->find_element_ok("upload_trial_link", "name", "click on upload_trial_link ")->click();
        sleep(4);

        # SCREEN 1 /Intro/
        $t->find_element_ok("next_step_upload_intro_button", "id", "click on next_step_upload_intro_button ")->click();
        sleep(1);

        # SCREEN 2 /File formating/
        $t->find_element_ok("upload_single_trial_design_tab", "id", "choose a single trial design tab (default)");
        $t->find_element_ok('next_step_file_formatting_button', 'id', 'go to next screen - Intro')->click();
        sleep(1);

        # SCREEN 3 /Enter trial information/
        my $trial_name = "selenium_test_trial_detail_$file";
        $t->find_element_ok("trial_upload_name", "id", "find trial name input")->send_keys($trial_name);

        $t->find_element_ok("trial_upload_breeding_program", "id", "find breeding program select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="trial_upload_breeding_program"]/option[@value="test"]', 'xpath', "Select 'test' as value for breeding program")->click();

        $t->find_element_ok("trial_upload_location", "id", "find location select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="trial_upload_location"]/option[@value="test_location"]', 'xpath', "Select 'test_location' as value for trial location")->click();

        $t->find_element_ok("trial_upload_trial_type", "id", "find trial type select")->click();
        sleep(1);

        $t->find_element_ok('//select[@id="trial_upload_trial_type"]/option[@title="phenotyping_trial"]', 'xpath', "Select 'phenotyping_trial' as value for type of trial")->click();

        $t->find_element_ok("trial_upload_year", "id", "find trial year input")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="trial_upload_year"]/option[@value="2016"]', 'xpath', "Select '2016' as value for year")->click();

        $t->find_element_ok('trial_upload_plot_width', 'id', "find trial plot width input")->send_keys("10");
        $t->find_element_ok('trial_upload_plot_length', 'id', "find trial plot length input")->send_keys("10");
        $t->find_element_ok('trial_upload_field_size', 'id', "find trial field size input")->send_keys("5");
        $t->find_element_ok('trial_upload_plant_entries', 'id', "find trial plants per plot input")->send_keys("10");

        $t->find_element_ok("trial_upload_description", "id", "find trial description input")->send_keys('Test trial detail selenium - description');;

        $t->find_element_ok("trial_upload_trial_stock_type", "id", "find trial design select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="trial_upload_trial_stock_type"]/option[@value="accession"]', 'xpath', "Select 'accession' as value for stock type")->click();

        $t->find_element_ok("trial_upload_design_method", "id", "find trial design select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="trial_upload_design_method"]/option[@value="CRD"]', 'xpath', "Select 'CRD' as value for design method")->click();

        my $upload_input = $t->find_element_ok("trial_uploaded_file", "id", "find file input");
        my $filename = $f->config->{basepath} . "/t/data/trial/$file";

        $t->driver()->upload_file($filename);
        $upload_input->send_keys($filename);
        sleep(2);

        $t->find_element_ok('next_step_trial_information_button', 'id', 'go to next screen - Intro')->click();
        # SCREEN 4 /Trial Linkage/

        $t->find_element_ok("upload_trial_trial_sourced", "id", "find trial sourced select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="upload_trial_trial_sourced"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial sourced")->click();

        $t->find_element_ok("upload_trial_trial_will_be_genotyped", "id", "find 'trial will be genotyped' select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="upload_trial_trial_will_be_genotyped"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial will be genotyped")->click();

        $t->find_element_ok("upload_trial_trial_will_be_crossed", "id", "find 'trial will be crossed' select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="upload_trial_trial_will_be_crossed"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial will be crossed")->click();

        $t->find_element_ok("upload_trial_validate_form_button", "id", "find and click trial validate form button")->click();
        sleep(2);

        $t->find_element_ok("upload_trial_submit_first", "name", "find and click upload trial submit button")->click();

        # important sleep 60 seconds for a functionality - it can take ages to save a trail depend of the machine
        sleep(60);

        $t->find_element_ok("close_trial_upload_dialog", "id", "find and click close trial upload button")->click();

        # OPEN A TRIAL AFTER CREATE TO CHECK DETAILS

        $t->get_ok('/breeders/trials');
        sleep(3);

        $t->find_element_ok("refresh_jstree_html_trialtree_button", "id", "refresh tree")->click();
        sleep(5);

        $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
        sleep(3);

        $t->find_element_ok("$trial_name", "partial_link_text", "open up tree")->click();

        #New Trial ID from database
        my $trial_id = $f->bcs_schema->resultset('Project::Project')->search({ name => $trial_name }, { order_by => { -desc => 'project_id' } })->first->project_id();

        #Delete Trial Coordinates - Remove first one to upload new coordinates
        $t->get_ok('/breeders/trial/' . $trial_id);
        sleep(5);

        my $heatmap_onswitch = $t->find_element_ok("pheno_heatmap_onswitch", "id", "click to open pheno heatmap panel");
        $heatmap_onswitch->click();
        sleep(3);

        $t->find_element_ok("delete_field_map_hm_link", "id", "click on delete previous coordinate")->click();
        sleep(1);

        $t->find_element_ok("delete_field_coords_ok_button", "id", "click on delete previous coordinate - confirm")->click();
        sleep(15);

        $t->find_element_ok("dismiss_delete_field_map_dialog", "id", "click on confirmation of delete")->click();
        sleep(10);

        #Upload Trial Coordinates
        my $heatmap_onswitch = $t->find_element_ok("pheno_heatmap_onswitch", "id", "click to open pheno heatmap panel");
        $heatmap_onswitch->click();
        sleep(3);

        $t->find_element_ok("heatmap_upload_trial_coords_link", "id", "click on upload_trial_coords_link ")->click();

        my $upload_input = $t->find_element_ok("trial_coordinates_uploaded_file", "id", "find file input");

        my $filename = $f->config->{basepath} . "/t/data/trial/T100_trial_coords.csv";
        $t->driver()->upload_file($filename);
        $upload_input->send_keys($filename);
        sleep(1);

        $t->find_element_ok("upload_trial_coords_ok_button", "id", "submit upload trial coords file ")->click();
        sleep(15);

        $t->find_element_ok("trial_coord_upload_success_dialog_message_cancel", "id", "close success msg")->click();
        sleep(1);

        $t->find_element_ok("upload_trial_coords_cancel_button", "id", "close upload modal")->click();
        sleep(5);

        my $trial_details = $t->find_element_ok(
            'trial_details_content',
            'id',
            "find content of trial details")->get_attribute('innerHTML');

        ok($trial_details =~ /$trial_name/, "Verify trial name: $trial_name");
        ok($trial_details =~ /test/, "Verify breeding program");
        ok($trial_details =~ /test_location/, "Verify trial location");
        ok($trial_details =~ /2016/, "Verify trial year");
        ok($trial_details =~ /phenotyping_trial/, "Verify trial type");
        ok($trial_details =~ /[No Planting Date]/, "Verify planting date");
        ok($trial_details =~ /[No Harvest Date]/, "Verify harvest date");
        ok($trial_details =~ /Test trial detail selenium - description/, "Verify description");

        my $trial_design_onswitch = $t->find_element_ok("trial_design_section_onswitch", "id", "click to open design section");
        $trial_design_onswitch->click();
        sleep(3);

        $trial_details = $t->find_element_ok(
            'trial_controls_table',
            'id',
            "find content of trial design")->get_attribute('innerHTML');

        ok($trial_details =~ /CRD/, "Verify ");
        ok($trial_details =~ /2/, "Verify ");

        $t->find_element_ok("trial_stocks_onswitch", "id", "view trial accessions")->click();
        sleep(5);

        $trial_details = $t->find_element_ok(
            'trial_stocks_table',
            'id',
            "find content of trial accessions")->get_attribute('innerHTML');

        ok($trial_details =~ /test_accession1/, "Verify accessions");
        ok($trial_details =~ /test_accession2/, "Verify accessions");
        ok($trial_details =~ /test_accession3/, "Verify accessions");
        ok($trial_details =~ /test_accession4/, "Verify accessions");

        $t->find_element_ok("trial_controls_onswitch", "id", "view trial controls")->click();
        sleep(5);

        $trial_details = $t->find_element_ok(
            'trial_controls_content',
            'id',
            "find content of trial accessions")->get_attribute('innerHTML');

        ok($trial_details =~ /test_accession2/, "Verify controls");
        ok($trial_details =~ /test_accession3/, "Verify controls");

        $t->find_element_ok("trial_plots_onswitch", "id", "view trial plots")->click();
        sleep(5);

        $t->find_element_ok("select_all_plots_btn", "id", "select plots")->click();
        sleep(1);

        $t->find_element_ok("plot_select_new_list_name", "id", "find add list input");

        my $add_list_input = $t->find_element_ok("plot_select_new_list_name", "id", "find add list input test");

        $add_list_input->send_keys("plots_list");

        $t->find_element_ok("plot_select_add_to_new_list_btn", "id", "find add list button")->click();
        sleep(1);
        $t->accept_alert_ok();
        sleep(1);

        # Open a a newly created list and check details of list
        my $out = $t->find_element_ok("lists_link", "name", "find lists_link")->click();
        sleep(3);

        $t->find_element_ok("view_list_plots_list", "id", "view 'plots_list' for test")->click();
        sleep(2);

        $trial_details = $t->find_element_ok(
            'list_item_dialog_datatable_wrapper',
            'id',
            "find content of list to check details")->get_attribute('innerHTML');

        ok($trial_details =~ /T100_plot_01/, "Verify plots");
        ok($trial_details =~ /T100_plot_02/, "Verify plots");
        ok($trial_details =~ /T100_plot_03/, "Verify plots");
        ok($trial_details =~ /T100_plot_04/, "Verify plots");
        ok($trial_details =~ /T100_plot_05/, "Verify plots");
        ok($trial_details =~ /T100_plot_06/, "Verify plots");
        ok($trial_details =~ /T100_plot_07/, "Verify plots");
        ok($trial_details =~ /T100_plot_08/, "Verify plots");
    }
});

$t->driver->close();
done_testing();

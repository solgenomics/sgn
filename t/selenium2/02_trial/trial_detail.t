use lib 't/lib';
use strict;

use Test::More 'tests' => 183;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("curator", sub {

    for my $file ("T100_trial_layout.xls", "T100_trial_layout_selenium_second_file.xlsx") {

        #Upload New Trial
        $t->get_ok('/breeders/trials');
        $t->click_ok("upload_trial_link", "name", "click on upload_trial_link");

        # SCREEN 1 /Intro/
        $t->click_ok("next_step_upload_intro_button", "id", "click on next_step_upload_intro_button");

        # SCREEN 2 /File formating/
        $t->click_ok("upload_single_trial_design_tab", "id", "choose a single trial design tab (default)");
        $t->click_ok('next_step_file_formatting_button', 'id', 'go to next screen - Intro');

        # SCREEN 3 /Enter trial information/
        my $trial_name = "selenium_test_trial_detail_$file";
        $t->send_keys_ok("trial_upload_name", "id", $trial_name, "find trial name input");
        $t->click_ok("trial_upload_breeding_program", "id", "find breeding program select");
        $t->click_ok('//select[@id="trial_upload_breeding_program"]/option[@value="test"]', 'xpath', "Select 'test' as value for breeding program");

        $t->click_ok("trial_upload_location", "id", "find location select");
        $t->click_ok('//select[@id="trial_upload_location"]/option[@value="test_location"]', 'xpath', "Select 'test_location' as value for trial location");

        $t->click_ok("trial_upload_trial_type", "id", "find trial type select");

        $t->click_ok('//select[@id="trial_upload_trial_type"]/option[@title="phenotyping_trial"]', 'xpath', "Select 'phenotyping_trial' as value for type of trial");

        $t->click_ok("trial_upload_year", "id", "find trial year input");
        $t->click_ok('//select[@id="trial_upload_year"]/option[@value="2016"]', 'xpath', "Select '2016' as value for year");

        $t->send_keys_ok('trial_upload_plot_width', 'id', "10", "find trial plot width input");
        $t->send_keys_ok('trial_upload_plot_length', 'id', "10", "find trial plot length input");
        $t->send_keys_ok('trial_upload_field_size', 'id', "5", "find trial field size input");
        $t->send_keys_ok('trial_upload_plant_entries', 'id', "10", "find trial plants per plot input");

        $t->send_keys_ok("trial_upload_description", "id", 'Test trial detail selenium - description', "find trial description input");

        $t->click_ok("trial_upload_trial_stock_type", "id", "find trial design select");
        $t->click_ok('//select[@id="trial_upload_trial_stock_type"]/option[@value="accession"]', 'xpath', "Select 'accession' as value for stock type");

        $t->click_ok("trial_upload_design_method", "id", "find trial design select");
        $t->click_ok('//select[@id="trial_upload_design_method"]/option[@value="CRD"]', 'xpath', "Select 'CRD' as value for design method");

        my $upload_input = $t->find_element_ok("trial_uploaded_file", "id", "find file input");
        my $filename = $f->config->{basepath} . "/t/data/trial/$file";

        $t->driver()->upload_file($filename);
        $upload_input->send_keys($filename);

        $t->click_ok('next_step_trial_information_button', 'id', 'go to next screen - Intro');
        # SCREEN 4 /Trial Linkage/

        $t->click_ok("upload_trial_trial_sourced", "id", "find trial sourced select");
        $t->click_ok('//select[@id="upload_trial_trial_sourced"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial sourced");

        $t->click_ok("upload_trial_trial_will_be_genotyped", "id", "find 'trial will be genotyped' select");
        $t->click_ok('//select[@id="upload_trial_trial_will_be_genotyped"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial will be genotyped");

        $t->click_ok("upload_trial_trial_will_be_crossed", "id", "find 'trial will be crossed' select");
        $t->click_ok('//select[@id="upload_trial_trial_will_be_crossed"]/option[@value="no"]', 'xpath', "Select 'no' as value for trial will be crossed");

        $t->click_ok("upload_trial_validate_form_button", "id", "find and click trial validate form button");

        $t->click_ok("upload_trial_submit_first", "name", "find and click upload trial submit button");

        # important sleep 60 seconds for a functionality - it can take ages to save a trail depend of the machine
        $t->wait_for_working_dialog();
        $t->wait_for_network_idle();

        $t->click_ok("close_trial_upload_dialog", "id", "find and click close trial upload button");

        # OPEN A TRIAL AFTER CREATE TO CHECK DETAILS

        $t->get_ok('/breeders/trials');

        $t->click_ok("refresh_jstree_html_trialtree_button", "id", "refresh tree");
        $t->wait_for_network_idle();

        $t->click_ok("jstree-icon", "class", "open up tree");
        $t->wait_for_network_idle();

        $t->click_ok("$trial_name", "partial_link_text", "click trial in tree");

        #New Trial ID from database
        my $trial_id = $f->bcs_schema->resultset('Project::Project')->search({ name => $trial_name }, { order_by => { -desc => 'project_id' } })->first->project_id();

        #Delete Trial Coordinates - Remove first one to upload new coordinates
        $t->get_ok('/breeders/trial/' . $trial_id);

        $t->wait_for_network_idle();
        $t->click_ok("pheno_heatmap_onswitch", "id", "click to open pheno heatmap panel");
        $t->wait_for_working_dialog();

        $t->click_ok("delete_field_map_hm_link", "id", "click on delete previous coordinate");
        $t->accept_alert_ok("click on delete previous coordinate - confirm");
        $t->accept_alert_ok("click on confirmation of delete");

        #Upload Trial Coordinates
        if ($file eq "T100_trial_layout.xls") { #the coords upload file only works on the first trial, no need to test that feature again
            $t->wait_for_network_idle();
            $t->click_ok("pheno_heatmap_onswitch", "id", "click to open pheno heatmap panel");
            $t->wait_for_working_dialog();

            $t->click_ok("heatmap_upload_trial_coords_link", "id", "click on upload_trial_coords_link ");

            my $upload_input = $t->find_element_ok("trial_coordinates_uploaded_file", "id", "find file input");

            my $filename = $f->config->{basepath} . "/t/data/trial/T100_trial_coords.tsv";
            $t->driver()->upload_file($filename);
            $upload_input->send_keys($filename);

            $t->click_ok("upload_trial_coords_ok_button", "id", "submit upload trial coords file ");

            $t->click_ok("trial_coord_upload_success_dialog_message_cancel", "id", "close success msg");
        }
        $t->wait_for_network_idle();

        my $trial_details = $t->get_attribute_ok(
            'trial_details_content',
            'id',
            'innerHTML',
            "find content of trial details");

        ok($trial_details =~ /$trial_name/, "Verify trial name: $trial_name");
        ok($trial_details =~ /test/, "Verify breeding program");
        ok($trial_details =~ /test_location/, "Verify trial location");
        ok($trial_details =~ /2016/, "Verify trial year");
        ok($trial_details =~ /phenotyping_trial/, "Verify trial type");
        ok($trial_details =~ /[No Planting Date]/, "Verify planting date");
        ok($trial_details =~ /[No Harvest Date]/, "Verify harvest date");
        ok($trial_details =~ /Test trial detail selenium - description/, "Verify description");

        # edit trial details
        sleep(5); # Waiting for network idle is not enough to ensure button is clickable
        $t->click_ok("edit_trial_details", "id", "open trial details");
        $t->click_ok('//select[@id="edit_trial_year_0"]/option[@value="2015"]', 'xpath', "Select '2015' as value for year 0");
        $t->click_ok("save_trial_details", "id", "save trial details");
        $t->click_ok("trial_details_saved_close_button", "id", "close trial details");
        $t->wait_for_network_idle();

        my $trial_year = $t->get_attribute_ok("trial_year", "id", "innerHTML", "locate trial year");
        ok($trial_year =~ /2016 | Year 0: 2015/, "Verify year 0");

        $t->click_ok("trial_design_section_onswitch", "id", "click to open design section");
        $t->wait_for_network_idle();

        $trial_details = $t->get_attribute_ok(
            'trial_controls_table',
            'id',
            'innerHTML',
            "find content of trial design");

        ok($trial_details =~ /CRD/, "Verify ");
        ok($trial_details =~ /2/, "Verify ");

        $t->click_ok("trial_stocks_onswitch", "id", "view trial accessions");
        $t->wait_for_network_idle();

        $trial_details = $t->get_attribute_ok(
            'trial_stocks_table',
            'id',
            'innerHTML',
            "find content of trial accessions");

        ok($trial_details =~ /test_accession1/, "Verify accessions");
        ok($trial_details =~ /test_accession2/, "Verify accessions");
        ok($trial_details =~ /test_accession3/, "Verify accessions");
        ok($trial_details =~ /test_accession4/, "Verify accessions");

        $t->click_ok("trial_controls_onswitch", "id", "view trial controls");
        $t->wait_for_network_idle();

        $trial_details = $t->get_attribute_ok(
            'trial_controls_content',
            'id',
            'innerHTML',
            "find content of trial accessions");

        ok($trial_details =~ /test_accession2/, "Verify controls");
        ok($trial_details =~ /test_accession3/, "Verify controls");

        $t->click_ok("trial_plots_onswitch", "id", "view trial plots");
        $t->wait_for_network_idle();

        $t->click_ok("select_all_plots_btn", "id", "select plots");

        $t->find_element_ok("plot_select_new_list_name", "id", "find add list input");

        $t->send_keys_ok("plot_select_new_list_name", "id", "plots_list", "find add list input test");
        sleep(1);

        $t->click_ok("plot_select_add_to_new_list_btn", "id", "find add list button");
        $t->accept_alert_ok("accept add list alert");

        # Open a a newly created list and check details of list
        $t->wait_for_network_idle();
        $t->click_ok("lists_link", "name", "find lists_link");
        $t->click_ok("view_list_plots_list", "id", "view 'plots_list' for test");

        $t->wait_for_working_dialog();

        $trial_details = $t->get_attribute_ok(
            'list_item_dialog_datatable_wrapper',
            'id',
            'innerHTML',
            "find content of list to check details");

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

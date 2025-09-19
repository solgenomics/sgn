use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

use strict;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {

    for my $extension ("xls", "xlsx") {
        sleep(1);

        $t->get_ok('/breeders/trials');
        sleep(4);

        $t->find_element_ok("refresh_jstree_html", "name", "click on upload_trial_link ")->click();
        sleep(5);

        $t->find_element_ok("upload_trial_link", "name", "click on upload_trial_link ")->click();
        sleep(2);

        # SCREEN 1 /Intro/
        $t->find_element_ok('next_step_upload_intro_button', 'id', 'go to next screen - Intro')->click();
        sleep(1);

        # SCREEN 2 /File formating/
        $t->find_element_ok("upload_single_trial_design_tab", "id", "choose a single trial design tab (default)")->click();
        sleep(1);
        $t->find_element_ok('next_step_file_formatting_button', 'id', 'go to next screen - Intro')->click();
        sleep(1);

        # SCREEN 3 /Enter trial information/
        my $trial_name = $t->find_element_ok("trial_upload_name", "id", "find trial name input");
        $trial_name->send_keys('test_trial_upload');

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

        my $trial_description = $t->find_element_ok("trial_upload_description", "id", "find trial description input");
        $trial_description->send_keys('Test derived traits trial test description');

        $t->find_element_ok("trial_upload_trial_stock_type", "id", "find trial design select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="trial_upload_trial_stock_type"]/option[@value="accession"]', 'xpath', "Select 'accession' as value for stock type")->click();

        $t->find_element_ok("trial_upload_design_method", "id", "find trial design select")->click();
        sleep(1);
        $t->find_element_ok('//select[@id="trial_upload_design_method"]/option[@value="CRD"]', 'xpath', "Select 'CRD' as value for design method")->click();

        my $upload_input = $t->find_element_ok("trial_uploaded_file", "id", "find file input");
        my $filename = $f->config->{basepath} . "/t/data/trial/trial_layout_example.$extension";

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

        $f->clean_up_db();
    }

    # SCREEN 5 /Fix missing accessions problem/
    # maybe in a future - not connected with basic functionality - but worth to think about it in test coverage
    # SCREEN 6 /Fix missing seedlots problem/
    # maybe in a future - not connected with basic functionality - but worth to think about it in test coverage
    # SCREEN 7 /Try submitting trial again/
    # maybe in a future - not connected with basic functionality - but worth to think about it in test coverage


    # FROM HERE TEST MAKES NO SENSE ANYMORE. DERIVED FUNCTIONALITY DOES NOT SEEMS TO WORK.
    # PROBABLY WE SHOULD WRITE THE REST OF THE TEST ONCE A FUNCTIONALITY IS SET UP WITH THE CORRECT UPLOAD FILE FOR THE
    # TEST UPLOAD TRAIL.


    # $t->get_ok('/breeders/phenotyping');
	#
    # sleep(2);
    #
    # $t->find_element_ok("upload_spreadsheet_phenotypes_link", "id", "submit upload phenotype file ")->click();
    # sleep(2);
    #
    # $t->find_element_ok("upload_spreadsheet_phenotype_file_format", "id", "find spreadsheet file format select")->click();
    # sleep(1);
    # $t->find_element_ok('//select[@id="upload_spreadsheet_phenotype_file_format"]/option[@value="simple"]', 'xpath', "Select 'simple' as file format")->click();
    #
    # my $upload_input = $t->find_element_ok("upload_spreadsheet_phenotype_file_input", "id", "find file input");
    # my $filename = $f->config->{basepath}."/t/data/trial/trial_phenotype_upload_file_simple.xls";
    # $t->driver()->upload_file($filename);
    # $upload_input->send_keys($filename);
    # sleep(1);
    #
    # $t->find_element_ok("upload_spreadsheet_phenotype_submit_verify", "id", "submit upload trial file ")->click();
    # sleep(3);
    #
    # $t->find_element_ok("upload_spreadsheet_phenotype_submit_store", "id", "submit upload trial file ")->click();
    # sleep(10);
    #
    # $t->get_ok('/breeders/trials');
    # sleep(2);
    #
    # $t->find_element_ok("refresh_jstree_html", "name", "click on upload_trial_link ")->click();
    # sleep(10);
    #
    # $t->find_element_ok("test", "partial_link_text", "check program in tree")->click();
    #
    # $t->find_element_ok("jstree-icon", "class", "view drop down for program")->click();
    # sleep(3);
    #
    # $t->find_element_ok("test_trial_upload", "partial_link_text", "check program in tree")->click();
    # sleep(1);
    #
    # $t->get_ok('/breeders/trial/145'); # ???
    # sleep(3);
    #
    # $t->find_element_ok("compute_derived_traits_onswitch", "id", "click on compute trait link ")->click();
    # sleep(1);
    #
    # $t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();
    # sleep(3);
    #
    # my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");
    #
    # $trait_select->send_keys('sprouting|CO_334:0000008');

   # $t->find_element_ok("button", "id", "submit compute trait ")->click();

   # sleep(1);

    # $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();
    #
    # sleep(5);

   # $t->find_element_ok("derived_trait_saved_dialog_message", "id", "ok compute trait saved dialog")->click();

    #sleep(1);

   #  $t->driver->accept_alert();
   #
   #  sleep(1);
   #
   #  $t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();
   #
   #  sleep(3);
   #
   #  my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");
   #
   #  $trait_select->send_keys('specific gravity|CO_334:0000163');
   #
   #
   #  $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();
   #
   #  sleep(5);
   #
   #  $t->driver->accept_alert();
   #
   #  sleep(1);
   #
   #   $t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();
   #
   #  sleep(3);
   #
   #  my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");
   #
   #  $trait_select->send_keys('starch content|CO_334:0000071');
   #
   #  $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();
   #
   #  sleep(5);
   #
   #  $t->driver->accept_alert();
   #
   #  sleep(1);
   #
   #   $t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();
   #
   #  sleep(3);
   #
   #  my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");
   #
   #  $trait_select->send_keys('dry matter content by specific gravity method|CO_334:0000160');
   #
   #  $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();
   #  sleep(5);
   #
   #  $t->driver->accept_alert();
   #  sleep(1);
   #
   #  #$t->get_ok('/breeders/trial/145');
   #
   # # sleep(3);
   #
   #  $t->find_element_ok("trial_detail_traits_assayed_onswitch", "id", "view uploaded traits ")->click();
   #  sleep(5);
   #
   }
);

$t->driver->close();
done_testing();

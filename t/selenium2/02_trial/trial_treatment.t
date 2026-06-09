
use strict;
use lib 't/lib';
use Test::More 'tests' => 27;
use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;
use Selenium::Waiter;
use Selenium::Firefox::Profile;
use File::Compare;

# Create firefox profile for download options
my $profile = Selenium::Firefox::Profile->new;
$profile->set_preference( 'browser.download.folderList', 2 ); # Use custom download folder
$profile->set_preference( 'browser.download.dir', '/downloads' ); # Path to custom download folder on selenium host
$profile->set_preference( 'browser.helperApps.neverAsk.saveToDisk', 'application/csv' ); # Automatically download to disk

# Create web driver
my $driver = Selenium::Remote::Driver->new(firefox_profile => $profile, base_url => $ENV{SGN_TEST_SERVER}, remote_server_addr => $ENV{SGN_REMOTE_SERVER_ADDR} || 'localhost');
my $w = SGN::Test::WWW::WebDriver->new();
$w->driver($driver);

# Set up the DB connection
my $f = SGN::Test::Fixture->new();

$w->while_logged_in_as("curator", sub {
    sleep(2);

    # -------------------------------------------------------------------------
    # Create new treatment

    $w->get_ok('/treatments/design', 'open treatment design');
    $w->find_element_ok('new_treatment_name', 'id', 'wait for page to load');
    $w->send_keys_ok('new_treatment_name', 'id', 'Water', 'enter treatment name');
    $w->send_keys_ok('new_treatment_definition', 'id', 'Apply water to a plot 0=no 1=yes', 'enter treatment definition');
    $w->click_ok('//select[@id="new_treatment_format_select"]/option[@value="boolean"]', 'xpath', 'select "boolean" as value for treatment format');
    $w->click_ok('new_treatment_submit_btn', 'id', 'submit new treatment');
    $w->accept_alert_ok('accept new treatment saved');

    # -------------------------------------------------------------------------
    # Open the trial page
    my $trial_id = $f->bcs_schema->resultset('Project::Project')->search({ name => 'test_trial' }, { order_by => { -desc => 'project_id' } })->first->project_id();
    $w->get_ok('/breeders/trial/' . $trial_id, 'open trial page');

    # -------------------------------------------------------------------------
    # Upload treatment

    # Open experimental design section
    $w->click_ok('trial_design_section_onswitch', 'id', 'open experiment design section');
    sleep(2);

    # Open treatments section
    $w->click_ok('trial_treatments_onswitch', 'id', 'open treatments section');
    sleep(2);
    $w->click_ok('trial_detail_page_add_treatment', 'id', 'click add treatments');

    # Upload treatments excel
    my $filename = $f->config->{basepath} . "/t/data/trial/download_layout_treatments.xlsx";
    $w->click_ok('//select[@id="upload_spreadsheet_treatment_file_format"]/option[@value="simple"]', 'xpath',  "select 'simple' as value for spreadsheet format");
    $w->driver()->upload_file($filename);
    $w->send_keys_ok("upload_spreadsheet_treatment_file_input", "id", $filename, 'input filename');
    $w->click_ok('upload_spreadsheet_treatment_submit_verify', 'id', 'click verify treatments');
    $w->click_ok('upload_spreadsheet_treatment_submit_store', 'id', 'click store treatments');
    $w->wait_for_working_dialog();
    $w->click_ok('upload_spreadsheet_treatment_close', 'id', 'close treatments dialog');

    # -------------------------------------------------------------------------
    # Upload trait

    # Open data files section
    $w->click_ok('trial_upload_files_onswitch', 'id', 'open upload files section');
    sleep(2);
    $w->click_ok('upload_spreadsheet_phenotypes_link', 'id', 'click upload phenotypes');

    # Upload traits excel
    my $filename = $f->config->{basepath} . "/t/data/trial/download_layout_traits.xlsx";
    $w->click_ok('//select[@id="upload_spreadsheet_phenotype_file_format"]/option[@value="simple"]', 'xpath',  "select 'simple' as value for spreadsheet format");
    $w->driver()->upload_file($filename);
    $w->send_keys_ok("upload_spreadsheet_phenotype_file_input", "id", $filename, 'input filename');
    $w->click_ok('upload_spreadsheet_phenotype_submit_verify', 'id', 'click verify phenotypes]');
    $w->click_ok('upload_spreadsheet_phenotype_submit_store', 'id', 'click store phenotypes');
    $w->wait_for_working_dialog();
    $w->click_ok('upload_spreadsheet_phenotype_close', 'id', 'close phenotypes dialog');

    # -------------------------------------------------------------------------
    # Download Layout, Phenotypes, and Treatments

    $w->click_ok('trial_download_layout_button', 'id', 'open download layout menu');
    $w->click_ok('//div[@data-toggle][input/@id = "create_fieldbook_include_measured_TrialLayout"]', 'xpath', 'enable phenotypes download');
    $w->click_ok('create_fieldbook_ok_button_TrialLayout', 'id', 'click submit button');

    sleep(2);
    # Compare observed download to expected output.
    # Reminder: the path /downloads on the selenium host is mapped to /selenium/downloads on the breedbase host
    my $result = compare("/home/production/cxgn/sgn/t/data/trial/download_layout_expected.csv", "/selenium/downloads/test_trial_layout.csv");
    ok($result == 0, "observed trial layout matches expected");

});

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

# Cleanup tests and driver
$w->driver->close();
done_testing();

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
$profile->set_preference( 'browser.download.dir', '/home/production/cxgn/sgn/t/data/tmp' ); # Path to custom download folder
$profile->set_preference( 'browser.helperApps.neverAsk.saveToDisk', 'application/csv' ); # Automatically download to disk

# Create web driver
my $driver = Selenium::Remote::Driver->new(firefox_profile => $profile, base_url => $ENV{SGN_TEST_SERVER}, remote_server_addr => $ENV{SGN_REMOTE_SERVER_ADDR} || 'localhost');
my $w = SGN::Test::WWW::WebDriver->new();
$w->driver($driver);

# Set up the DB connection
my $f = SGN::Test::Fixture->new();

# Lightweight wrapper around Selenium::Waiter::wait_until
sub wait_for {
    my $assert = shift;
    return wait_until { $assert->() } timeout => 10, interval => 1;
}

$w->while_logged_in_as("curator", sub {
    sleep(2);

    # -------------------------------------------------------------------------
    # Create new treatment

    ok( wait_for sub { $w->get('/treatments/design') }, 'open treatment design');
    ok( wait_for sub { $w->find_element('new_treatment_name', 'id')->click() }, 'wait for page to load');
    ok( wait_for sub { $w->find_element('new_treatment_name', 'id')->send_keys('Water') }, 'enter treatment name');
    ok( wait_for sub { $w->find_element('new_treatment_definition', 'id')->send_keys('Apply water to a plot 0=no 1=yes') }, 'enter treatment definition');
    ok( wait_for sub { $w->find_element('//select[@id="new_treatment_format_select"]/option[@value="boolean"]', 'xpath')->click() },  "select 'boolean' as value for treatment format");
    ok( wait_for sub { $w->find_element('new_treatment_submit_btn', 'id')->click() }, 'submit new treatment');
    ok( wait_for sub { $w->accept_alert }, 'accept new treatment saved');

    # -------------------------------------------------------------------------
    # Open the trial page
    my $trial_id = $f->bcs_schema->resultset('Project::Project')->search({ name => 'test_trial' }, { order_by => { -desc => 'project_id' } })->first->project_id();
    ok( wait_for sub { $w->get('/breeders/trial/' . $trial_id) }, 'open trial page');

    # -------------------------------------------------------------------------
    # Upload treatment

    # Open experimental design section
    ok( wait_for sub { $w->find_element('trial_design_section_onswitch', 'id')->click() }, 'open experiment design section');
    sleep(2);

    # Open treatments section
    ok( wait_for sub { $w->find_element('trial_treatments_onswitch', 'id')->click() }, 'open treatments section');
    sleep(2);
    ok( wait_for sub { $w->find_element('trial_detail_page_add_treatment', 'id')->click() }, 'click add treatments');

    # Upload treatments excel
    my $filename = $f->config->{basepath} . "/t/data/trial/download_layout_treatments.xlsx";
    ok( wait_for sub { $w->find_element('//select[@id="upload_spreadsheet_treatment_file_format"]/option[@value="simple"]', 'xpath')->click() },  "select 'simple' as value for spreadsheet format");
    my $upload_input = $w->find_element_ok("upload_spreadsheet_treatment_file_input", "id", 'find file input');
    $w->driver()->upload_file($filename);
    $upload_input->send_keys($filename);
    ok( wait_for sub { $w->find_element('upload_spreadsheet_treatment_submit_verify', 'id')->click() }, 'click verify treatments');
    ok( wait_for sub { $w->find_element('upload_spreadsheet_treatment_submit_store', 'id')->click() }, 'click store treatments');
    $w->wait_for_working_dialog();
    ok( wait_for sub { $w->find_element('upload_spreadsheet_treatment_close', 'id')->click() }, 'close treatments dialog');

    # -------------------------------------------------------------------------
    # Upload trait

    # Open data files section
    ok( wait_for sub { $w->find_element('trial_upload_files_onswitch', 'id')->click() }, 'open upload files section');
    sleep(2);
    ok( wait_for sub { $w->find_element('upload_spreadsheet_phenotypes_link', 'id')->click() }, 'click upload phenotypes');

    # Upload traits excel
    my $filename = $f->config->{basepath} . "/t/data/trial/download_layout_traits.xlsx";
    ok( wait_for sub { $w->find_element('//select[@id="upload_spreadsheet_phenotype_file_format"]/option[@value="simple"]', 'xpath')->click() },  "select 'simple' as value for spreadsheet format");
    my $upload_input = $w->find_element_ok("upload_spreadsheet_phenotype_file_input", "id", 'find file input');
    $w->driver()->upload_file($filename);
    $upload_input->send_keys($filename);
    ok( wait_for sub { $w->find_element('upload_spreadsheet_phenotype_submit_verify', 'id')->click() }, 'click verify phenotypes]');
    ok( wait_for sub { $w->find_element('upload_spreadsheet_phenotype_submit_store', 'id')->click() }, 'click store phenotypes');
    $w->wait_for_working_dialog();
    ok( wait_for sub { $w->find_element('upload_spreadsheet_phenotype_close', 'id')->click() }, 'close phenotypes dialog');

    # -------------------------------------------------------------------------
    # Download Layout, Phenotypes, and Treatments

    ok( wait_for sub { $w->find_element('trial_download_layout_button', 'id')->click() }, 'open download layout menu');
    ok( wait_for sub { $w->find_element('//div[@data-toggle][input/@id = "create_fieldbook_include_measured_TrialLayout"]', 'xpath')->click()}, , 'enable phenotypes download');
    ok( wait_for sub { $w->find_element('create_fieldbook_ok_button_TrialLayout', 'id')->click() }, 'click submit button');

    sleep(2);
    my $result = compare("/home/production/cxgn/sgn/t/data/trial/download_layout_expected.csv", "/home/production/cxgn/sgn/t/data/tmp/test_trial_layout.csv");
    ok($result == 0, "observed trial layout matches expected");
});

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

# Cleanup tests and driver
$w->driver->close();
done_testing();
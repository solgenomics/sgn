use lib 't/lib';
use strict;
use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Firefox::Profile;
use Text::CSV;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

# Setup Firefox profile for automatic downloads
# The path /downloads on the selenium host is shared with the host and typically 
# mapped to /selenium/downloads on the breedbase (web) host.
my $profile = Selenium::Firefox::Profile->new;
$profile->set_preference( 'browser.download.folderList', 2 );
$profile->set_preference( 'browser.download.dir', '/downloads' );
$profile->set_preference( 'browser.helperApps.neverAsk.saveToDisk', 'application/csv' );

my $driver = Selenium::Remote::Driver->new(
    firefox_profile => $profile,
    base_url => $ENV{SGN_TEST_SERVER},
    remote_server_addr => $ENV{SGN_REMOTE_SERVER_ADDR} || 'localhost'
);
$t->driver($driver);

$t->while_logged_in_as("curator", sub {
    my $schema = $f->bcs_schema;
    
    # Create test stocks with explicit parent relationships
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $female_parent_rel_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_rel_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $organism = $schema->resultset("Organism::Organism")->first();

    # Use random suffixes to avoid name collisions in local development environments
    my $suffix = int(rand(1000));
    my $female_name = "FemaleParentTest" . $suffix;
    my $male_name = "MaleParentTest" . $suffix;
    my $progeny_name = "ProgenyTest" . $suffix;

    my $female = $schema->resultset("Stock::Stock")->create({
        uniquename => $female_name,
        name => $female_name,
        type_id => $accession_type_id,
        organism_id => $organism->organism_id,
    });
    my $male = $schema->resultset("Stock::Stock")->create({
        uniquename => $male_name,
        name => $male_name,
        type_id => $accession_type_id,
        organism_id => $organism->organism_id,
    });
    my $progeny = $schema->resultset("Stock::Stock")->create({
        uniquename => $progeny_name,
        name => $progeny_name,
        type_id => $accession_type_id,
        organism_id => $organism->organism_id,
    });

    $schema->resultset("Stock::StockRelationship")->create({
        subject_id => $female->stock_id,
        object_id => $progeny->stock_id,
        type_id => $female_parent_rel_id,
    });
    $schema->resultset("Stock::StockRelationship")->create({
        subject_id => $male->stock_id,
        object_id => $progeny->stock_id,
        type_id => $male_parent_rel_id,
    });

    # Upload a trial using the progeny
    my $trial_csv_content = "plot_name,accession_name,plot_number,block_number,is_a_control,rep_number,range_number,row_number,col_number\n";
    $trial_csv_content .= "DownloadParentsPlot1,$progeny_name,1,1,0,1,1,1,1\n";

    my $trial_csv_path = "/tmp/trial_parents_test_$suffix.csv";
    open(my $fh_csv, '>', $trial_csv_path) or die $!;
    print $fh_csv $trial_csv_content;
    close($fh_csv);

    $t->get_ok('/breeders/trials', "Navigate to trials management page");
    $t->click_ok("upload_trial_link", "name", "Open upload trial dialog");
    $t->click_ok('next_step_upload_intro_button', 'id', "Click next on upload intro");
    $t->click_ok('//li[@id="upload_single_trial_design_tab"]/a', 'xpath', "Select single trial design tab");
    $t->click_ok('next_step_file_formatting_button', 'id', "Click next on file formatting");

    my $trial_name = "DownloadParentsTestTrial" . $suffix;
    $t->wait_for_network_idle();

    $t->send_keys_ok("trial_upload_name", "id", $trial_name, "Enter trial name");
    $t->click_ok('//select[@id="trial_upload_breeding_program"]/option[@value="test"]', 'xpath', "Select breeding program");
    $t->click_ok('//select[@id="trial_upload_location"]/option[@value="test_location"]', 'xpath', "Select location");
    $t->click_ok('//select[@id="trial_upload_trial_type"]/option[@title="phenotyping_trial"]', 'xpath', "Select trial type");
    $t->click_ok('//select[@id="trial_upload_year"]/option[@value="2024"]', 'xpath', "Select trial year");
    $t->send_keys_ok("trial_upload_description", "id", 'Test layout download with parents', "Enter description");
    $t->click_ok('//select[@id="trial_upload_design_method"]/option[@value="CRD"]', 'xpath', "Select design method");
    $t->click_ok('//select[@id="trial_upload_trial_stock_type"]/option[@value="accession"]', 'xpath', "Select stock type");

    my $remote_path = $t->driver()->upload_file($trial_csv_path);
    $t->send_keys_ok("trial_uploaded_file", "id", $remote_path, "Provide trial layout file");

    $t->click_ok('next_step_trial_information_button', 'id', "Click next on trial info");
    $t->click_ok("upload_trial_validate_form_button", "id", "Click validate upload form");
    $t->wait_for_network_idle();
    $t->click_ok("upload_trial_submit_first", "name", "Click submit trial upload");
    $t->wait_for_working_dialog();
    $t->click_ok("close_trial_upload_dialog", "id", "Close upload success dialog");

    # Navigate to trial page and perform layout download with parent columns
    sleep(1);
    my $project = $schema->resultset('Project::Project')->search({ name => $trial_name })->first();
    ok($project, "Check if trial '$trial_name' was created in the database");
    my $trial_id = $project->project_id();
    $t->get_ok('/breeders/trial/' . $trial_id, "Navigate to new trial detail page");
    $t->wait_for_network_idle();

    # Expand the Experimental Design section to make the download button visible and clickable
    $t->click_ok('trial_design_section_onswitch', 'id', "Expand experimental design section");
    $t->wait_for_network_idle();

    $t->click_ok('trial_download_layout_button', 'id', "Open download layout dialog");

    # Select the new parent columns in the checkbox grid
    $t->click_ok('//input[@data-column="female_parent"]', 'xpath', "Select female parent column");
    $t->click_ok('//input[@data-column="male_parent"]', 'xpath', "Select male parent column");
    $t->click_ok('create_fieldbook_ok_button_TrialLayout', 'id', "Submit layout download request");
    sleep(5); # Wait for browser to process the download

    # Verify downloaded content
    my $download_path = "/selenium/downloads/${trial_name}_layout.csv";
    ok(-e $download_path, "Verify downloaded layout file exists on disk");

    my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
    open my $fh, "<:encoding(utf8)", $download_path or die "Could not open $download_path: $!";
    my $header = $csv->getline($fh);
    my %col_map = map { $header->[$_] => $_ } 0..$#$header;

    ok(exists $col_map{female_parent}, "Verify header contains female_parent column");
    ok(exists $col_map{male_parent}, "Verify header contains male_parent column");

    my $row = $csv->getline($fh);
    is($row->[$col_map{accession_name}], $progeny_name, "Verify accession name in downloaded row");
    is($row->[$col_map{female_parent}], $female_name, "Verify female parent name in downloaded row");
    is($row->[$col_map{male_parent}], $male_name, "Verify male parent name in downloaded row");

    close $fh;
    unlink $trial_csv_path;
});

$t->driver->close();
$f->clean_up_db();
done_testing();

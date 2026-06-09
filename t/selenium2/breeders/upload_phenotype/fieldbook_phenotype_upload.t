use strict;
use warnings;
use lib 't/lib';
use Test::More 'tests' => 57;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Waiter qw(wait_until);

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/trial/137');

    $t->wait_for_working_dialog();

    $t->click_ok("trial_upload_files_onswitch", "id", "click on upload_fieldbook_link");
    $t->click_ok("upload_fieldbook_phenotypes_link", "id", "click on upload_fieldbook_link ");

    my $upload_input = $t->find_element_ok("upload_fieldbook_phenotype_file_input", "id", "find file input");

    # Change from fieldbook_phenotype_file.csv to fieldbook_phenotype_file_no_fieldbook_image.csv
    # For some reasons, fieldbook_image traits are returned as invalid. Don't know why there is no
    # list of valid traits in the documentation or changes in the valid list.
    # In fieldbook_phenotype_file_no_fieldbook_image two last rows with fieldbook_image traits were removed

    $t->click_ok("upload_fieldbook_phenotype_data_level", "id", "find fieldbook phenotype data level select");
    $t->click_ok('//select[@id="upload_fieldbook_phenotype_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of phenotype data level");

    my $filename = $f->config->{basepath}."/t/data/fieldbook/fieldbook_phenotype_file_no_fieldbook_image.csv";
    $t->driver()->upload_file($filename);
    $upload_input->send_keys($filename);

    $t->click_ok("upload_fieldbook_phenotype_submit_verify", "id", "submit spreadsheet file for verification");
    $t->wait_for_working_dialog();

    my $verify_status = $t->find_element_ok(
        "upload_phenotype_fieldbook_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    ok($verify_status =~ /File fieldbook_phenotype_file_no_fieldbook_image.csv saved in archive./, "Verify the positive validation");
    ok($verify_status =~ /File valid: fieldbook_phenotype_file_no_fieldbook_image.csv./, "Verify the positive validation");
    ok($verify_status =~ /File data successfully parsed./, "Verify the positive validation");
    ok($verify_status =~ /File data verified. Plot names and trait names are valid./, "Verify the positive validation");

    $t->click_ok("upload_fieldbook_phenotype_submit_store", "id", "submit spreadsheet file for storage");
    $t->wait_for_working_dialog();

    $verify_status = $t->find_element_ok(
        "upload_phenotype_fieldbook_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    ok($verify_status =~ /File data successfully parsed./, "Verify the positive store validation");
    ok($verify_status =~ /All values in your file have been successfully processed!/, "Verify the positive store validation");
    ok($verify_status =~ /Metadata saved for archived file./, "Verify the positive store validation");
    ok($verify_status =~ /Upload Successful!/, "Verify the positive store validation");

    #back to the trial page and re-upload !!
    $t->get_ok('/breeders/trial/137');
    $t->wait_for_working_dialog();

    $t->click_ok("trial_upload_files_onswitch", "id", "click on upload_fieldbook_link ");
    $t->click_ok("upload_fieldbook_phenotypes_link", "id", "click on upload_spreadsheet_link ");

    $t->wait_for_working_dialog();

    $t->click_ok("upload_fieldbook_phenotype_data_level", "id", "find fieldbook phenotype data level select");
    $t->click_ok('//select[@id="upload_fieldbook_phenotype_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of phenotype data level");

    $upload_input = $t->find_element_ok("upload_fieldbook_phenotype_file_input", "id", "find file input");
    $filename = $f->config->{basepath}."/t/data/fieldbook/fieldbook_phenotype_file_no_fieldbook_image.csv";
    $t->driver()->upload_file($filename);
    $upload_input->send_keys($filename);

    $t->click_ok("upload_fieldbook_phenotype_submit_verify", "id", "submit spreadsheet file for verification");
    $t->wait_for_working_dialog();

    $verify_status = $t->get_attribute_ok("upload_phenotype_fieldbook_verify_status", "id", "innerHTML", "verify the verification");

    print STDERR "VERIFY STATUS: $verify_status\n";
    
    ok($verify_status =~ /File data successfully parsed/, "Verify warnings after store validation");
    ok($verify_status =~ /File data verified. Plot names and trait names are valid./, "Verify plot names and trait names after store validation");
    ok($verify_status =~ /Warnings are shown in yellow. Either fix the file and try again/, "Verify yellow warnings after store validation");
    ok($verify_status =~ /To overwrite previously stored values instead/, "Verify overwrite values after store validation");
    ok($verify_status =~ /There are 28 values in your file that are the same as values already stored in the database./, "Verify 28 values in your file after store validation");

    $t->find_element_ok("upload_fieldbook_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();
    $t->wait_for_working_dialog();

    $verify_status = $t->find_element_ok(
        "upload_phenotype_fieldbook_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    print STDERR "VERIFY STATUS 2: $verify_status\n";
    
    ok($verify_status =~ /0 new values stored/, "Verify warnings: 0 new values stored");
    ok($verify_status =~ /30 previously stored values skipped/, "Verify warnings: 30 previously stored values skipped");
    ok($verify_status =~ /0 previously stored values overwritten/, "Verify warnings: 0 previously stored values overwritten");
    ok($verify_status =~ /0 previously stored values removed/, "Verify warnings: 0 previously stored values removed");
    ok($verify_status =~ /Upload Successful!/, "Verify warnings: Upload successful");

    $t->get_ok('/fieldbook');

    $t->click_ok("upload_fieldbook_phenotypes_link", "id", "click on upload_spreadsheet_link ");
    $t->click_ok("upload_fieldbook_phenotype_data_level", "id", "find fieldbook phenotype data level select");

    $t->click_ok('//select[@id="upload_fieldbook_phenotype_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of phenotype data level");

    $upload_input = $t->find_element_ok("upload_fieldbook_phenotype_file_input", "id", "find file input");
    $filename = $f->config->{basepath}."/t/data/fieldbook/fieldbook_phenotype_file_no_fieldbook_image.csv";
    $t->driver()->upload_file($filename);
    $upload_input->send_keys($filename);

    $t->click_ok("upload_fieldbook_phenotype_submit_verify", "id", "submit spreadsheet file for verification");
    $t->wait_for_working_dialog();

    $verify_status = $t->find_element_ok(
        "upload_phenotype_fieldbook_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    #check for warnings after the store_validation 
    ok($verify_status =~ /File data successfully parsed/, "Verify warnings after store validation");
    ok($verify_status =~ /File data verified. Plot names and trait names are valid./, "Verify warnings after store validation");
    ok($verify_status =~ /Warnings are shown in yellow. Either fix the file and try again/, "Verify warnings after store validation");
    ok($verify_status =~ /To overwrite previously stored values instead/, "Verify warnings after store validation");
    ok($verify_status =~ /There are 28 values in your file that are the same as values already stored in the database./, "Verify warnings after store validation");

    $t->click_ok("upload_fieldbook_phenotype_submit_store", "id", "submit spreadsheet file for storage");
    $t->wait_for_working_dialog();

    $verify_status = $t->find_element_ok(
        "upload_phenotype_fieldbook_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    ok($verify_status =~ /0 new values stored/, "Verify warnings after store validation");
    ok($verify_status =~ /30 previously stored values skipped/, "Verify warnings after store validation");
    ok($verify_status =~ /0 previously stored values overwritten/, "Verify warnings after store validation");
    ok($verify_status =~ /0 previously stored values removed/, "Verify warnings after store validation");
    ok($verify_status =~ /Upload Successful!/, "Verify warnings after store validation");
   
    }
);

$t->driver()->close();
$f->clean_up_db();
done_testing();

use strict;
use warnings;
use lib 't/lib';

use Test::More 'tests' => 39;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

# Test for both xlsx and xls file. First upload is done with xlsx file and stored in db. Then file with exactly the same content but in .xls format is uploaded to check if values will be duplicated.

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/breeders/trial/137');
    sleep(3);

    $t->wait_for_working_dialog();

    my $trial_files_onswitch = $t->find_element_ok("trial_upload_files_onswitch",  "id",  "find and open 'trial upload files onswitch' and click");
    $trial_files_onswitch->click();
    sleep(2);

    $t->wait_for_working_dialog();

    $t->find_element_ok("upload_datacollector_phenotypes_link", "id", "click on upload_trial_link ")->click();
    sleep(2);

    $t->find_element_ok("upload_phenotype_datacollector_data_level", "id", "find phenotype datacollector data level select")->click();
    sleep(1);

    $t->find_element_ok('//select[@id="upload_phenotype_datacollector_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of datacollector phenotype data level")->click();

    my $upload_input = $t->find_element_ok("upload_datacollector_phenotype_file_input", "id", "find file input");

    # Test for .xlsx upload and store data
    my $filename = $f->config->{basepath}."/t/data/trial/data_collector_upload.xlsx";
    $t->driver()->upload_file($filename);
    $upload_input->send_keys($filename);
    sleep(1);

    $t->find_element_ok("upload_datacollector_phenotype_submit_verify", "id", "submit spreadsheet file for verification")->click();
    sleep(3);

    my $verify_status = $t->find_element_ok(
        "upload_phenotype_datacollector_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    ok($verify_status =~ /File data_collector_upload.xlsx saved in archive./, "Verify the positive validation");
    ok($verify_status =~ /File valid: data_collector_upload.xlsx./, "Verify the positive validation");
    ok($verify_status =~ /File data successfully parsed./, "Verify the positive validation");
    ok($verify_status =~ /File data verified. Plot names and trait names are valid./, "Verify the positive validation");

    $t->find_element_ok("upload_datacollector_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();
    sleep(10);

    $verify_status = $t->find_element_ok(
        "upload_phenotype_datacollector_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    ok($verify_status =~ /File data successfully parsed./, "Verify the positive validation");
    ok($verify_status =~ /All values in your file have been successfully processed!/, "Verify the positive validation");
    ok($verify_status =~ /0 previously stored values overwritten/, "Verify the positive validation");
    ok($verify_status =~ /Metadata saved for archived file./, "Verify the positive validation");
    ok($verify_status =~ /Upload Successfull!/, "Verify the positive validation");

    $t->get_ok('/breeders/trial/137');
    sleep(3);

    $t->wait_for_working_dialog();

    my $trial_files_onswitch = $t->find_element_ok("trial_upload_files_onswitch",  "id",  "find and open 'trial upload files onswitch' and click");
    $trial_files_onswitch->click();
    sleep(2);

    $t->wait_for_working_dialog();
    
    $t->find_element_ok("upload_datacollector_phenotypes_link", "id", "click on upload_spreadsheet_link ")->click();
    sleep(2);

    $t->find_element_ok("upload_phenotype_datacollector_data_level", "id", "find phenotype datacollector data level select")->click();
    sleep(1);

    $t->find_element_ok('//select[@id="upload_phenotype_datacollector_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of datacollector phenotype data level")->click();

    $upload_input = $t->find_element_ok("upload_datacollector_phenotype_file_input", "id", "find file input");

    # Test for .xls upload and if data is correctly parsed to return duplication result from .xlsx file
    $filename = $f->config->{basepath}."/t/data/trial/data_collector_upload.xls";
    $t->driver()->upload_file($filename);
    $upload_input->send_keys($filename);
    sleep(1);

    $t->find_element_ok("upload_datacollector_phenotype_submit_verify", "id", "submit spreadsheet file for verification")->click();
    sleep(3);

    $verify_status = $t->find_element_ok(
        "upload_phenotype_datacollector_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');
    diag("verify_statues : $verify_status");
    ok($verify_status =~ /File data successfully parsed/, "Verify warnings after store validation");
    ok($verify_status =~ /File data verified. Plot names and trait names are valid./, "Verify warnings after store validation");
    ok($verify_status =~ /Warnings are shown in yellow. Either fix the file and try again/, "Verify warnings after store validation");
    ok($verify_status =~ /To overwrite previously stored values instead/, "Verify warnings after store validation");
    ok($verify_status =~ /There are 44 values in your file that are the same as values already stored in the database./, "Verify warnings after store validation");

    $t->find_element_ok("upload_datacollector_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();
    sleep(10);

    $verify_status = $t->find_element_ok(
        "upload_phenotype_datacollector_verify_status",
        "id", "verify the verification")->get_attribute('innerHTML');

    print STDERR "VERFIY STATUS NOW: $verify_status\n";
    
    ok($verify_status =~ /60 previously stored values skipped/, "Verify warnings after store validation - skipped values");
    ok($verify_status =~ /0 previously stored values overwritten/, "Verify warnings after store validation - overwritten values");
    ok($verify_status =~ /Metadata saved for archived file./, "Verify warnings after store validation - metadata saved");
    ok($verify_status =~ /0 previously stored values removed/, "Verify warnings after store validation - removed values");
    ok($verify_status =~ /Upload Successfull!/, "Verify warnings after store validation - upload successful");

    }
);

$t->driver()->close();
$f->clean_up_db();
done_testing();

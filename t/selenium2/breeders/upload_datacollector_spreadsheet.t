
use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/trial/137');

    $t->find_element_ok("upload_datacollector_phenotypes_link", "id", "click on upload_trial_link ")->click();

    sleep(2);

    my $upload_input = $t->find_element_ok("upload_datacollector_phenotype_file_input", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/data_collector_upload.xls";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    

    sleep(1);

    $t->find_element_ok("upload_datacollector_phenotype_submit_verify", "id", "submit spreadsheet file for verification")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File data_collector_upload.xls saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: data_collector_upload.xls.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File metadata set.')]", "xpath", "verify the verification")->get_text();
    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("upload_datacollector_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File data_collector_upload.xls saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: data_collector_upload.xls.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File metadata set.')]", "xpath", "verify the verification")->get_text();
    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data successfully stored.')]", "xpath", "verify the verification")->get_text();



    #try verifying and uploading the same file again.


    $t->get_ok('/breeders/trial/137');

    $t->find_element_ok("upload_datacollector_phenotypes_link", "id", "click on upload_spreadsheet_link ")->click();

    sleep(2);

    my $upload_input = $t->find_element_ok("upload_datacollector_phenotype_file_input", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/data_collector_upload.xls";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_datacollector_phenotype_submit_verify", "id", "submit spreadsheet file for verification")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File data_collector_upload.xls saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: data_collector_upload.xls.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File metadata set.')]", "xpath", "verify the verification")->get_text();
    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'Warnings are shown in yellow. Either fix the file and try again or continue with storing the data.')]", "xpath", "verify the verification")->get_text();



    $t->find_element_ok("upload_datacollector_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();

    sleep(10);

    $t->find_element_ok("//div[contains(., 'File data_collector_upload.xls saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: data_collector_upload.xls.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File metadata set.')]", "xpath", "verify the verification")->get_text();
    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data successfully stored.')]", "xpath", "verify the verification")->get_text();



    }

);

done_testing();

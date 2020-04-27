use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/trial/137');

    $t->find_element_ok("upload_fieldbook_phenotypes_link", "id", "click on upload_fieldbook_link ")->click();

    sleep(2);

    my $upload_input = $t->find_element_ok("upload_fieldbook_phenotype_file_input", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/fieldbook/fieldbook_phenotype_file.csv";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_fieldbook_phenotype_submit_verify", "id", "submit spreadsheet file for verification")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File fieldbook_phenotype_file.csv saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: fieldbook_phenotype_file.csv.')]", "xpath", "verify the verification")->get_text();
   
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("upload_fieldbook_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File fieldbook_phenotype_file.csv saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: fieldbook_phenotype_file.csv.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    #$t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'Metadata saved for archived file.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data successfully stored.')]", "xpath", "verify the verification")->get_text();



    #try verifying and uploading the same file again.


    $t->get_ok('/breeders/trial/137');

    $t->find_element_ok("upload_fieldbook_phenotypes_link", "id", "click on upload_spreadsheet_link ")->click();

    sleep(2);

    my $upload_input = $t->find_element_ok("upload_fieldbook_phenotype_file_input", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/fieldbook/fieldbook_phenotype_file.csv";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_fieldbook_phenotype_submit_verify", "id", "submit spreadsheet file for verification")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File fieldbook_phenotype_file.csv saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: fieldbook_phenotype_file.csv.')]", "xpath", "verify the verification")->get_text();

    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'Warnings are shown in yellow. Either fix the file and try again or continue with storing the data.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'This combination exists in database: ')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Plot Name: test_trial21')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Trait Name: dry matter content|CO_334:0000092')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Value: 35')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Trait Name: dry yield|CO_334:0000014')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Value: 42')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("upload_fieldbook_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File fieldbook_phenotype_file.csv saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: fieldbook_phenotype_file.csv.')]", "xpath", "verify the verification")->get_text();
    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    #$t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'Metadata saved for archived file.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data successfully stored.')]", "xpath", "verify the verification")->get_text();



    #try verifying and uploading the same file again from the /fieldbook page.


    $t->get_ok('/fieldbook');

    $t->find_element_ok("upload_fieldbook_phenotypes_link", "id", "click on upload_spreadsheet_link ")->click();

    sleep(2);

    my $upload_input = $t->find_element_ok("upload_fieldbook_phenotype_file_input", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/fieldbook/fieldbook_phenotype_file.csv";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_fieldbook_phenotype_submit_verify", "id", "submit spreadsheet file for verification")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File fieldbook_phenotype_file.csv saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: fieldbook_phenotype_file.csv.')]", "xpath", "verify the verification")->get_text();
    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'Warnings are shown in yellow. Either fix the file and try again or continue with storing the data.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'This combination exists in database: ')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Plot Name: test_trial21')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Trait Name: dry matter content|CO_334:0000092')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Value: 35')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Trait Name: dry yield|CO_334:0000014')]", "xpath", "verify the verification")->get_text();
    $t->find_element_ok("//div[contains(., 'Value: 42')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("upload_fieldbook_phenotype_submit_store", "id", "submit spreadsheet file for storage")->click();

    sleep(9);

    $t->find_element_ok("//div[contains(., 'File fieldbook_phenotype_file.csv saved in archive.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File valid: fieldbook_phenotype_file.csv.')]", "xpath", "verify the verification")->get_text();
    
    $t->find_element_ok("//div[contains(., 'File data successfully parsed.')]", "xpath", "verify the verification")->get_text();

    #$t->find_element_ok("//div[contains(., 'File data verified. Plot names and trait names are valid.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'Metadata saved for archived file.')]", "xpath", "verify the verification")->get_text();

    $t->find_element_ok("//div[contains(., 'File data successfully stored.')]", "xpath", "verify the verification")->get_text();

   
    $t->get_ok('/breeders/trial/137');
    sleep(9);

    $t->find_element_ok("trial_detail_traits_assayed_onswitch", "id", "view uploaded traits ")->click();

    sleep(5);
    }

);

done_testing();

use lib 't/lib';

use Test::More 'tests' => 6;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    sleep(1);

    $t->get_ok('/breeders/accessions');
    sleep(2);

    $t->find_element_ok("upload_pedigrees_link", "id", "click on upload_pedigrees_link ")->click();
    sleep(1);

    my $upload_input = $t->find_element_ok("pedigrees_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/pedigree_upload/upload_accession_selenium_test.txt";

    $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);
    sleep(1);

    $t->find_element_ok("upload_pedigrees_dialog_submit", "id", "validate upload pedigrees file")->click();
    sleep(3);

    $t->find_element_ok("upload_pedigrees_store", "id", "store upload pedigrees file to database")->click();
    sleep(3);

    $t->find_element_ok("pedigrees_upload_success_dismiss", "id", "dismiss success modal ")->click();
    sleep(1);

    }
);
$t->driver()->close();
done_testing();

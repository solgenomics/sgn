use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/accessions');

    $t->find_element_ok("upload_pedigrees_link", "id", "click on upload_pedigrees_link ")->click();

    my $upload_input = $t->find_element_ok("pedigrees_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/pedigree_upload/upload_accession_test.txt";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_pedigrees_dialog_submit", "id", "submit upload pedigrees file ")->click();

    sleep(2);

    $t->find_element_ok("pedigrees_upload_success_dismiss", "id", "dismiss success modal ")->click();

    sleep(1);

    }

);

done_testing();

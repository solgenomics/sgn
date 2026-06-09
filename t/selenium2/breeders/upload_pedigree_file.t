use lib 't/lib';

use Test::More 'tests' => 6;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/accessions');
    sleep(1); # FIXME Wait for click handler to be registered

    $t->click_ok("upload_pedigrees_link", "id", "click on upload_pedigrees_link ");

    my $filename = $f->config->{basepath}."/t/data/pedigree_upload/upload_accession_selenium_test.txt";
    $t->driver()->upload_file($filename);
    $t->send_keys_ok("pedigrees_uploaded_file", "id", $filename, "input file name");

    $t->click_ok("upload_pedigrees_dialog_submit", "id", "validate upload pedigrees file");
    $t->click_ok("upload_pedigrees_store", "id", "store upload pedigrees file to database");
    $t->click_ok("pedigrees_upload_success_dismiss", "id", "dismiss success modal ");

    }
);
$t->driver()->close();
done_testing();

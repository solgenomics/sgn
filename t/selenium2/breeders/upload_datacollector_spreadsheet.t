
use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/trial/137');

    $t->find_element_ok("upload_data_collector_link", "id", "click on upload_trial_link ")->click();

    sleep(2);

    my $upload_input = $t->find_element_ok("DataCollector_upload_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/data_collector_upload.xls";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_DataCollector_ok_button", "id", "submit upload data collector file ")->click();

    sleep(10);

    $t->driver->accept_alert();

    $t->get_ok('/breeders/trials');

    sleep(2);

    $t->find_element_ok("test", "partial_link_text", "check program in tree")->click();

    $t->find_element_ok("jstree-icon", "class", "view drop down for program")->click();

    sleep(3);
    
    $t->find_element_ok("test_trial", "partial_link_text", "check program in tree")->click();
   
    $t->get_ok('/breeders/trial/137');
    sleep(20);
    }

);

done_testing();

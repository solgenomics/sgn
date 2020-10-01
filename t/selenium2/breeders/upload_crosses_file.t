use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/crosses');

    $t->find_element_ok("upload_crosses_link", "name", "click on upload_crosses_link ")->click();

    sleep(2);

    my $program_select = $t->find_element_ok("cross_upload_breeding_program", "id", "find breeding program select");

    $program_select->send_keys('test');

    my $location_select = $t->find_element_ok("cross_upload_location", "id", "find location select");

    $location_select->send_keys('test_location');

    my $upload_input = $t->find_element_ok("crosses_upload_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/cross/upload_cross.xls";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_crosses_submit", "id", "submit upload cross file ")->click();

    sleep(4);

    $t->find_element_ok("cross_upload_success_dismiss", "id", "dismiss success modal ")->click();

    sleep(2);
    
    $t->get_ok('/breeders/crosses');

    sleep(2);

    $t->find_element_ok("test_upload_cross1", "partial_link_text", "find link for test_cross")->click();

    sleep(2);
    }

);

done_testing();

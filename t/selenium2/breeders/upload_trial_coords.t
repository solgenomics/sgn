use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/trial/137');

    $t->find_element_ok("upload_trial_coords_link", "id", "click on upload_trial_coords_link ")->click();

    sleep(2);

    my $upload_input = $t->find_element_ok("trial_coordinates_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/upload_trial_coords_file.csv";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_trial_coords_ok_button", "id", "submit upload trial coords file ")->click();

    sleep(10); 

    $t->find_element_ok("dismiss_trial_coord_upload_dialog", "id", "close success msg")->click();

    sleep(20);    

    
    $t->find_element_ok("physical_layout_onswitch", "id", "view field map ")->click();

    sleep(20);

    
    }

);

done_testing();

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/trials');

    $t->find_element_ok("upload_trial_link", "name", "click on upload_trial_link ")->click();

    sleep(2);

    my $program_select = $t->find_element_ok("trial_upload_breeding_program", "id", "find breeding program select");

    $program_select->send_keys('test');

    my $location_select = $t->find_element_ok("trial_upload_location", "id", "find location select");

    $location_select->send_keys('test_location');

    my $trial_name = $t->find_element_ok("trial_upload_name", "id", "find trial name input");

    $trial_name->send_keys('test_trial_upload');

    my $trial_year = $t->find_element_ok("trial_upload_year", "id", "find trial year input");

    $trial_year->send_keys('2015');

    my $trial_description = $t->find_element_ok("trial_upload_description", "id", "find trial description input");

    $trial_description->send_keys('Test trial test description');

    my $trial_design = $t->find_element_ok("trial_upload_design_method", "id", "find trial design select");

    $trial_design->send_keys('Completely Randomized');

    my $upload_input = $t->find_element_ok("trial_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/trial_layout_example.xls";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_trial_submit", "id", "submit upload trial file ")->click();

    sleep(5);

    $t->get_ok('/breeders/trials');
    
    my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
    sleep(3);

    $t->find_element_ok("test", "partial_link_text", "check program in tree")->click();

    $t->find_element_ok("jstree-icon", "class", "view drop down for program")->click();

    sleep(3);
    
    $t->find_element_ok("test_trial_upload", "partial_link_text", "check program in tree")->click();

    sleep(1);
    }

);

done_testing();

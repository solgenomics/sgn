use lib 't/lib';

use Test::More 'tests' => 12;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

use strict;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/breeders/trial/137');
    sleep(3);

    my $heatmap_onswitch = $t->find_element_ok("pheno_heatmap_onswitch",  "id",  "click to open pheno heatmap panel");

    $heatmap_onswitch->click();
    sleep(5);

    $t->find_element_ok("heatmap_upload_trial_coords_link", "id", "click on upload_trial_coords_link ")->click();

    my $upload_input = $t->find_element_ok("trial_coordinates_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/upload_trial_coords_file.csv";

    $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);
    sleep(1);

    $t->find_element_ok("upload_trial_coords_ok_button", "id", "submit upload trial coords file ")->click();
    sleep(15);

    $t->find_element_ok("trial_coord_upload_success_dialog_message_cancel", "id", "close success msg")->click();
    sleep(1);

    $t->find_element_ok("upload_trial_coords_cancel_button", "id", "close upload modal")->click();
    sleep(1);

    # RELOAD PAGE TO CHECK IF SUCCESS
    $t->get_ok('/breeders/trial/137');
    sleep(3);

    my $heatmap_onswitch = $t->find_element_ok("pheno_heatmap_onswitch",  "id",  "click to open pheno heatmap panel");

    $heatmap_onswitch->click();
    sleep(4);

    $t->find_element_ok("trial_fieldmap_download_layout_button", "id", "find a download button after upload coordinates");
    sleep(1);
    
    $t->find_element_ok("delete_field_map_hm_link", "id", "find a delete coordinates after upload button and click")->click();
    sleep(1);

    $t->accept_alert_ok("find confirm deletion of coordinates after upload");
    }
);

$t->driver()->close();
$f->clean_up_db();
done_testing();

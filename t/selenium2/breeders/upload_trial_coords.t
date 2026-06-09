use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

use strict;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    $t->get_ok('/breeders/trial/137');
    sleep(1); # FIXME Need to wait for click handler to be registered

    $t->click_ok("pheno_heatmap_onswitch",  "id",  "click to open pheno heatmap panel");
    $t->wait_for_working_dialog();

    $t->click_ok("heatmap_upload_trial_coords_link", "id", "click on upload_trial_coords_link ");

    my $filename = $f->config->{basepath}."/t/data/trial/upload_trial_coords_file.csv";

    $t->driver()->upload_file($filename);
    $t->send_keys_ok("trial_coordinates_uploaded_file", "id", $filename, "input file name");

    $t->click_ok("upload_trial_coords_ok_button", "id", "submit upload trial coords file");
    $t->wait_for_working_dialog();
    $t->wait_for_network_idle();
    $t->click_ok("trial_coord_upload_success_dialog_message_cancel", "id", "close success msg");
    $t->wait_for_network_idle();

    # RELOAD PAGE TO CHECK IF SUCCESS
    $t->get_ok('/breeders/trial/137');
    sleep(1); # FIXME Need to wait for click handler to be registered

    $t->click_ok("pheno_heatmap_onswitch", "id", "click to open pheno heatmap panel");

    $t->find_element_ok("trial_fieldmap_download_layout_button", "id", "find a download button after upload coordinates");

    $t->click_ok("delete_field_map_hm_link", "id", "find a delete coordinates after upload button and click");

    $t->accept_alert_ok("find confirm deletion of coordinates after upload");
    }
);

$t->driver()->close();
$f->clean_up_db();
done_testing();

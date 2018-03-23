use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/breeders/trials');
    $t->find_element_ok("refresh_jstree_html", "name", "click on upload_trial_link ")->click();
    sleep(10);

    $t->find_element_ok("upload_trial_link", "name", "click on upload_trial_link ")->click();

    sleep(2);

    my $program_select = $t->find_element_ok("trial_upload_breeding_program", "id", "find breeding program select");

    $program_select->send_keys('test');

    my $location_select = $t->find_element_ok("trial_upload_location", "id", "find location select");

    $location_select->send_keys('test_location');

    my $trial_name = $t->find_element_ok("trial_upload_name", "id", "find trial name input");

    $trial_name->send_keys('test_trial_upload');

    my $trial_year = $t->find_element_ok("trial_upload_year", "id", "find trial year input");

    $trial_year->send_keys('2016');

    my $trial_description = $t->find_element_ok("trial_upload_description", "id", "find trial description input");

    $trial_description->send_keys('Test derived traits trial test description');

    my $trial_design = $t->find_element_ok("trial_upload_design_method", "id", "find trial design select");

    $trial_design->send_keys('Completely Randomized');

    my $upload_input = $t->find_element_ok("trial_uploaded_file", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/trial_layout_example.xls";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_trial_submit", "id", "submit upload trial file ")->click();

    sleep(5);

    $t->get_ok('/breeders/phenotyping');
	
    sleep(2);

    $t->find_element_ok("upload_spreadsheet_phenotypes_link", "id", "submit upload phenotype file ")->click();

      sleep(2);

     my $upload_input = $t->find_element_ok("upload_spreadsheet_phenotype_file_input", "id", "find file input");

    my $filename = $f->config->{basepath}."/t/data/trial/trial_phenotype_upload_file.xls";

    my $remote_filename = $t->driver()->upload_file($filename);

    $upload_input->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_spreadsheet_phenotype_submit_verify", "id", "submit upload trial file ")->click();

    sleep(5);

    $t->find_element_ok("upload_spreadsheet_phenotype_submit_store", "id", "submit upload trial file ")->click();    

    sleep(5);

    $t->get_ok('/breeders/trials');

    sleep(2);

    $t->find_element_ok("refresh_jstree_html", "name", "click on upload_trial_link ")->click();
    sleep(10);

    $t->find_element_ok("test", "partial_link_text", "check program in tree")->click();

    $t->find_element_ok("jstree-icon", "class", "view drop down for program")->click();

    sleep(3);
    
    $t->find_element_ok("test_trial_upload", "partial_link_text", "check program in tree")->click();

    sleep(1);
  
   $t->get_ok('/breeders/trial/145');

   sleep(3);

    $t->find_element_ok("compute_derived_traits_onswitch", "id", "click on compute trait link ")->click();

    sleep(1);

$t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();

    sleep(3);

    my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");

    $trait_select->send_keys('sprouting|CO_334:0000008');

   # $t->find_element_ok("button", "id", "submit compute trait ")->click();

   # sleep(1);

    $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();

    sleep(5);

   # $t->find_element_ok("derived_trait_saved_dialog_message", "id", "ok compute trait saved dialog")->click();

    #sleep(1);

    $t->driver->accept_alert();

    sleep(1);

    $t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();

    sleep(3);

    my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");

    $trait_select->send_keys('specific gravity|CO_334:0000163');


    $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();

    sleep(5);

    $t->driver->accept_alert();

    sleep(1);

     $t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();

    sleep(3);

    my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");

    $trait_select->send_keys('starch content|CO_334:0000071');

    $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();

    sleep(5);

    $t->driver->accept_alert();

    sleep(1);

     $t->find_element_ok("derived_button", "id", "click on compute trait link button")->click();

    sleep(3);

    my $trait_select = $t->find_element_ok("derived_trait_select", "id", "find trait select dialog");

    $trait_select->send_keys('dry matter content by specific gravity method|CO_334:0000160');

    $t->find_element_ok("create_derived_trait_submit_button", "id", "submit compute trait ")->click();

    sleep(5);

    $t->driver->accept_alert();

    sleep(1);

    #$t->get_ok('/breeders/trial/145');

   # sleep(3);

    $t->find_element_ok("trial_detail_traits_assayed_onswitch", "id", "view uploaded traits ")->click();

    sleep(5);

    
    }

);

done_testing();

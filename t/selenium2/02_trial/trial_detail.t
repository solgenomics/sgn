use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->login_as("curator");
#Upload New Trial


$t->get_ok('/breeders/trials');
my $refresh_tree = $t->find_element_ok("refresh_jstree_html_trialtree_button", "name", "refresh tree")->click();
sleep(3);
$t->find_element_ok("upload_trial_link", "id", "click on upload_trial_link ")->click();
sleep(2);
my $program_select = $t->find_element_ok("trial_upload_breeding_program", "id", "find breeding program select");
$program_select->send_keys('test');
my $location_select = $t->find_element_ok("trial_upload_location", "id", "find location select");
$location_select->send_keys('test_location');
my $trial_name = $t->find_element_ok("trial_upload_name", "id", "find trial name input");
$trial_name->send_keys('T100');
my $trial_year = $t->find_element_ok("trial_upload_year", "id", "find trial year input");
$trial_year->send_keys('2016');
my $trial_description = $t->find_element_ok("trial_upload_description", "id", "find trial description input");
$trial_description->send_keys('T100 trial test description');
my $trial_design = $t->find_element_ok("trial_upload_design_method", "id", "find trial design select");
$trial_design->send_keys('Completely Randomized');
my $upload_input = $t->find_element_ok("trial_uploaded_file", "id", "find file input");
my $filename = $f->config->{basepath}."/t/data/trial/T100_trial_layout.xls";
my $remote_filename = $t->driver()->upload_file($filename);
$upload_input->send_keys($filename);
sleep(1);
$t->find_element_ok("upload_trial_submit_first", "name", "submit upload trial file ")->click();
sleep(5);

$t->find_element_ok("close_trial_upload_success_dialog", "id", "success msg")->click();
sleep(1);
$t->find_element_ok("close_trial_upload_dialog", "id", "close trial upload dialog")->click();
sleep(1);

my $refresh_tree = $t->find_element_ok("refresh_jstree_html_trialtree_button", "name", "refresh tree")->click();
sleep(3);
my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
sleep(2);
my $open_tree = $t->find_element_ok("T100", "partial_link_text", "open up tree")->click();

my $trial_id = $f->bcs_schema->resultset('Project::Project')->search({name=>'T100'}, {order_by => { -desc => 'project_id'}})->first->project_id();

#Upload Trial Coordinates -> New Trial ID 144
$t->get_ok('/breeders/trial/'.$trial_id);
sleep(10);
$t->find_element_ok("upload_trial_coords_link", "id", "click on upload_trial_coords_link ")->click();
sleep(2);
my $upload_input = $t->find_element_ok("trial_coordinates_uploaded_file", "id", "find file input");
my $filename = $f->config->{basepath}."/t/data/trial/T100_trial_coords.csv";
my $remote_filename = $t->driver()->upload_file($filename);
$upload_input->send_keys($filename);
sleep(1);
$t->find_element_ok("upload_trial_coords_ok_button", "id", "submit upload trial coords file ")->click();
sleep(2); 
$t->find_element_ok("dismiss_trial_coord_upload_dialog", "id", "close success msg")->click();
sleep(3);    
$t->find_element_ok("physical_layout_onswitch", "id", "view field map ")->click();
sleep(6);
$t->find_element_ok("physical_layout_offswitch", "id", "view field map ")->click();
sleep(2);

#Verify Trial Info

sleep(3);
$t->find_element_ok("//div[contains(., 'T100')]", "xpath", "verify trial name")->get_text();
$t->find_element_ok("//div[contains(., 'test')]", "xpath", "verify breeding program")->get_text();
$t->find_element_ok("//div[contains(., 'test_location')]", "xpath", "verify trial location")->get_text();
$t->find_element_ok("//div[contains(., '2016')]", "xpath", "verify trial year")->get_text();
$t->find_element_ok("//div[contains(., '[Type not set]')]", "xpath", "verify trial type")->get_text();
$t->find_element_ok("//div[contains(., '[No Planting Date]')]", "xpath", "verify planting date")->get_text();
$t->find_element_ok("//div[contains(., '[No Harvest Date]')]", "xpath", "verify harvest date")->get_text();
$t->find_element_ok("//div[contains(., 'T100 trial test description')]", "xpath", "verify description")->get_text();

#Verify Trial Design
$t->find_element_ok("//div[contains(., 'CRD')]", "xpath", "verify design type")->get_text();
$t->find_element_ok("//div[contains(., '2')]", "xpath", "verify number of blocks")->get_text();
$t->find_element_ok("//div[contains(., '2')]", "xpath", "verify number of blocks")->get_text();
$t->find_element_ok("//div[contains(., 'undefined')]", "xpath", "verify plants per plot")->get_text();
$t->find_element_ok("trial_accessions_onswitch", "id", "view trial accessions")->click();
sleep(5);
$t->find_element_ok("test_accession1", "partial_link_text", "verify accessions");
$t->find_element_ok("test_accession2", "partial_link_text", "verify accessions");
$t->find_element_ok("test_accession3", "partial_link_text", "verify accessions");
$t->find_element_ok("test_accession4", "partial_link_text", "verify accessions");
$t->find_element_ok("trial_controls_onswitch", "id", "view trial controls")->click();
sleep(5);
$t->find_element_ok("test_accession2", "partial_link_text", "verify controls");
$t->find_element_ok("test_accession3", "partial_link_text", "verify controls");
$t->find_element_ok("trial_plots_onswitch", "id", "view trial plots")->click();
sleep(5);
$t->find_element_ok("plot_select_all", "id", "select plots")->click();
sleep(1);
$t->find_element_ok("plot_data_new_list_name", "id", "find add list input");

my $add_list_input = $t->find_element_ok("plot_data_new_list_name", "id", "find add list input test");

$add_list_input->send_keys("plots_list");

$t->find_element_ok("plot_data_add_to_new_list", "id", "find add list button")->click();
sleep(1);
$t->accept_alert_ok();
sleep(1);
my $out = $t->find_element_ok("lists_link", "name", "find lists_link")->click();
sleep(3);
$t->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

$t->find_element_ok("//div[contains(., 'T100_plot_01')]", "xpath", "verify plots")->get_text();
$t->find_element_ok("//div[contains(., 'T100_plot_02')]", "xpath", "verify plots")->get_text();
$t->find_element_ok("//div[contains(., 'T100_plot_03')]", "xpath", "verify plots")->get_text();
$t->find_element_ok("//div[contains(., 'T100_plot_04')]", "xpath", "verify plots")->get_text();
$t->find_element_ok("//div[contains(., 'T100_plot_05')]", "xpath", "verify plots")->get_text();
$t->find_element_ok("//div[contains(., 'T100_plot_06')]", "xpath", "verify plots")->get_text();
$t->find_element_ok("//div[contains(., 'T100_plot_07')]", "xpath", "verify plots")->get_text();
$t->find_element_ok("//div[contains(., 'T100_plot_08')]", "xpath", "verify plots")->get_text();


$t->find_element_ok("//div[contains(., 'test')]", "xpath", "verify breeding program")->get_text();

$t->find_element_ok("//div[contains(., 'T100')]", "xpath", "verify trial name")->get_text();

$t->find_element_ok("//div[contains(., '2016')]", "xpath", "verify trial type")->get_text();

$t->find_element_ok("//div[contains(., 'test_location')]", "xpath", "verify trial location")->get_text();

$t->find_element_ok("//div[contains(., 'T100 trial test description')]", "xpath", "verify desc")->get_text();






done_testing();

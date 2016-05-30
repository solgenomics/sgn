use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("curator", sub { 

    #Upload New Trial
    $t->get_ok('/breeders/trials');
    my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "id", "refresh tree")->click();
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
    $t->find_element_ok("upload_trial_submit", "id", "submit upload trial file ")->click();
    sleep(5);
    my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "id", "refresh tree")->click();
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
    sleep(4);


    #Verify Trial Info
    $t->find_element_ok("//div[contains(., 'test (test)')]", "xpath", "verify breeding program")->get_text();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'T100')]", "xpath", "verify trial name")->get_text();
    $t->find_element_ok("//div[contains(., '[Type not set]')]", "xpath", "verify trial type")->get_text();
    $t->find_element_ok("//div[contains(., 'T100 trial test description')]", "xpath", "verify description")->get_text();

    #Verify Trial Design
    $t->find_element_ok("//div[contains(., 'CRD')]", "xpath", "verify design type")->get_text();
    $t->find_element_ok("//div[contains(., '2')]", "xpath", "verify number of blocks")->get_text();
    $t->find_element_ok("//div[contains(., '2')]", "xpath", "verify number of blocks")->get_text();
    $t->find_element_ok("trial_accessions_onswitch", "id", "view trial accessions")->click();
    sleep(3);
    $t->find_element_ok("test_accession1", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession2", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession3", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession4", "partial_link_text", "verify accessions");
     $t->find_element_ok("trial_controls_onswitch", "id", "view trial controls")->click();
     sleep(3);
    $t->find_element_ok("test_accession2", "partial_link_text", "verify controls");
    $t->find_element_ok("test_accession3", "partial_link_text", "verify controls");
    $t->find_element_ok("trial_plots_onswitch", "id", "view trial plots")->click();
    sleep(3);
    $t->find_element_ok("//div[contains(., 'T100_plot_01')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'T100_plot_02')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'T100_plot_03')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'T100_plot_04')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'T100_plot_05')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'T100_plot_06')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'T100_plot_07')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'T100_plot_08')]", "xpath", "verify plots")->get_text();


    #Edit Breeding Program
    $t->find_element_ok("show_change_breeding_program_link", "id", "find edit breeding program")->click();
    $t->find_element_ok("breeding_program_select", "id", "edit breeding program")->send_keys('test');
    $t->find_element_ok("edit_trial_breeding_program_submit", "id", "submit edit breeding program")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'test (test)')]", "xpath", "verify breeding program")->get_text();

    #Edit Name
    $t->find_element_ok("edit_trial_name", "id", "find edit trial name")->click();
    sleep(1);
    $t->find_element_ok("trial_name_input", "id", "edit trial name")->send_keys('New Trial Name');
    $t->find_element_ok("edit_name_save_button", "id", "submit edit trial name")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'New Trial Name')]", "xpath", "verify trial name")->get_text();

    #Edit Trial type
    $t->find_element_ok("edit_trial_type", "id", "find edit trial type")->click();
    $t->find_element_ok("trial_type_select", "id", "edit trial type")->send_keys('AYT');
    $t->find_element_ok("edit_type_save_button", "id", "submit edit trial type")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'AYT')]", "xpath", "verify trial type")->get_text();

    #Edit year
    $t->find_element_ok("change_year_link", "id", "find edit year")->click();
    sleep(1);
    $t->find_element_ok("year_select", "id", "edit year")->send_keys('2014');
    $t->find_element_ok("change_trial_year_save_button", "id", "submit edit year")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., '2014')]", "xpath", "verify trial type")->get_text();

    #Edit location
    $t->find_element_ok("change_trial_location_link", "id", "find edit location")->click();
    $t->find_element_ok("location_select", "id", "edit location")->send_keys('test_location');
    $t->find_element_ok("edit_trial_location_submit", "id", "submit edit location")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'test_location')]", "xpath", "verify trial location")->get_text();

    #Edit planting date. Cant get this to work with the calendar popping up.
    #$t->find_element_ok("change_planting_date_link", "id", "find edit planting date")->click();
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->click();
    #sleep(1);
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->send_keys('01/26/2016');
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->send_keys(KEYS->{'enter'});
    #sleep(1);
    #$t->find_element_ok("change_planting_date_button", "id", "submit edit date")->click();
    #sleep(1);
    #$t->driver->accept_alert();
    #sleep(1);
    #$t->find_element_ok("//div[contains(., '2016/01/26')]", "xpath", "verify date")->get_text();

    #Edit harvest date. Cant get this to work with the calendar popping up.
    #$t->find_element_ok("change_harvest_date_link", "id", "find edit harvest date")->click();
    #$t->find_element_ok("harvest_date_picker", "id", "edit date")->click();
    #sleep(1);
    #$t->find_element_ok("harvest_date_picker", "id", "edit date")->send_keys('01/27/2016');
    #$t->find_element_ok("planting_date_picker", "id", "edit date")->send_keys(KEYS->{'enter'});
    #sleep(1);
    #$t->find_element_ok("change_harvest_date_button", "id", "submit edit date")->click();
    #sleep(1);
    #$t->driver->accept_alert();
    #sleep(1);
    #$t->find_element_ok("//div[contains(., '2016/01/27')]", "xpath", "verify date")->get_text();

    #Edit description
    $t->find_element_ok("edit_trial_description", "id", "find edit description")->click();
    $t->find_element_ok("trial_description_input", "id", "edit description")->send_keys('test_description');
    $t->find_element_ok("edit_description_save_button", "id", "submit edit desc")->click();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->driver->accept_alert();
    sleep(1);
    $t->find_element_ok("//div[contains(., 'test_description')]", "xpath", "verify desc")->get_text();






    }


);

done_testing();

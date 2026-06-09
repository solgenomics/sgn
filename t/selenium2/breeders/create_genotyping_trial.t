
use strict;

use lib 't/lib';

use Test::More;

use Data::Dumper;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
	$t->get_ok('/breeders/genotyping_projects');

	sleep(1); # FIXME Need to wait for click handler to be registered

	# CREATE PROJECT FIRST
	$t->click_ok("create_genotyping_project_link", "name", "find create genotyping project link abd click");

	# SCREEN 1 /Intro/
	$t->click_ok('next_step_add_new_genotyping_project', 'id', 'Next step from Into Screen find and click');

	# SCREEN 2 /Genotyping Project/
	my $project_name = "NEXTGENCASSAVA";
	$t->send_keys_ok('new_genotyping_project_name', 'id', $project_name, 'find "genotyping project name" and click');

	$t->click_ok('genotyping_project_facility_select', 'id', 'find "genotyping project facility select" and click');
	$t->click_ok('//select[@id="genotyping_project_facility_select"]/option[@value="None"]', 'xpath', 'Select "None" as value for genotyping project facility');

	$t->click_ok('data_type', 'id', 'find "genotyping project data_type" and click');
	$t->click_ok('//select[@id="data_type"]/option[@value="snp"]', 'xpath', 'Select "snp" as value for genotyping data type');

	$t->click_ok('genotyping_project_breeding_program_select', 'id', 'find "genotyping breeding program select" and click');
	$t->click_ok('//select[@id="genotyping_project_breeding_program_select"]/option[@title="test"]', 'xpath', 'Select "Breedbase" as title for genotyping data type');

	$t->click_ok('genotyping_project_year_select', 'id', 'find "genotyping project year" select and click');
	$t->click_ok('//select[@id="genotyping_project_year_select"]/option[@title="2018"]', 'xpath', 'Select "2018" as value of project year');

	$t->click_ok('genotyping_project_location_select', 'id', 'find "genotyping project location" select and click');
	$t->click_ok('//select[@id="genotyping_project_location_select"]/option[@title="test_location"]', 'xpath', 'Select "test_location" as value of project location');

	$t->send_keys_ok('genotyping_project_description', 'id', "Selenium test genotyping project description", 'find "genotyping project description" and fill');

	$t->click_ok('add_new_genotyping_project_submit', 'id', 'New genotyping project submit button find and click');
    
    $t->wait_for_working_dialog();

	$t->click_ok('add_new_genotyping_project_close_modal', 'id', 'New genotyping project close modal button find and click');

    #manage genotyping projects
    $t->click_ok("refresh_genotyping_project_jstree_html_button", "id", "find and click 'refresh genotyping project jstree'");
	$t->wait_for_network_idle();

    $t->click_ok('//div[@id="genotyping_project_list"]//i[contains(@class, "jstree-icon")]', 'xpath', 'open a tree with genotyping project list');
	$t->wait_for_network_idle();

    my $href_to_trial = $t->get_attribute_ok("//div[\@id='genotyping_project_list']//a[contains(text(), '$project_name')]", 'xpath', 'href', 'find created project and take link href');

    $t->get_ok($href_to_trial);

	# test uploading genotyping plate for both excel formats xls and xlsx
	my @files = (["NEW_CASSAVA_GS_74Template.xls", "2018TestPlate02"], ["NEW_CASSAVA_GS_74Template_selenium.xlsx", "2018TestPlate03"]);
	for my $index (0 .. $#files) {

		my $plate_name = $files[$index][1];
		my $excel_file_name = $files[$index][0];

		$t->get_ok('/breeders/genotyping_projects');
		sleep(1); # FIXME Need to wait for click handler to be registered

		# CREATE TRIAL
		$t->click_ok("create_genotyping_trial_link", "name", "find create genotyping trial link abd click");

		# SCREEN 1 /Intro/
		$t->click_ok('next_step_intro_button', 'id', 'go to next screen - Intro');

		# SCREEN 2 /Genotyping Project/
		$t->click_ok('next_step_creating_genotyping_plates', 'id', 'go to next screen - Genotyping Project');

		# SCREEN 3 /Basic Plate Info/
		$t->click_ok('plate_genotyping_project_id', 'id', 'find "genotyping trial facility select" and click');

		$t->click_ok("//select[\@id=\"plate_genotyping_project_id\"]/option[\@title='$project_name']", 'xpath', "Select $project_name as value for genotyping project facility");

		$t->send_keys_ok('genotyping_trial_name', 'id', $plate_name, 'find "genotyping trial name" and click');

		$t->click_ok('genotyping_trial_plate_format', 'id', 'find "genotyping trial plate format" select and click');
		$t->click_ok('//select[@id="genotyping_trial_plate_format"]/option[@value="96"]', 'xpath', 'Select "96" as value for genotyping trial plate format');

		$t->click_ok('genotyping_trial_plate_sample_type', 'id', 'find "genotyping trial plate sample type" select and click');
		$t->click_ok('//select[@id="genotyping_trial_plate_sample_type"]/option[@value="DNA"]', 'xpath', 'Select "DNA" as value for plate sample type');

		$t->send_keys_ok('genotyping_trial_description', 'id', "Selenium test plate description", 'find "genotyping trial description" and fill');
		$t->click_ok('plate_info_intro_button', 'id', 'go to next screen - Basic Plate Info');

		# SCREEN 4 /Well Info/
		$t->click_ok('genotyping_trial_well_input_option', 'id', 'find "genotyping trial well input" select and click');
		$t->click_ok('//select[@id="genotyping_trial_well_input_option"]/option[@value="xlsx"]', 'xpath', 'Select "xlsx" as value of trial well input formal (Excel)');

		my $filename = $f->config->{basepath} . "/t/data/genotype_trial_upload/$excel_file_name";
		my $remote_filename = $t->driver()->upload_file($filename);
		$t->send_keys_ok("genotyping_trial_layout_upload", "id", $filename, "find trial file upload button");

		$t->click_ok('well_info_intro_button', 'id', 'go to next screen - Well Info');

		# SCREEN 5 /Trial Linkage/
		$t->click_ok('trial_linkage_intro_button', 'id', 'go to next screen - Well Info');

		# SCREEN 6 /Confirm/
		$t->click_ok('add_geno_trial_submit', 'id', 'find "submit genotyping trial" and click');
		$t->wait_for_working_dialog();

		$t->click_ok('close_trial_button', 'id', 'find "close trial button" and click');
		$t->wait_for_network_idle();

        #New genotyping plate ID
        my $genotyping_plate_id = $f->bcs_schema->resultset('Project::Project')->find({ name => $plate_name })->project_id();
        $t->get_ok('/breeders/trial/' . $genotyping_plate_id);

        my $trial_table_content = $t->get_attribute_ok('trial_plate_view_table', 'id', 'innerHTML', 'find table with created trial data');
        ok($trial_table_content =~ /\Q${plate_name}_F07/, "Verify sample id in a table: ${plate_name}_F07");
        ok($trial_table_content =~ /\Q${plate_name}_B04/, "Verify sample id in a table: ${plate_name}_B04");
        ok($trial_table_content =~ /test_accession1/, "Verify accession id in a table: test_accession1");

        my $trial_plate_layout = $t->get_attribute_ok('trial_plate_layout_table', 'id', 'innerHTML', 'find table with plate layout');

        ok($trial_table_content =~ /A01/, "Verify well id in a table: A01");
        ok($trial_table_content =~ /A05/, "Verify well id in a table: A05");
    }
});

$t->driver()->close();
done_testing();

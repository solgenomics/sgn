
use strict;

use lib 't/lib';

use Test::More 'tests' => 77;

use Data::Dumper;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
	sleep(1);

	$t->get_ok('/breeders/genotyping_projects');
	sleep(2);

	# CREATE PROJECT FIRST
	$t->find_element_ok("create_genotyping_project_link", "name", "find create genotyping project link abd click")->click();
	sleep(1);

	# SCREEN 1 /Intro/
	$t->find_element_ok('next_step_add_new_genotyping_project', 'id', 'Next step from Into Screen find and click')->click();
	sleep(2);

	# SCREEN 2 /Genotyping Project/
	my $project_name = "NEXTGENCASSAVA";
	$t->find_element_ok('new_genotyping_project_name', 'id', 'find "genotyping project name" and click')->send_keys($project_name);
	sleep(1);

	$t->find_element_ok('genotyping_project_facility_select', 'id', 'find "genotyping project facility select" and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_project_facility_select"]/option[@value="None"]', 'xpath', 'Select "None" as value for genotyping project facility')->click();

	$t->find_element_ok('data_type', 'id', 'find "genotyping project data_type" and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="data_type"]/option[@value="snp"]', 'xpath', 'Select "snp" as value for genotyping data type')->click();

	$t->find_element_ok('genotyping_project_breeding_program_select', 'id', 'find "genotyping breeding program select" and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_project_breeding_program_select"]/option[@title="test"]', 'xpath', 'Select "Breedbase" as title for genotyping data type')->click();

	$t->find_element_ok('genotyping_project_year_select', 'id', 'find "genotyping project year" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_project_year_select"]/option[@title="2018"]', 'xpath', 'Select "2018" as value of project year')->click();

	$t->find_element_ok('genotyping_project_location_select', 'id', 'find "genotyping project location" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_project_location_select"]/option[@title="test_location"]', 'xpath', 'Select "test_location" as value of project location')->click();

	$t->find_element_ok('genotyping_project_description', 'id', 'find "genotyping project description" and fill')->send_keys("Selenium test genotyping project description");

	$t->find_element_ok('add_new_genotyping_project_submit', 'id', 'New genotyping project submit button find and click')->click();
	sleep(4);

	$t->find_element_ok('add_new_genotyping_project_close_modal', 'id', 'New genotyping project close modal button find and click')->click();
	sleep(1);

    #manage genotyping projects
    $t->find_element_ok("refresh_genotyping_project_jstree_html_button", "id", "find and click 'refresh genotyping project jstree'")->click();
    sleep(5);

    $t->find_element_ok('//div[@id="genotyping_project_list"]//i[contains(@class, "jstree-icon")]', 'xpath', 'open a tree with genotyping project list')->click();
    sleep(5);

    my $href_to_trial = $t->find_element_ok("//div[\@id='genotyping_project_list']//a[contains(text(), '$project_name')]", 'xpath', 'find created project and take link href')->get_attribute('href');

    $t->get_ok($href_to_trial);
    sleep(5);

	# test uploading genotyping plate for both excel formats xls and xlsx
	my @files = (["NEW_CASSAVA_GS_74Template.xls", "2018TestPlate02"], ["NEW_CASSAVA_GS_74Template_selenium.xlsx", "2018TestPlate03"]);
	for my $index (0 .. $#files) {

		my $plate_name = $files[$index][1];
		my $excel_file_name = $files[$index][0];

		$t->get_ok('/breeders/genotyping_projects');
		sleep(2);

		# CREATE TRIAL
		$t->find_element_ok("create_genotyping_trial_link", "name", "find create genotyping trial link abd click")->click();
		sleep(1);

		# SCREEN 1 /Intro/
		$t->find_element_ok('next_step_intro_button', 'id', 'go to next screen - Intro')->click();
		sleep(1);

		# SCREEN 2 /Genotyping Project/
		$t->find_element_ok('next_step_creating_genotyping_plates', 'id', 'go to next screen - Genotyping Project')->click();
		sleep(1);

		# SCREEN 3 /Basic Plate Info/
		$t->find_element_ok('plate_genotyping_project_id', 'id', 'find "genotyping trial facility select" and click')->click();
		sleep(1);

		$t->find_element_ok("//select[\@id=\"plate_genotyping_project_id\"]/option[\@title='$project_name']", 'xpath', "Select $project_name as value for genotyping project facility")->click();

		$t->find_element_ok('genotyping_trial_name', 'id', 'find "genotyping trial name" and click')->send_keys($plate_name);

		$t->find_element_ok('genotyping_trial_plate_format', 'id', 'find "genotyping trial plate format" select and click')->click();
		sleep(1);
		$t->find_element_ok('//select[@id="genotyping_trial_plate_format"]/option[@value="96"]', 'xpath', 'Select "96" as value for genotyping trial plate format')->click();

		$t->find_element_ok('genotyping_trial_plate_sample_type', 'id', 'find "genotyping trial plate sample type" select and click')->click();
		sleep(1);
		$t->find_element_ok('//select[@id="genotyping_trial_plate_sample_type"]/option[@value="DNA"]', 'xpath', 'Select "DNA" as value for plate sample type')->click();

		$t->find_element_ok('genotyping_trial_description', 'id', 'find "genotyping trial description" and fill')->send_keys("Selenium test plate description");
		$t->find_element_ok('plate_info_intro_button', 'id', 'go to next screen - Basic Plate Info')->click();

		# SCREEN 4 /Well Info/
		$t->find_element_ok('genotyping_trial_well_input_option', 'id', 'find "genotyping trial well input" select and click')->click();
		sleep(1);
		$t->find_element_ok('//select[@id="genotyping_trial_well_input_option"]/option[@value="xlsx"]', 'xpath', 'Select "xlsx" as value of trial well input formal (Excel)')->click();
		sleep(2);

		my $file_upload = $t->find_element_ok("genotyping_trial_layout_upload", "id", "find trial file upload button");
		my $filename = $f->config->{basepath} . "/t/data/genotype_trial_upload/$excel_file_name";
		my $remote_filename = $t->driver()->upload_file($filename);
		$file_upload->send_keys($filename);

		$t->find_element_ok('well_info_intro_button', 'id', 'go to next screen - Well Info')->click();
		sleep(1);

		# SCREEN 5 /Trial Linkage/
		$t->find_element_ok('trial_linkage_intro_button', 'id', 'go to next screen - Well Info')->click();
		sleep(1);

		# SCREEN 6 /Confirm/
		$t->find_element_ok('add_geno_trial_submit', 'id', 'find "submit genotyping trial" and click')->click();
		sleep(40);

		$t->driver()->accept_alert();
		$t->find_element_ok('close_trial_button', 'id', 'find "close trial button" and click')->click();
		sleep(3);

        #New genotyping plate ID
        my $genotyping_plate_id = $f->bcs_schema->resultset('Project::Project')->find({ name => $plate_name })->project_id();
        $t->get_ok('/breeders/trial/' . $genotyping_plate_id);
        sleep(5);

        my $trial_table_content = $t->find_element_ok('trial_plate_view_table', 'id', 'find table with created trial data')->get_attribute('innerHTML');
        ok($trial_table_content =~ /\Q${plate_name}_F07/, "Verify sample id in a table: ${plate_name}_F07");
        ok($trial_table_content =~ /\Q${plate_name}_B04/, "Verify sample id in a table: ${plate_name}_B04");
        ok($trial_table_content =~ /test_accession1/, "Verify accession id in a table: test_accession1");

        my $trial_plate_layout = $t->find_element_ok('trial_plate_layout_table', 'id', 'find table with plate layout')->get_attribute('innerHTML');

        ok($trial_table_content =~ /A01/, "Verify well id in a table: A01");
        ok($trial_table_content =~ /A05/, "Verify well id in a table: A05");
    }
});

$t->driver()->close();
done_testing();

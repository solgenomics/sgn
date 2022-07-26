
use strict;

use lib 't/lib';

use Test::More 'tests' => 37;

use Data::Dumper;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
	sleep(1);

	$t->get_ok('/breeders/genotyping');
	sleep(2);

	$t->find_element_ok("create_genotyping_trial_link", "name", "find create genotyping trial link abd click")->click();
	sleep(1);

	# SCREEN 1 /Intro/
	$t->find_element_ok('next_step_intro_button', 'id', 'go to next screen - Intro')->click();
	sleep(1);

	# SCREEN 2 /Basic Plate Info/
	$t->find_element_ok('genotyping_trial_facility_select', 'id', 'find "genotyping trial facility select" and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_trial_facility_select"]/option[@value="None"]', 'xpath', 'Select "None" as value for genotyping trial facility')->click();

	$t->find_element_ok('genotyping_project_name', 'id', 'find "genotyping project name" and click')->send_keys("NEXTGENCASSAVA");

	$t->find_element_ok('genotyping_trial_name', 'id', 'find "genotyping trial name" and click')->send_keys("2018TestPlate02");

	$t->find_element_ok('genotyping_trial_plate_format', 'id', 'find "genotyping trial plate format" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_trial_plate_format"]/option[@value="96"]', 'xpath', 'Select "96" as value for genotyping trial plate format')->click();

	$t->find_element_ok('genotyping_trial_plate_sample_type', 'id', 'find "genotyping trial plate sample type" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_trial_plate_sample_type"]/option[@value="DNA"]', 'xpath', 'Select "DNA" as value for plate sample type')->click();

	$t->find_element_ok('breeding_program_select', 'id', 'find "genotyping breeding program" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="breeding_program_select"]/option[@title="test"]', 'xpath', 'Select "test" as value of breeding program')->click();

	$t->find_element_ok('location_select', 'id', 'find "genotyping trial location" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="location_select"]/option[@title="test_location"]', 'xpath', 'Select "test_location" as value of trial location')->click();

	$t->find_element_ok('year_select', 'id', 'find "genotyping trial year" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="year_select"]/option[@title="2018"]', 'xpath', 'Select "2018" as value of trial year')->click();

	$t->find_element_ok('genotyping_trial_description', 'id', 'find "genotyping trial description" and fill')->send_keys("Selenium test plate description");

	$t->find_element_ok('plate_info_intro_button', 'id', 'go to next screen - Basic Plate Info')->click();

	$t->find_element_ok('genotyping_trial_well_input_option', 'id', 'find "genotyping trial well input" select and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="genotyping_trial_well_input_option"]/option[@value="xls"]', 'xpath', 'Select "xls" as value of trial well input formal (Excel)')->click();

	my $file_upload = $t->find_element_ok("genotyping_trial_layout_upload", "id", "find trial file upload button");
	my $filename = $f->config->{basepath}."/t/data/genotype_trial_upload/NEW_CASSAVA_GS_74Template.xls";
	my $remote_filename = $t->driver()->upload_file($filename);
	$file_upload->send_keys($filename);

	# SCREEN 3 /Well Info/
	$t->find_element_ok('well_info_intro_button', 'id', 'go to next screen - Well Info')->click();
	sleep(1);

	# SCREEN 4 /Trial Linkage/
	$t->find_element_ok('trial_linkage_intro_button', 'id', 'go to next screen - Well Info')->click();
	sleep(1);

	# SCREEN 5 /Confirm/
	$t->find_element_ok('add_geno_trial_submit', 'id', 'find "submit genotyping trial" and click')->click();
	sleep(40);

	$t->driver()->accept_alert();
	$t->find_element_ok('close_trial_button', 'id', 'find "close trial button" and click')->click();
	sleep(3);

	$t->find_element_ok("refresh_genotyping_trial_jstree_html_trialtree_button", "id", "find and click 'refresh genotyping trial jstree'")->click();
	sleep(5);

	$t->find_element_ok('//div[@id="genotyping_trial_list"]//i[contains(@class, "jstree-icon")]', 'xpath', 'open a tree with genotyping trial list')->click();
	sleep(5);

	my $href_to_trial = $t->find_element_ok('//div[@id="genotyping_trial_list"]//a[contains(text(), "2018TestPlate02")]', 'xpath', 'find created trial and take link href')->get_attribute('href');

	$t->get_ok($href_to_trial);
	sleep(5);

	my $trial_table_content = $t->find_element_ok('trial_plate_view_table', 'id', 'find table with created trial data')->get_attribute('innerHTML');

	ok($trial_table_content =~ /2018TestPlate02_F07/, "Verify sample id in a table: 2018TestPlate02_F07");
	ok($trial_table_content =~ /2018TestPlate02_B04/, "Verify sample id in a table: 2018TestPlate02_B04");
	ok($trial_table_content =~ /test_accession1/, "Verify accession id in a table: test_accession1");

	my $trial_plate_layout = $t->find_element_ok('trial_plate_layout_table', 'id', 'find table with plate layout')->get_attribute('innerHTML');

	ok($trial_table_content =~ /A01/, "Verify well id in a table: A01");
	ok($trial_table_content =~ /A05/, "Verify well id in a table: A05");
});

$t->driver()->close();
done_testing();


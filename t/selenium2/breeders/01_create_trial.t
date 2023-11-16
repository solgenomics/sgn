
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("submitter", sub {
	sleep(1);

	$t->get_ok('/breeders/trials');
	sleep(3);

	$t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
	sleep(5);

	my $add_project_link = $t->find_element_ok('add_project_link', 'id', "find add trial link");
	$add_project_link->click();
	sleep(1);

	# SCREEN 1 /Intro/
	$t->find_element_ok('next_step_intro_button', 'id', 'go to next screen - Intro')->click();

	# SCREEN 2 /Trial information/
	$t->find_element_ok('select_breeding_program', 'id', 'find breeding program select and click "test"')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="select_breeding_program"]/option[@value="test"]', 'xpath', "Select 'test' as value for breeding program")->click();

	$t->find_element_ok('//select[@id="add_project_location"]/option[@value="test_location"]',
		'xpath',
		"Select 'test_location' as value for project location")->click();

	my $trail_name = sprintf("Trial_selenium_%d", int(rand(1000)));
	$t->find_element_ok('new_trial_name', 'id', "find new trial name input box")->send_keys($trail_name);

	$t->find_element_ok('add_project_type', 'id', "find project type select list")->click();
	sleep(1);
	$t->find_element_ok('//select[@id="add_project_type"]/option[@title="misc_trial"]', 'xpath', "Select 'test' as value for breeding program")->click();

	$t->find_element_ok('add_project_year', 'id', "find trial year select list")->click();
	sleep(1);
	$t->find_element_ok('//select[@id="add_project_year"]/option[@value="2015"]', 'xpath', "Select '2015' as value for year")->click();

	$t->find_element_ok('add_project_planting_date', 'id', "Set '31/01/2015' as value for planting_date")->send_keys("31/01/2015");

	$t->find_element_ok('add_project_plot_width', 'id', "find trial plot width input")->send_keys("10");
	$t->find_element_ok('add_project_plot_length', 'id', "find trial plot length input")->send_keys("10");
	$t->find_element_ok('new_trial_field_size', 'id', "find trial field size input")->send_keys("5");
	$t->find_element_ok('add_plant_entries', 'id', "find trial plants per plot input")->send_keys("10");

	$t->find_element_ok('add_project_description', 'id', "find project description input box")
		->send_keys("Test trial selenium / description for field test");

	$t->find_element_ok('select_stock_type', 'id', "find trial stock type select input");
	sleep(1);
	$t->find_element_ok('//select[@id="select_stock_type"]/option[@value="accession"]', 'xpath', "find accession value for stock type")->click();

	$t->find_element_ok('select_design_method', 'id', "find field trial description input")->click();
	sleep(1);
	$t->find_element_ok('//select[@id="select_design_method"]/option[@value="CRD"]', 'xpath', "find randomized method of design")->click();

	$t->find_element_ok('create_trial_validate_form_button', 'id', "find form validation button and click")->click();
	sleep(3);

	$t->find_element_ok('button[name="create_trial_submit"]', 'css', "find form submit button and click")->click();
	sleep(3);


	# SCREEN 3 /Design Information/

	$t->find_element_ok('rep_count', 'id', "find trial replicates count input")->send_keys("1");
	sleep(1);

	$t->find_element_ok('show_list_of_accession_section', 'id', "find accessions to include select")->click();
	sleep(1);
	$t->find_element_ok('//option[text()="accessions2add"]', "xpath", "find accession value for list")->click();
	sleep(2);

	$t->find_element_ok('crbd_list_of_checks_section_list_select', 'id', "find accessions to include select")->click();
	sleep(1);
	$t->find_element_ok('//select[@id="crbd_list_of_checks_section_list_select"]//option[@value ="4"]', "xpath", "find checks for list")->click();
	sleep(1);

	$t->find_element_ok('next_step_design_information_button', 'id', 'go to next screen - Design Information')->click();
	sleep(2);

	# SCREEN 4 /Trail Linkage/

	$t->find_element_ok('add_project_trial_sourced', 'id', "find add project trial sourced select")->click();
	$t->find_element_ok('//select[@id="add_project_trial_sourced"]/option[contains(@value, "no")]', "xpath", "select project trial source option as 'no'")->click();

	$t->find_element_ok('add_project_trial_will_be_genotyped', 'id', "find add project trial will be genotyped select")->click();
	$t->find_element_ok('//select[@id="add_project_trial_will_be_genotyped"]/option[contains(@value, "no")]', "xpath", "select project trial will be genotyped option as 'no'")->click();

	$t->find_element_ok('add_project_trial_will_be_crossed', 'id', "find project trial will be crossed select")->click();
	$t->find_element_ok('//select[@id="add_project_trial_will_be_crossed"]/option[contains(@value, "no")]', "xpath", "select project trial will be crossed option as 'no'")->click();

	$t->find_element_ok('next_step_trail_linkage_button', 'id', 'go to next screen - Trail Linkage')->click();
	sleep(1);

	# SCREEN 5 /Field map information/
	$t->find_element_ok('fieldMap_row_number', 'id', "find field map row number input")->send_keys("1");
	$t->find_element_ok('plot_layout_format', 'id', "find plot layout format select")->click();
	$t->find_element_ok('//select[@id="plot_layout_format"]//option[contains(@value, "zigzag")]', "xpath", "find checks for list")->click();

	$t->find_element_ok('next_step_field_map_button', 'id', 'go to next screen - Field map information')->click();
	sleep(1);

	# SCREEN 6 /Custom plot naming/
	$t->find_element_ok('plot_prefix', 'id', "find plot prefix input")->send_keys("prefix_sel_");
	$t->find_element_ok('start_number', 'id', "find plot start number select")->click();
	$t->find_element_ok('//select[@id="start_number"]//option[contains(@value, "101")]', "xpath", "find checks for list")->click();
	$t->find_element_ok('increment', 'id', "find plot number increment input")->send_keys("2");

	$t->find_element_ok('new_trial_submit', 'id', 'go to next screen - Custom plot naming')->click();
	sleep(20);

	# SCREEN 7 /Review design/
	$t->find_element_ok('redo_trial_layout_button', 'id', "find redo randomization and click button")->click();
	sleep(20);

	$t->find_element_ok('new_trial_confirm_submit', 'id', "find new trial confirm and submit")->click();
	sleep(20);

	# Very strange, but the only way to catch the complete trial button. Standard selectors without an extended XPath solution don't work.
	$t->find_element_ok('create_trial_success_complete_button', 'id', "find success button after trial upload to database");
	$t->find_element_ok('//div[@class="panel-body"]//div[@class="workflow-complete-message workflow-message-show"]//center//button[@id="create_trial_success_complete_button"]',
		'xpath', 'click complete button on last screen and finish a modal process')->click();

	sleep(2);

	$t->find_element_ok("refresh_jstree_html", "name", "refresh tree with new trial added")->click();
	sleep(5);

	$t->find_element_ok('//div[@id="trial_list"]//ul[@class="jstree-container-ul jstree-children"]//li//i[@class="jstree-icon jstree-ocl"]',
		'xpath', 'find a plus button to open a tree in test trails')->click();
	sleep(2);

	$t->find_element_ok("//a[contains(text(),\"$trail_name\")]", 'xpath', 'Confirm if trail exists in database and new tree after refresh')->click();
});


$t->driver->close();
done_testing();
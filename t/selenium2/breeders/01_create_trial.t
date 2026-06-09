
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Waiter qw(wait_until);

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("submitter", sub {
	$t->get_ok('/breeders/trials');

	$t->click_ok("refresh_jstree_html", "name", "refresh tree");
	$t->wait_for_working_dialog();

	$t->click_ok('add_project_link', 'id', "find add trial link");

	# SCREEN 1 /Intro/
	$t->click_ok('next_step_intro_button', 'id', 'go to next screen - Intro');

	# SCREEN 2 /Trial information/
	$t->click_ok('select_breeding_program', 'id', 'find breeding program select and click "test"');
	$t->click_ok('//select[@id="select_breeding_program"]/option[@value="test"]', 'xpath', "Select 'test' as value for breeding program");

	$t->click_ok('//select[@id="add_project_location"]/option[@value="test_location"]',
		'xpath',
		"Select 'test_location' as value for project location");

	my $trail_name = sprintf("Trial_selenium_%d", int(rand(1000)));
	$t->send_keys_ok('new_trial_name', 'id', $trail_name, "find new trial name input box");

	$t->click_ok('add_project_type', 'id', "find project type select list");
	$t->click_ok('//select[@id="add_project_type"]/option[@title="misc_trial"]', 'xpath', "Select 'test' as value for breeding program");

	$t->click_ok('add_project_year', 'id', "find trial year select list");
	$t->click_ok('//select[@id="add_project_year"]/option[@value="2015"]', 'xpath', "Select '2015' as value for year");

	$t->send_keys_ok('add_project_planting_date', 'id', "31/01/2015", "Set '31/01/2015' as value for planting_date");

	$t->send_keys_ok('add_project_plot_width', 'id', "10", "find trial plot width input");
	$t->send_keys_ok('add_project_plot_length', 'id', "10", "find trial plot length input");
	$t->send_keys_ok('new_trial_field_size', 'id', "5", "find trial field size input");
	$t->send_keys_ok('add_plant_entries', 'id', "10", "find trial plants per plot input");

	$t->send_keys_ok('add_project_description', 'id', "Test trial selenium / description for field test", "find project description input box");

	$t->find_element_ok('select_stock_type', 'id', "find trial stock type select input");
	$t->click_ok('//select[@id="select_stock_type"]/option[@value="accession"]', 'xpath', "find accession value for stock type");

	$t->click_ok('select_design_method', 'id', "find field trial description input");
	$t->click_ok('//select[@id="select_design_method"]/option[@value="CRD"]', 'xpath', "find randomized method of design");

	$t->click_ok('create_trial_validate_form_button', 'id', "find form validation button and click");

	$t->click_ok('button[name="create_trial_submit"]', 'css', "find form submit button and click");


	# SCREEN 3 /Design Information/

	$t->send_keys_ok('rep_count', 'id', "1", "find trial replicates count input");

	$t->click_ok('show_list_of_accession_section', 'id', "find accessions to include select");
	$t->click_ok('//option[text()="accessions2add"]', "xpath", "find accession value for list");

	$t->click_ok('crbd_list_of_checks_section_list_select', 'id', "find accessions to include select");
	$t->click_ok('//select[@id="crbd_list_of_checks_section_list_select"]//option[@value ="4"]', "xpath", "find checks for list");

	$t->click_ok('next_step_design_information_button', 'id', 'go to next screen - Design Information');

	# SCREEN 4 /Trail Linkage/

	$t->click_ok('add_project_trial_sourced', 'id', "find add project trial sourced select");
	$t->click_ok('//select[@id="add_project_trial_sourced"]/option[contains(@value, "no")]', "xpath", "select project trial source option as 'no'");

	$t->click_ok('add_project_trial_will_be_genotyped', 'id', "find add project trial will be genotyped select");
	$t->click_ok('//select[@id="add_project_trial_will_be_genotyped"]/option[contains(@value, "no")]', "xpath", "select project trial will be genotyped option as 'no'");

	$t->click_ok('add_project_trial_will_be_crossed', 'id', "find project trial will be crossed select");
	$t->click_ok('//select[@id="add_project_trial_will_be_crossed"]/option[contains(@value, "no")]', "xpath", "select project trial will be crossed option as 'no'");

	$t->click_ok('next_step_trail_linkage_button', 'id', 'go to next screen - Trail Linkage');

	# SCREEN 5 /Field map information/
	$t->send_keys_ok('fieldMap_row_number', 'id', "1", "find field map row number input");
	$t->click_ok('plot_layout_format', 'id', "find plot layout format select");
	$t->click_ok('//select[@id="plot_layout_format"]//option[contains(@value, "zigzag")]', "xpath", "find checks for list");

	$t->click_ok('next_step_field_map_button', 'id', 'go to next screen - Field map information');

	# SCREEN 6 /Custom plot naming/
	$t->send_keys_ok('plot_prefix', 'id', "prefix_sel_", "find plot prefix input");
	$t->click_ok('start_number', 'id', "find plot start number select");
	$t->click_ok('//select[@id="start_number"]//option[contains(@value, "101")]', "xpath", "find checks for list");
	$t->send_keys_ok('increment', 'id', "2", "find plot number increment input");

	$t->click_ok('new_trial_submit', 'id', 'go to next screen - Custom plot naming');
	$t->wait_for_working_dialog();

	# SCREEN 7 /Review design/
	$t->click_ok('redo_trial_layout_button', 'id', "find redo randomization and click button");
	$t->wait_for_working_dialog();

	$t->click_ok('new_trial_confirm_submit', 'id', "find new trial confirm and submit");
	$t->wait_for_working_dialog();

	# Very strange, but the only way to catch the complete trial button. Standard selectors without an extended XPath solution don't work.
	$t->find_element_ok('create_trial_success_complete_button', 'id', "find success button after trial upload to database");
	$t->click_ok('//div[@class="panel-body"]//div[@class="workflow-complete-message workflow-message-show"]//center//button[@id="create_trial_success_complete_button"]',
		'xpath', 'click complete button on last screen and finish a modal process');

	$t->click_ok("refresh_jstree_html", "name", "refresh tree with new trial added");

	$t->click_ok('//div[@id="trial_list"]//ul[@class="jstree-container-ul jstree-children"]//li//i[@class="jstree-icon jstree-ocl"]',
		'xpath', 'find a plus button to open a tree in test trails');

	$t->click_ok("//a[contains(text(),\"$trail_name\")]", 'xpath', 'Confirm if trail exists in database and new tree after refresh');
});


$t->driver->close();
done_testing();
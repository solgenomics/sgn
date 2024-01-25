
use strict;

use lib 't/lib';

use Test::More 'tests' => 43;

use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();


$t->while_logged_in_as("submitter", sub {
	sleep(1);

	$t->get_ok('/breeders/crosses');

	$t->find_element_ok("create_crossingtrial_link", "name", 'find "create crossing trial link" and click')->click();
	sleep(1);

	# ADD NEW CROSSING EXPERIMENT
	# SCREEN 1 - Add New Crossing Experiment Intro/ modal
	$t->find_element_ok('next_step_add_new_intro', 'id', 'go to next screen in Add New Experiment modal')->click();

	# SCREEN 2 -  Add New Crossing Experiment Information/ modal
	my $experiment_name = "Selenium_create_cross_trial";
	$t->find_element_ok('crossingtrial_name', 'id', 'find "crossing trial name" input and give a name')->send_keys($experiment_name);

	$t->find_element_ok('crossingtrial_program', 'id', 'find "crossing trial program" select input and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="crossingtrial_program"]/option[text()="test"]', 'xpath', 'select "test" as value for crossing trial program')->click();

	$t->find_element_ok('crossingtrial_location', 'id', 'find "crossing trial location" select input and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="crossingtrial_location"]/option[@value="test_location"]', 'xpath', 'select "test_location" as value for crossing trial location')->click();

	$t->find_element_ok('crosses_add_project_year_select', 'id', 'find "crossing trial year" select input and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="crosses_add_project_year_select"]/option[@value="2018"]', 'xpath', 'select "2018" as value for crossing trial year')->click();

	$t->find_element_ok('crosses_add_project_description', 'id', 'find "crossing trial description" input and give a description')->send_keys("Selenium_create_cross_trial_description");

	$t->find_element_ok('create_crossingtrial_submit', 'id', 'find and click "crossing trial submit" input and give a description')->click();
	sleep(4);

	# check if added successfully
	my $trial_submit_info = $t->find_element_ok(
		'//div[@id="add_crossing_trial_workflow"]//div[contains(@class, "workflow-complete-message")]',
		'xpath',
		'find feedback info after trial submition')->get_attribute('innerHTML');

	ok($trial_submit_info =~ /Crossing experiment was added successfully/, "Verify feedback after submission, looking for: 'Crossing experiment was added successfully'");

	$t->find_element_ok('add_crossing_experiment_dismiss_button_2', 'id', 'find and close "Add New Experiment" modal')->click();
	sleep(1);

	# ADD NEW CROSS
	$t->find_element_ok("create_cross_link", "name", 'find "create cross link" and click')->click();
	sleep(1);

	# SCREEN 1 - Intro
	$t->find_element_ok('next_step_cross_intro', 'id', 'go to next screen in Add New Cross  / Intro')->click();
	sleep(1);

	# SCREEN 2 - Crossing Experiment
	$t->find_element_ok('next_step_cross_experiment', 'id', 'go to next screen in Add New Cross modal / Crossing Experiment')->click();
	sleep(1);

	# SCREEN 3 - Cross Informatio
	$t->find_element_ok('add_cross_breeding_program_id', 'id', 'find "cross breeding program" select input and click')->click();
	sleep(1);
	$t->find_element_ok('//select[@id="add_cross_breeding_program_id"]/option[@title="test"]', 'xpath', 'select "test" as value for breeding program')->click();
	sleep(2);

	$t->find_element_ok('add_cross_crossing_experiment_id', 'id', 'find "crossing trial program" select input and click')->click();
	sleep(1);
	$t->find_element_ok("//select[\@id='add_cross_crossing_experiment_id']/option[\@title='$experiment_name']", 'xpath', "select '$experiment_name' as value for crossing experiment")->click();

	my $cross_unique_name = "selenium_cross_create_123";
	$t->find_element_ok('cross_name', 'id', 'find "cross name" input and create a name')->send_keys($cross_unique_name);

	$t->find_element_ok('dialog_cross_combination', 'id', 'find "cross combination name" input and create a name')->send_keys("TMEB419xTMEB693");

	$t->find_element_ok('cross_type', 'id', 'find "cross type" select input and click')->click();
	sleep(1);
	$t->find_element_ok("//select[\@id='cross_type']/option[\@value='biparental']", 'xpath', "select 'biparental' as value for cross type")->click();

	$t->find_element_ok('next_step_cross_information', 'id', 'go to next screen in Add New Cross modal / Cross Information')->click();
	sleep(1);

	# SCREEN 4 - Basic Information
	$t->find_element_ok('maternal_parent', 'id', 'find "maternal parent" input')->send_keys("TMEB419");

	$t->find_element_ok('paternal_parent', 'id', 'find "paternal parent" input')->send_keys("TMEB693");

	$t->find_element_ok('next_step_basic_information', 'id', 'go to next screen in Add New Cross modal / Basic Information')->click();
	sleep(1);

	# SCREEN 5 - Additional cross info
	$t->find_element_ok('create_cross_submit', 'id', 'find "create cross submit" and click')->click();
	sleep(5);

	my $cross_submit_info = $t->find_element_ok(
		'//div[@id="add_cross_workflow"]//div[contains(@class, "panel-body")]//div[contains(@class, "workflow-complete-message")]',
		'xpath',
		'find feedback info after add cross')->get_attribute('innerHTML');

	ok($cross_submit_info =~ /The cross was added successfully/, "Verify feedback after submission, looking for: 'The cross was added successfully'");

	$t->find_element_ok('new_cross_close_modal', 'id', 'find "new cross close modal" and click')->click();
	sleep(1);

	$t->find_element_ok("refresh_crosses_jstree_html_trialtree_button", "id", "find and click 'refresh crosses trial jstree'")->click();
	sleep(5);

	$t->find_element_ok('//div[@id="crosses_list"]//i[contains(@class, "jstree-icon")]', 'xpath', 'open a tree with crosses trial list')->click();
	sleep(5);

	my $href_to_trial = $t->find_element_ok("//div[\@id='crosses_list']//a[contains(text(), '$experiment_name')]", 'xpath', 'find created cross and take link href')->get_attribute('href');

	# check if added successfully
	$t->get_ok($href_to_trial);
	sleep(3);

	my $cross_table_content = $t->find_element_ok('parent_information', 'id', 'find table with parent information')->get_attribute('innerHTML');

	ok($cross_table_content =~ /TMEB419xTMEB693/, "Verify info in the table: TMEB419xTMEB693");
	ok($cross_table_content =~ /TMEB419/, "Verify info in the table: TMEB419");
	ok($cross_table_content =~ /TMEB693/, "Verify info in the table: TMEB693");
	ok($cross_table_content =~ /biparental/, "Verify info in the table: biparental");

});

$t->driver()->close();
done_testing();

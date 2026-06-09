
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();


$t->while_logged_in_as("submitter", sub {

	$t->get_ok('/breeders/crosses');

	sleep(1); # FIXME Need to wait for click handler to be registered
	$t->click_ok("create_crossingtrial_link", "name", 'find "create crossing trial link" and click');

	# ADD NEW CROSSING EXPERIMENT
	# SCREEN 1 - Add New Crossing Experiment Intro/ modal
	$t->click_ok('next_step_add_new_intro', 'id', 'go to next screen in Add New Experiment modal');

	# SCREEN 2 -  Add New Crossing Experiment Information/ modal
	my $experiment_name = "Selenium_create_cross_trial";
	$t->send_keys_ok('crossingtrial_name', 'id', $experiment_name, 'find "crossing trial name" input and give a name');

	$t->click_ok('crossingtrial_program', 'id', 'find "crossing trial program" select input and click');
	$t->click_ok('//select[@id="crossingtrial_program"]/option[text()="test"]', 'xpath', 'select "test" as value for crossing trial program');

	$t->click_ok('crossingtrial_location', 'id', 'find "crossing trial location" select input and click');
	$t->click_ok('//select[@id="crossingtrial_location"]/option[@value="test_location"]', 'xpath', 'select "test_location" as value for crossing trial location');

	$t->click_ok('crosses_add_project_year_select', 'id', 'find "crossing trial year" select input and click');
	$t->click_ok('//select[@id="crosses_add_project_year_select"]/option[@value="2018"]', 'xpath', 'select "2018" as value for crossing trial year');

	$t->send_keys_ok('crosses_add_project_description', 'id', "Selenium_create_cross_trial_description", 'find "crossing trial description" input and give a description');

	$t->click_ok('create_crossingtrial_submit', 'id', 'find and click "crossing trial submit" input and give a description');

	# check if added successfully
	my $trial_submit_info = $t->get_attribute_ok(
		'//div[@id="add_crossing_trial_workflow"]//div[contains(@class, "workflow-complete-message")]',
		'xpath',
		'innerHTML',
		'find feedback info after trial submition');

	ok($trial_submit_info =~ /Crossing experiment was added successfully/, "Verify feedback after submission, looking for: 'Crossing experiment was added successfully'");

	$t->click_ok('add_crossing_experiment_dismiss_button_2', 'id', 'find and close "Add New Experiment" modal');

	# ADD NEW CROSS
	$t->click_ok("create_cross_link", "name", 'find "create cross link" and click');

	# SCREEN 1 - Intro
	$t->click_ok('next_step_cross_intro', 'id', 'go to next screen in Add New Cross  / Intro');

	# SCREEN 2 - Crossing Experiment
	$t->click_ok('next_step_cross_experiment', 'id', 'go to next screen in Add New Cross modal / Crossing Experiment');

	# SCREEN 3 - Cross Informatio
	$t->click_ok('add_cross_breeding_program_id', 'id', 'find "cross breeding program" select input and click');
	$t->click_ok('//select[@id="add_cross_breeding_program_id"]/option[@title="test"]', 'xpath', 'select "test" as value for breeding program');

	$t->click_ok('add_cross_crossing_experiment_id', 'id', 'find "crossing trial program" select input and click');
	$t->click_ok("//select[\@id='add_cross_crossing_experiment_id']/option[\@title='$experiment_name']", 'xpath', "select '$experiment_name' as value for crossing experiment");

	my $cross_unique_name = "selenium_cross_create_123";
	$t->send_keys_ok('cross_name', 'id', $cross_unique_name, 'find "cross name" input and create a name');

	$t->send_keys_ok('dialog_cross_combination', 'id', "TMEB419xTMEB693", 'find "cross combination name" input and create a name');

	$t->click_ok('cross_type', 'id', 'find "cross type" select input and click');
	$t->click_ok("//select[\@id='cross_type']/option[\@value='biparental']", 'xpath', "select 'biparental' as value for cross type");

	$t->click_ok('next_step_cross_information', 'id', 'go to next screen in Add New Cross modal / Cross Information');

	# SCREEN 4 - Basic Information
	$t->send_keys_ok('maternal_parent', 'id', "TMEB419", 'find "maternal parent" input');

	$t->send_keys_ok('paternal_parent', 'id', "TMEB693", 'find "paternal parent" input');

	$t->click_ok('next_step_basic_information', 'id', 'go to next screen in Add New Cross modal / Basic Information');

	# SCREEN 5 - Additional cross info
	$t->click_ok('create_cross_submit', 'id', 'find "create cross submit" and click');

	my $cross_submit_info = $t->get_attribute_ok(
		'//div[@id="add_cross_workflow"]//div[contains(@class, "panel-body")]//div[contains(@class, "workflow-complete-message")]',
		'xpath',
		'innerHTML',
		'find feedback info after add cross');

	ok($cross_submit_info =~ /The cross was added successfully/, "Verify feedback after submission, looking for: 'The cross was added successfully'");

	$t->click_ok('new_cross_close_modal', 'id', 'find "new cross close modal" and click');

	$t->click_ok("refresh_crosses_jstree_html_trialtree_button", "id", "find and click 'refresh crosses trial jstree'");

	$t->click_ok('//div[@id="crosses_list"]//i[contains(@class, "jstree-icon")]', 'xpath', 'open a tree with crosses trial list');

	my $href_to_trial = $t->get_attribute_ok("//div[\@id='crosses_list']//a[contains(text(), '$experiment_name')]", 'xpath', 'href', 'find created cross and take link href');

	# check if added successfully
	$t->get_ok($href_to_trial);

	my $cross_table_content = $t->get_attribute_ok('parent_information', 'id', 'innerHTML', 'find table with parent information');

	ok($cross_table_content =~ /TMEB419xTMEB693/, "Verify info in the table: TMEB419xTMEB693");
	ok($cross_table_content =~ /TMEB419/, "Verify info in the table: TMEB419");
	ok($cross_table_content =~ /TMEB693/, "Verify info in the table: TMEB693");
	ok($cross_table_content =~ /biparental/, "Verify info in the table: biparental");

});

$t->driver()->close();
done_testing();

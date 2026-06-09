
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';
use SGN::Test::Fixture;
use Selenium::Waiter qw(wait_until);

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

$t->while_logged_in_as("submitter", sub {
  $t->get_ok("/breeders/trials");

  $t->click_ok("refresh_jstree_html", "name", "refresh tree");
  $t->wait_for_network_idle();
  $t->click_ok("jstree-icon", "class", "open up tree");
  $t->wait_for_network_idle();

  $t->click_ok("new_folder_dialog_link", "id", "create new folder");
  $t->wait_for_network_idle();

  # CREATE NEW F1 PARENT FOLDER
  my $random_val = int(rand(1000));
  my $folder_parent_name = sprintf("Selenium_F1_%d", $random_val);

  $t->send_keys_ok("new_folder_name", "id", $folder_parent_name, "pass F1 as new folder name");

  $t->click_ok('button[id="new_folder_submit"]', "css", "create new folder submit");
  $t->click_ok('button[id="close_new_folder_success_dialog"]', "css", "close new folder success dialog");
  $t->wait_for_network_idle();

  $t->click_ok("refresh_jstree_html", "name", "refresh tree");
  $t->wait_for_network_idle();
  $t->click_ok("jstree-icon", "class", "open up tree");
  $t->wait_for_network_idle();

  $t->find_element_ok("//a[contains(text(),\"$folder_parent_name\")]", 'xpath', "Confirm if new $folder_parent_name folder exists after tree refresh");

  $t->click_ok("new_folder_dialog_link", "id", "create new F2 folder");
  $t->wait_for_network_idle();

  # CREATE NEW F2 CHILD FOLDER
  my $folder_child_name = sprintf("Selenium_F2_%d", $random_val);
  $t->send_keys_ok("new_folder_name", "id", [KEYS->{'control'}, 'a'], "find 'new folder name' textbox and ctrl-a");
  $t->send_keys_ok("new_folder_name", "id", KEYS->{'backspace'}, "find 'new folder name' textbox and backspace");
  $t->send_keys_ok("new_folder_name", "id", $folder_child_name, "input F2 as new folder name");

  $t->click_ok('select[id="new_folder_parent_folder_id"]', "css","find and click to open new_folder/parent_folder");

  my $parent_selector = "option[title='$folder_parent_name']";
  my $parent_folder_number = $t->get_attribute_ok($parent_selector, "css","value", "find parent name by title and select parent : $folder_parent_name");
  $t->click_ok($parent_selector, "css","find parent name by title and select parent : $folder_parent_name");

  $t->click_ok('button[id="new_folder_submit"]', "css", "create new folder submit");
  $t->click_ok('button[id="close_new_folder_success_dialog"]', "css", "close new folder success dialog");
  $t->wait_for_network_idle();

  $t->click_ok("refresh_jstree_html", "name", "refresh tree");
  $t->wait_for_network_idle();
  $t->click_ok("jstree-icon", "class", "open up tree");
  $t->wait_for_network_idle();

  # MOVE TRIAL TO F2 FOLDER FROM MODAL WINDOW
  $t->click_ok("open_folder_dialog_link", "id", "place trial in F2");
  $t->wait_for_network_idle();
  $t->click_ok("html_select_folder_for_trial", "id","pass child folder $folder_child_name as folder name");
  $t->wait_for_network_idle();

  my $child_selector = "option[title='$folder_child_name']";
  my $child_folder_number = $t->get_attribute_ok($child_selector, "css","value", "find child folder name by title and select : $folder_child_name");
  $t->click_ok($child_selector, "css","find child folder name by title and select : $folder_child_name");

  $t->click_ok("html_select_trial_for_folder", "id","find select trial for folder pass and click (open)");
  $t->click_ok('option[title="test_trial"]', "css","pass test_trial as trial names");

  $t->click_ok("set_trial_folder", "id", "add trial to folder submit");
  $t->click_ok('button[id="close_set_folder_success_dialog"]', "css", "close set folder success dialog");
  $t->wait_for_network_idle();

  # TEST DELETE OF PARENT FOLDER - SHOULD FAIL
  $t->get_ok("/folder/$parent_folder_number");

  $t->click_ok("delete_folder_button", "id", "delete folder fails because child folder.");
  $t->accept_alert();
  $t->accept_alert();

  $t->click_ok("Folders", "partial_link_text", "go to folder tab");

  # MOVE CHILD FOLDER (F2) FROM PARENT (F1) FOLDER AND DELETE PARENT (F1)
  $t->click_ok("move_folder_dialog_link", "id", "find 'move folder' link and click");
  $t->wait_for_network_idle();

  $t->find_element_ok("move_folder_id", "id","find move folder select and open it");
  $t->click_ok("option[title='$folder_child_name']", "css","pass child folder : $folder_child_name as folder name");
  $t->click_ok("move_folder_submit", "id", "find move folder submit button and click");
  $t->click_ok('button[id="close_move_folder_success_dialog"]', "css", "close move folder success dialog");
  $t->wait_for_network_idle();

  # TEST DELETE OF PARENT FOLDER - SHOULD PASS BECAUSE FOLDER IS EMPTY
  $t->get_ok("/folder/$parent_folder_number");

  $t->click_ok("delete_folder_button", "id", "delete folder");
  $t->accept_alert();
  $t->accept_alert();

  my $check_folder_deleted = $schema->resultset("Project::Project")->find({ project_id => $parent_folder_number});
  ok(!$check_folder_deleted, "folder F1 deleted");

  # MOVE TEST_TRIAL TO ROOT FOLDER
  $t->get_ok("/breeders/trials");

  $t->wait_for_network_idle();
  $t->click_ok("open_folder_dialog_link", "id", "open a 'move trail' modal window to move trial from F2 folder");
  $t->wait_for_network_idle();
  $t->click_ok("html_select_folder_for_trial", "id","pass 'None' (root) folder as folder name");
  $t->click_ok("option[value='0']", "css","find 'None' folder name by value '0' and select");
  $t->click_ok("html_select_trial_for_folder", "id","find select trial for folder pass and click (open)");
  $t->click_ok('option[title="test_trial"]', "css","pass test_trial as trial names");
  $t->click_ok("set_trial_folder", "id", "add trial to folder 'None' and submit button");
  $t->click_ok('button[id="close_set_folder_success_dialog"]', "css", "close set folder success dialog");
  $t->wait_for_network_idle();

  # DELETE F2 FOLDER

  $t->get_ok("/folder/$child_folder_number");

  $t->click_ok("delete_folder_button", "id", "find 'delete folder' button and click");
  $t->accept_alert();
  $t->accept_alert();

  # CHECK IF F2 FOLDER EXISTS
  $check_folder_deleted = $schema->resultset("Project::Project")->find({ project_id => $child_folder_number});
  ok(!$check_folder_deleted, "folder F2 deleted");

});

$t->driver->close();
$f->clean_up_db();
done_testing();

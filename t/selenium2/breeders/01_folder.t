
use strict;

use lib 't/lib';

use Test::More 'tests' => 48;

use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';
use SGN::Test::Fixture;

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

$t->while_logged_in_as("submitter", sub {
    sleep(2);

    $t->get_ok("/breeders/trials");
    sleep(7);

    $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
    sleep(10);

  $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(5);

  $t->find_element_ok("new_folder_dialog_link", "id", "create new folder")->click();

  # CREATE NEW F1 PARENT FOLDER
  my $random_val = int(rand(1000));
  my $folder_parent_name = sprintf("Selenium_F1_%d", $random_val);

  $t->find_element_ok("new_folder_name", "id","pass F1 as new folder name")->send_keys($folder_parent_name);
  sleep(2);

  $t->find_element_ok('button[id="new_folder_submit"]', "css", "create new folder submit")->click();
  sleep(5);

  $t->find_element_ok('button[id="close_new_folder_success_dialog"]', "css", "close new folder success dialog")->click();
  sleep(8);

  $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
  sleep(10);

  $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(5);

  my $page_source = $t->driver->get_page_source();

  $t->find_element_ok("//a[contains(text(),\"$folder_parent_name\")]", 'xpath', "Confirm if new $folder_parent_name folder exists after tree refresh");

  $t->find_element_ok("new_folder_dialog_link", "id", "create new F2 folder")->click();
  sleep(1);

  # CREATE NEW F2 CHILD FOLDER
  my $folder_child_name = sprintf("Selenium_F2_%d", $random_val);
  my $new_folder_field = $t->find_element_ok("new_folder_name", "id","find 'new folder name' textbox and clear a field");
  $new_folder_field->send_keys(KEYS->{'control'}, 'a');
  $new_folder_field->send_keys(KEYS->{'backspace'});
  $t->find_element_ok("new_folder_name", "id","pass F2 as new folder name")->send_keys($folder_child_name);

  $t->find_element_ok('select[id="new_folder_parent_folder_id"]', "css","find and click to open new_folder/parent_folder")->click();
  sleep(1);

  my $parent_elem = $t->find_element_ok("option[title='$folder_parent_name']", "css","find parent name by title and select parent : $folder_parent_name");
  my $parent_folder_number = $parent_elem->get_attribute('value');
  $parent_elem->click();

  $t->find_element_ok('button[id="new_folder_submit"]', "css", "create new folder submit")->click();
  sleep(5);

  $t->find_element_ok('button[id="close_new_folder_success_dialog"]', "css", "close new folder success dialog")->click();
  sleep(7);

  $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
  sleep(5);

  $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);

  # MOVE TRIAL TO F2 FOLDER FROM MODAL WINDOW
  $t->find_element_ok("open_folder_dialog_link", "id", "place trial in F2")->click();
  sleep(1);

  $t->find_element_ok("html_select_folder_for_trial", "id","pass child folder $folder_child_name as folder name")->click();
  sleep(1);

  my $child_elem = $t->find_element_ok("option[title='$folder_child_name']", "css","find child folder name by title and select : $folder_child_name");
  my $child_folder_number = $child_elem->get_attribute('value');
  $child_elem->click();

  $t->find_element_ok("html_select_trial_for_folder", "id","find select trial for folder pass and click (open)")->click();
  $t->find_element_ok('option[title="test_trial"]', "css","pass test_trial as trial names")->click();

  $t->find_element_ok("set_trial_folder", "id", "add trial to folder submit")->click();
  sleep(4);
  $t->find_element_ok('button[id="close_set_folder_success_dialog"]', "css", "close set folder success dialog")->click();
  sleep(2);

  # TEST DELETE OF PARENT FOLDER - SHOULD FAIL
  $t->get_ok("/folder/$parent_folder_number");
  sleep(2);

  $t->find_element_ok("delete_folder_button", "id", "delete folder fails because child folder.")->click();
  $t->driver->accept_alert();
  sleep(2);
  $t->driver->accept_alert();
  sleep(2);

  $t->find_element_ok("Folders", "partial_link_text", "go to folder tab")->click();
  sleep(2);

  # MOVE CHILD FOLDER (F2) FROM PARENT (F1) FOLDER AND DELETE PARENT (F1)
  $t->find_element_ok("move_folder_dialog_link", "id", "find 'move folder' link and click")->click();

  $t->find_element_ok("move_folder_id", "id","find move folder select and open it");
  $t->find_element_ok("option[title='$folder_child_name']", "css","pass child folder : $folder_child_name as folder name")->click();

  $t->find_element_ok("move_folder_submit", "id", "find move folder submit button and click")->click();
  sleep(2);
  $t->find_element_ok('button[id="close_move_folder_success_dialog"]', "css", "close move folder success dialog")->click();

  # TEST DELETE OF PARENT FOLDER - SHOULD PASS BECAUSE FOLDER IS EMPTY
  $t->get_ok("/folder/$parent_folder_number");
  sleep(2);

  $t->find_element_ok("delete_folder_button", "id", "delete folder")->click();
  $t->driver->accept_alert();
  sleep(2);
  $t->driver->accept_alert();

  my $check_folder_deleted = $schema->resultset("Project::Project")->find({ project_id => $parent_folder_number});
  ok(!$check_folder_deleted, "folder F1 deleted");

  # MOVE TEST_TRIAL TO ROOT FOLDER
  $t->get_ok("/breeders/trials");
  sleep(2);

  $t->find_element_ok("open_folder_dialog_link", "id", "open a 'move trail' modal window to move trial from F2 folder")->click();
  sleep(1);

  $t->find_element_ok("html_select_folder_for_trial", "id","pass 'None' (root) folder as folder name")->click();
  sleep(1);

  $t->find_element_ok("option[value='0']", "css","find 'None' folder name by value '0' and select")->click();

  $t->find_element_ok("html_select_trial_for_folder", "id","find select trial for folder pass and click (open)")->click();
  $t->find_element_ok('option[title="test_trial"]', "css","pass test_trial as trial names")->click();

  $t->find_element_ok("set_trial_folder", "id", "add trial to folder 'None' and submit button")->click();
  sleep(4);
  $t->find_element_ok('button[id="close_set_folder_success_dialog"]', "css", "close set folder success dialog")->click();
  sleep(2);

  # DELETE F2 FOLDER

  $t->get_ok("/folder/$child_folder_number");
  sleep(2);

  $t->find_element_ok("delete_folder_button", "id", "find 'delete folder' button and click")->click();
  $t->driver->accept_alert();
  sleep(2);
  $t->driver->accept_alert();
  sleep(2);

  # CHECK IF F2 FOLDER EXISTS
  $check_folder_deleted = $schema->resultset("Project::Project")->find({ project_id => $child_folder_number});
  ok(!$check_folder_deleted, "folder F2 deleted");

});

$t->driver->close();
$f->clean_up_db();
done_testing();

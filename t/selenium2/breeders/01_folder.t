
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

$t->while_logged_in_as("submitter", sub {
  
  $t->get_ok("/breeders/trials");
  sleep(2);
 
  my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
  sleep(3);
  
  my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);
  
  my $add_folder = $t->find_element_ok("new_folder_dialog_link", "id", "create new folder")->click();
  
  my $new_folder_name = $t->find_element_ok("new_folder_name", "id","pass F1 as new folder name")->send_keys("F1");
  
  my $add_folder_submit = $t->find_element_ok("new_folder_submit", "id", "create new folder submit")->click();
  $t->driver->accept_alert();
  sleep(2);
  
  my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
  sleep(3);
  
  my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);

  my $page_source = $t->driver->get_page_source();

  ok($page_source =~ /glyphicon-folder-open/, "check if folder appears");


  my $add_folder = $t->find_element_ok("new_folder_dialog_link", "id", "create new folder")->click();
  sleep(1);
  
  my $new_folder_name = $t->find_element_ok("new_folder_name", "id","pass F2 as new folder name")->send_keys("F2");
  sleep(1);
  my $new_folder_name = $t->find_element_ok("new_folder_parent_folder_id", "id","pass F1 as new folder's parent name")->send_keys("F1");
  
  my $add_folder_submit = $t->find_element_ok("new_folder_submit", "id", "create new folder submit")->click();
  $t->driver->accept_alert();
  sleep(2);
  
  my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
  sleep(3);
  
  my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);
  
  
  my $add_trial = $t->find_element_ok("open_folder_dialog_link", "id", "place trial in F2")->click();
  sleep(1);
  
  my $folder_name = $t->find_element_ok("html_select_folder_for_trial", "id","pass F2 as folder name")->send_keys("F1F2");
  sleep(1);
  my $trial_name = $t->find_element_ok("html_select_trial_for_folder", "id","pass test_trial as trial name")->send_keys("test_trial");
  
  my $trial_submit = $t->find_element_ok("set_trial_folder", "id", "add trial to folder submit")->click();
  $t->driver->accept_alert();
  sleep(2);
  
  my $refresh_tree = $t->find_element_ok("refresh_jstree_html", "name", "refresh tree")->click();
  sleep(3);
  
  #my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  #sleep(2);
  
  $t->get_ok("/folder/145");
  sleep(2);
  
  my $delete_folder = $t->find_element_ok("delete_folder_button", "id", "delete folder fails because child folder.")->click();
  $t->driver->accept_alert();
  sleep(2);
  $t->driver->accept_alert();
  sleep(2);
  
  my $move_folder = $t->find_element_ok("Folders", "partial_link_text", "go to folder tab")->click();

  sleep(2);
  
  my $move_folder = $t->find_element_ok("move_folder_dialog_link", "id", "move folder")->click();
  
  my $folder_name = $t->find_element_ok("move_folder_id", "id","pass F2 as folder name")->send_keys("F1F2");
  
  my $move_folder = $t->find_element_ok("move_folder_submit", "id", "move folder")->click();
  $t->driver->accept_alert();
  
  $t->get_ok("/folder/145");
  sleep(2);
  
  my $delete_folder = $t->find_element_ok("delete_folder_button", "id", "delete folder")->click();
  $t->driver->accept_alert();
  sleep(2);
  $t->driver->accept_alert();
  
  my $check_folder_deleted = $schema->resultset("Project::Project")->find({ project_id => 145});
  ok(!$check_folder_deleted, "folder deleted.");
});

done_testing();

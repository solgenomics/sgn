
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
  
  $t->get_ok("/breeders/trials");
  sleep(2);
  
  my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);
  
  my $add_folder = $t->find_element_ok("new_folder_dialog_link", "id", "create new folder")->click();
  
  my $new_folder_name = $t->find_element_ok("new_folder_name", "id","pass F1 as new folder name")->send_keys("F1");
  
  my $add_folder_submit = $t->find_element_ok("new_folder_submit", "id", "create new folder submit")->click();
  $t->driver->accept_alert();
  sleep(3);
  
  my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);

  my $page_source = $t->driver->get_page_source();

  ok($page_source =~ /glyphicon-folder-open/, "check if folder appears");


  my $add_folder = $t->find_element_ok("new_folder_dialog_link", "id", "create new folder")->click();
  sleep(1);
  
  my $new_folder_name = $t->find_element_ok("new_folder_name", "id","pass F2 as new folder name")->send_keys("F2");
  
  my $new_folder_name = $t->find_element_ok("new_folder_parent_folder_id", "id","pass F1 as new folder's parent name")->send_keys("F1");
  
  my $add_folder_submit = $t->find_element_ok("new_folder_submit", "id", "create new folder submit")->click();
  $t->driver->accept_alert();
  sleep(3);
  
  my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);
  
  
  my $add_trial = $t->find_element_ok("open_folder_dialog_link", "id", "place trial in F2")->click();
  sleep(1);
  
  my $folder_name = $t->find_element_ok("html_select_folder_for_trial", "id","pass F2 as folder name")->send_keys("F2");
  
  my $trial_name = $t->find_element_ok("html_select_trial_for_folder", "id","pass test_trial as trial name")->send_keys("test_trial");
  
  my $trial_submit = $t->find_element_ok("set_trial_folder", "id", "add trial to folder submit")->click();
  $t->driver->accept_alert();
  sleep(3);
  
  my $open_tree = $t->find_element_ok("jstree-icon", "class", "open up tree")->click();
  sleep(2);

});

done_testing();

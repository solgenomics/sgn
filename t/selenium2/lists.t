
use strict;
#use Selenium::Remote::Driver;
use Test::WebDriver tests => qw | no_plan |;

my $d = Test::WebDriver->new(
#    remote_server_addr => $ENV{REMOTE_SERVER_ADDR} || 'localhost',
#    browser_name       => $ENV{BROWSER_NAME} || 'firefox',
    
    );

print STDERR $d->status();
$d->{verbose} = 1;
#print STDERR "Available engines: ".join(",", $d->available_engines())."\n";
$d->get_ok("http://localhost:3000");
$d->get_ok("http://localhost:3000/solpeople/login.pl");
$d->find_element_ok("username", "name", "get username element");
my $username_field = $d->find_element("username", "name");
$username_field->send_keys("lam87\@cornell.edu");
$d->find_element_ok("pd", "name", "find password field test");
my $password_field = $d->find_element("pd", "name");
$password_field->send_keys("******");

$password_field->submit();

$d->find_element_ok("lists_link", "id", "find lists_link");
my $out = $d->find_element("lists_link", "id")->click();

# delete the list should it already exist
#
if ($d->get_page_source() =~ /new_test_list/) { 
    print "DELETE LIST new_test_list... ";
    $d->find_element("delete_list_new_test_list", "id")->click();
    $d->accept_alert();
    sleep(1);

    print "Done.\n";
}
 
sleep(1);

print "Adding new list...\n";

$d->find_element_ok("add_list_input", "id", "find add list input");

my $add_list_input = $d->find_element("add_list_input", "id");
   
$add_list_input->send_keys("new_test_list");

$d->find_element_ok("add_list_button", "id", "find add list button test");

$d->find_element("add_list_button", "id")->click();

print "View new list...\n";

$d->find_element_ok("view_list_new_test_list", "id");
$d->find_element("view_list_new_test_list", "id")->click();

$d->find_element_ok("dialog_add_list_item", "id", "dialog add list item test");
$d->find_element("dialog_add_list_item", "id")->send_keys("element1\nelement2\nelement3\n");

sleep(1);

$d->find_element("dialog_add_list_item_button", "id")->click();

print "Close list content dialog...\n";

$d->accept_alert_ok();
sleep(1);
$d->accept_alert_ok();
sleep(1);
my $button = $d->find_element("close_list_item_dialog", "id");

#print "VALUE: ".$button->get_value()."\n";
$button->click();

print "Delete test list...\n";

$d->find_element("delete_list_new_test_list", "id")->click();

sleep(1);

my $text = $d->get_alert_text_ok();

$d->accept_alert_ok();

sleep(1);

$d->accept_alert_ok();

print "Deleted the list\n";

$d->find_element_ok("close_list_dialog_button", "id");
$d->find_element("close_list_dialog_button", "id")->click();

Test::WebDriver::done_testing();

$d->close();


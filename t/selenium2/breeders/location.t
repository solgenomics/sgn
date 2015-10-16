
use lib 't/lib';

use Test::More 'tests'=>8;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/locations');
    
    my $add_location_link = $t->find_element_ok(
	"add_location_link", 
	"id", 
	"find element add location link as submitter"
	);
    
    $add_location_link->click();
    
    my $location_desc_input = $t->find_element_ok(
	"location_description", 
	"id",
	"find location input test");
    $location_desc_input->send_keys("yet another test location");
    my $longitude = $t->find_element_ok(
	"longitude", 
	"id",
	"find longitude input test");
    $longitude->send_keys("100");
    my $latitude = $t->find_element_ok(
	"latitude",
	"id",
	"find latitude input test");
    $latitude->send_keys("blabla");
    my $submit_button = $t->find_element_ok(
	"new_location_submit",
	"id",
	"find add_new_location_button test");
    $submit_button->click();

    ok($t->driver->get_alert_text() =~ m/must be numbers/i, "enter numbers in latitude test");
    $t->driver->accept_alert();

    $latitude->clear();
    $latitude->send_keys("200");
    $submit_button->click();
    
    ok($t->driver->get_alert_text() =~ m/new location was saved/i, 'new location was saved test');
    
    $t->driver->accept_alert();
    
		       }
    );



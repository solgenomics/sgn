
use strict;

use lib 't/lib';

use Test::More 'tests'=>12;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as(
    "submitter", 
    sub { 
	$t->get_ok('/breeders/crosses');
	
	$t->find_element_ok( 
	    "add_cross_link",
	    "id",
	    "find element add location link as submitter"
	    )->click();

	$t->find_element_ok(
	    "cross_name", "id", "find cross name input element")
	    ->send_keys("test_cross_1");
	
	$t->find_element_ok(
	    "cross_type", "id", "find cross type select element")->click("biparental");

	 $t->find_element_ok(
	     "maternal_parent", "id", "find maternal parent input box")->send_keys("test_accession1");
	
	 $t->find_element_ok(
	     "paternal_parent", "id", "find paternal parent input box")
	     ->send_keys("test_accession2");
	
#	 $t->find_element_ok(
#	     "cross_upload_breeding_program", "id", "find program select")
#	     ->click(134);

#	$t->find_element_ok(
#	    "location", "id", "find location select")
#	    ->click(23);

	$t->find_element_ok(
	    "create_progeny_checkbox", "id", "find create accessions checkbox")
	    ->click();
	
	$t->find_element_ok(
	    "progeny_number", "id", "find progeny number input box")
	    ->send_keys("20");

	$t->find_element_ok(
	    "create_cross_submit","id", "find cross submit button")
	    ->click();
	
	sleep(10);

	$t->find_element_ok(
	    "dismiss_cross_saved_dialog", "id", "find dismiss message button")
	    ->click();

	sleep(5);

	$t->get_ok('/breeders/crosses');
	
	$t->find_element_ok(
	    "test_cross_1", "partial_link_text", "find link for test_cross")->click();

	

		
    });

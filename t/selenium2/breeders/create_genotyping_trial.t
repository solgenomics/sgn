
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as(
    "submitter", 


    sub { 
	$t->get_ok('/breeders/genotyping');
	my $link = $t->find_element_ok("create_genotyping_trial_link", "id", "find creategenotype trial link");
	$link->click();
	sleep(3);

	my $input_name = $t->find_element_ok("genotyping_trial_name", "id", "find genotyping name input element");

	$input_name->send_keys("blablablabla");

	my $input_year = $t->find_element_ok("year_select_div", "id", "find year select");

	$input_year->send_keys("2015");
	
	my $accession_input = $t->find_element_ok("accession_select_box_list_select", "id", "find accession list"); 
	$accession_input->send_keys("test_list");

	my $ok = $t->find_element_ok("genotype_trial_submit_button", "id", "find ok button on submit genotype trial dialog");
	$ok->click();

	sleep(5);

	$t->driver->accept_alert();

	sleep(5);

	ok($t->driver->get_page_source()=~m/A1/, "detail page");
	
    });


done_testing();


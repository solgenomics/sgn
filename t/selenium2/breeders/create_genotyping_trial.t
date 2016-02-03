
use strict;

use lib 't/lib';

use Test::More;

use Data::Dumper;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as(
    "submitter", 


    sub { 
	$t->get_ok('/breeders/genotyping');
	my $link = $t->find_element_ok("create_igd_genotyping_trial_link", "id", "find creategenotype trial link");
	$link->click();
	sleep(5);

	print STDERR $t->driver->get_page_source()."\n";

	##my $input_name = $t->find_element_ok("genotyping_trial_name", "id", "find genotyping name input element");



	#$input_name->send_keys("blablablabla");

	print STDERR "Find year...\n";
	my $input_year = $t->find_element_ok("year_select", "id", "find year select");

	$input_year->send_keys("2015");


#	print STDERR "\n\n\nFind upload...\n\n\n";
	my $file_upload = $t->find_element_ok("igd_genotyping_trial_upload_file", "id", "find trial file upload button");
	my $filename = $f->config->{basepath}."/t/data/genotype_trial_upload/CASSAVA_GS_74Template";
	print STDERR "FILENAME = $filename\n";
	my $remote_filename = $t->driver()->upload_file($filename);
	print STDERR "REMOTE FILENAME = $remote_filename\n";
	$file_upload->send_keys($filename);
	
	print STDERR "Find accession list select...\n";
	my $accession_input = $t->find_element_ok("igd_accession_select_box_list_select", "id", "find accession list"); 
	$accession_input->send_keys("test_list");

	my $ok = $t->find_element_ok("add_igd_geno_trial_submit", "id", "find ok button on submit genotype trial dialog");
	$ok->click();

	sleep(5);

	$t->driver->accept_alert();

	sleep(3);

	#Verify Trial Design

    $t->find_element_ok("trial_accessions_onswitch", "id", "view trial accessions")->click();
    sleep(3);
    $t->find_element_ok("BLANK", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession5", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession1", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession2", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession3", "partial_link_text", "verify accessions");
    $t->find_element_ok("test_accession4", "partial_link_text", "verify accessions");
     $t->find_element_ok("trial_controls_onswitch", "id", "view trial controls")->click();
     sleep(3);
    $t->find_element_ok("trial_plots_onswitch", "id", "view trial plots")->click();
    sleep(3);
    $t->find_element_ok("//div[contains(., 'CASSAVA_GS_74_A01')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'CASSAVA_GS_74_A02')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'CASSAVA_GS_74_A03')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'CASSAVA_GS_74_A04')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'CASSAVA_GS_74_A05')]", "xpath", "veify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'CASSAVA_GS_74_F05_BLANK')]", "xpath", "verify plots")->get_text();

    $t->find_element_ok("trial_plate_layout_onswitch", "id", "view plate layout")->click();
    sleep(3);
    $t->find_element_ok("//div[contains(., 'A01')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'A02')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'A03')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'A04')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'A05')]", "xpath", "verify plots")->get_text();
    $t->find_element_ok("//div[contains(., 'F05')]", "xpath", "verify plots")->get_text();

    sleep(1);
	$t->download_linked_file("genotyping_trial_spreadsheet_link");
	
	sleep(10);
	
    });


done_testing();


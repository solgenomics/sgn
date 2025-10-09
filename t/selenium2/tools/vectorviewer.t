
use strict;

use SGN::Model::Cvterm;

use lib 't/lib';

use Test::More qw | no_plan |;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

# add a stock of type vector
#
my $vector_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema(), "vector_construct", "stock_type")->cvterm_id();

my $vector_data = {
    name => 'pBR322',
    uniquename => 'pBR322',
    type_id => $vector_cvterm_id,
};


$t->while_logged_in_as(
    "submitter", sub {
	
	my $row = $f->bcs_schema()->resultset("Stock::Stock")->find_or_create( $vector_data );
	
	sleep(1);
	
	my $vector_stock_id = $row->stock_id();
	
	sleep(1);
	
	$t->get_ok('/stock/'.$vector_stock_id.'/view');
	
	sleep(4);
	$t->driver->accept_alert();

	sleep(1);

	$t->driver->accept_alert();

	sleep(1);

	print STDERR "Scrolling to top of the section...\n";
	my $element = $t->find_element_ok('stock_literature_annotation_section_onswitch', 'id', 'find element');
	sleep(1);
	
	$t->driver()->execute_script('arguments[0].scrollIntoView(true);', $element);

	sleep(5);

	
	my $open_upload_section = $t->find_element_ok('stock_upload_files_onswitch', 'id', 'open file upload section'); # click to add the pBR322.gb file as an additional file

	sleep(3);
	
	$open_upload_section->click();
	
	sleep(3);
	
	my $open_upload_dialog = $t->find_element_ok('accession_upload_additional_files_link', 'id', 'open upload dialog');
	
#	sleep(1);
	
#	$t->driver()->execute_script('arguments[0].scrollIntoView(true);', $open_upload_dialog);

	sleep(3);
	$open_upload_dialog->click();
	
	sleep(5);


	print STDERR "Clicking on the upload button...\n";
	my $open_file_selector = $t->find_element_ok('accession_upload_additional_file', 'id', 'get file selector element');
	my $filename = $f->config->{basepath}."/t/data/vectorviewer/pBR322.gb";
	
	$t->driver()->upload_file($filename);
	$open_file_selector->send_keys($filename);
	
	sleep(5);
	
	my $submit_file = $t->find_element_ok('accession_upload_additional_file_submit_button', 'id', 'submit file upload!')->click();
	
	sleep(4);
	$t->driver()->accept_alert();
	
	print STDERR "Reloading page...\n";
	$t->driver()->refresh(); # refersh /stock/'.$vector_stock_id.'/view

	sleep(5);
$t->driver->accept_alert();

	sleep(1);

	$t->driver->accept_alert();

	sleep(1);
	
	

	print STDERR "GETTING THE PAGE SOURCE...\n";
	my $page_source = $t->driver->get_page_source();

	sleep(3);
	
	print STDERR "THE PAGE SOURCE IS ".length($page_source)." characters long\n";

	sleep(1);
	
	ok($page_source =~ /BamHI/, "check if BamHI is present");
	ok($page_source =~ /tet/, "check if tet gene is present");

	my $add_feature_button = $t->find_element_ok('open_add_feature_dialog_button', 'id', 'find open_add_feature_dialog_button...');

	sleep(1);
	
	$add_feature_button->click();

	

	sleep(2);
	
	my $feature_name = $t->find_element_ok("feature_name", "id", "find feature_name");
	$feature_name -> send_keys('pffzt');

	my $start_coord = $t->find_element_ok("feature_start_coord", "id", "find start coord");
	$start_coord -> send_keys('2000');

	my $end_coord = $t->find_element_ok("feature_end_coord", "id", "find end coord");
	$end_coord -> send_keys('2500');

	my $orientation = $t->find_element_ok("feature_orientation_select", "id", "find feature_orientation");
	$orientation -> send_keys('R');

	my $feature_color = $t->find_element_ok("feature_color_select", "id", "find feature_color");
	$feature_color->send_keys('lightblue');

	my $submit_botton = $t->find_element_ok("add_feature_data_submit_button", "id", "find submit button");
	$submit_botton->click();

	sleep(2);

	my $save_vector = $t->find_element_ok("saveVector", "id", "find saveVector button");
	$save_vector->click();

	sleep(1);
	
	$t->driver->accept_alert();
	
	sleep(1);

	$t->driver()->refresh();

	$t->driver->accept_alert();
	sleep(1);
	$t->driver->accept_alert();
	sleep(1);
	
	my $page_source = $t->driver->get_page_source();

	sleep(4);

	#print STDERR $page_source;

	
	#ok($page_source =~ /pffzt/, "check if pffzt is present");

	sleep(5);
	
	
	# ..etc
	print STDERR "Done with tests.\n";
    }
    );
    

#$t->driver->close();
done_testing();




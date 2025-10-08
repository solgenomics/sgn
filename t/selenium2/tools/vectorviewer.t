
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

my $row = $f->bcs_schema()->resultset("Stock::Stock")->find_or_create( $vector_data );

my $vector_stock_id = $row->stock_id();

$t->get_ok('/stock/'.$vector_stock_id.'/view');


my $element = $t->find_element_ok('stock_upload_files_offswitch', 'id', 'find element');
$t->execute_script('arguments[0].scrollIntoView(true);', $element);

#my $open_upload_section = $t->find_element_ok('stock_upload_files_offswitch', 'id', 'open file upload section'); # click to add the pBR322.gb file as an additional file

#$open_upload_section->click();

#sleep(1);

my $open_upload_dialog = $t->find_element_ok('accession_upload_additional_files_link', 'id', 'open upload dialog');
$t->execute_script('arguments[0].scrollIntoView(true);', $open_upload_dialog);
$open_upload_dialog->click();

sleep(1);

my $open_file_selector = $t->find_element_ok('accession_upload_additional_file', 'id', 'get file selector element');
my $filename = $f->config->{basepath}."/t/data/vectorviewer/pBR322.gb";

$t->driver()->upload_file($filename);
$open_file_selector->send_keys($filename);

sleep(1);

my $submit_file = $t->find_element_ok('accession_upload_additional_file_submit_button', 'id', 'submit file upload!')->click();

sleep(4);

$t->get_ok('/stock/'.$vector_stock_id.'/view');




print STDERR "EXITING HERE...\n";
exit(1);


# ... 

sleep(5);

#my $example = $t->find_element_ok('input_example', 'id', 'find input example link');
#$example->click();

my $test_sequence = <<SEQ;
>test_sequence
aattcggcaccagtaaattttcccaaaggtttcaaaaatgaaaattttgattttcctaat
aatgtttcttgctatgttgctagtaacaagtgggaataataatctagtagagacaacatg
caagaacacaccaaattataatttgtgtgtgaaaactttgtctttagaca
SEQ

my $input_box = $t->find_element_ok('sequence', 'id', 'find the seq input box');

$input_box->send_keys($test_sequence);

my $submit = $t->find_element_ok('submit_blast_button', 'id', 'find blast submit button');
$submit->click();

sleep(15);

my $elem = $t->driver->find_element('SGN_output', 'id')->get_attribute('innerHTML');
ok(lc($elem) =~ m/query[:\s]*1[\s]*aattcggcaccagtaaattttcccaaaggtttcaaaaatgaaaatttt/, "find aligned seq");

$t->driver->close();
done_testing();




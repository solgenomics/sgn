
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

# add a stock of type vector
#
my $vector_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($t->bcs_schema(), "vector_construct", "stock_property")->cvterm_id();

my $vector_data = {
    name => 'pBR322',
    uniquename => 'pBR322',
    type_id => $vector_cvterm_id,
};

my $row = $t->bcs_schema()->resultset("Stock::Stock")->insert( $vector_data );

my $vector_stock_id = $row->stock_id();

$t->get_ok('/stock/'.$vector_stock_id.'/view');

my $submit = $t->find_element_ok(' ???? '); # click to add the pBR322.gb file as an additional file

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




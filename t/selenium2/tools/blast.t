
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->get_ok('/tools/blast');

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

sleep(10);

my $elem = $t->driver->find_element('SGN_output', 'id')->get_attribute('innerHTML');
ok(lc($elem) =~ m/query[:\s]*1[\s]*aattcggcaccagtaaattttcccaaaggtttcaaaaatgaaaatttt/, "find aligned seq");

done_testing();
$t->driver->close();



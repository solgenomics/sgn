
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->get_ok('/tools/blast');

my $example = $t->find_element_ok('input_example', 'id', 'find input example link');
$example->click();

my $submit = $t->find_element_ok('submit_blast_button', 'id', 'find blast submit button');
$submit->click();

sleep(10);

done_testing();



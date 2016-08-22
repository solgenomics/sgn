
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok('/solgs', 'solgs home page');

sleep(2);

$d->get_ok('/solgs/traits/D', 'index of solgs traits');
$d->find_element_ok('traits_starting_with_index_table', 'id', 'traits starting with index found');


# $d->while_logged_in_as("submitter", sub {


		      
# });


done_testing();

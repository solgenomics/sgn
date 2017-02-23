
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;


$d->while_logged_in_as("submitter", sub {
$d->get_ok('/solgs', 'solgs home page');
sleep(2);
$d->find_element_ok('Select a training population', 'partial_link_text', 'toggle trial search')->click();
sleep(2);
$d->find_element_ok('//table[@id="all_trials_table"]/tbody/tr[1]/td[1]/form/input', 'xpath', 'select trial NaCRRI')->click();
sleep(2);
$d->find_element_ok('//table[@id="all_trials_table"]/tbody/tr[3]/td[1]/form/input', 'xpath', 'select trial Kasese')->click();
sleep(2);
$d->find_element_ok('done_selecting', 'id', 'done selecting')->click();
sleep(2);
$d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
sleep(2);
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(120);
$d->find_element_ok('dry matter content percentage', 'link_text', 'build model')->click();
sleep(20);
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(160);
$d->find_element_ok('run_pca', 'id', 'run pca')->click();
sleep(40);

});
done_testing();

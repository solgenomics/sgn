
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok('/solgs', 'solgs home page');

sleep(2);

$d->find_element_ok('D', 'link_text', 'index of solgs traits')->click();
sleep(3);

#$d->find_element_ok('traits_starting_with_index_table', 'id', 'traits starting with index found');
#sleep(3);
$d->find_element_ok('dry matter content percentage', 'link_text', 'select trait')->click();
sleep(3);
$d->find_element_ok('dry', 'partial_link_text', 'go to trials with trait data page')->click();
sleep(5);

$d->get_ok('/solgs', 'solgs home page');
sleep(3);
$d->find_element_ok('search_trait_form', 'id', 'search trait form');
my $trait_search = $d->find_element_ok('search_trait_entry', 'id', 'search trait form');
$trait_search->send_keys('dry matter content');
$d->find_element_ok('search_trait', 'id', 'submit trait entry')->click();
sleep(3);

$d->driver->go_back();

$d->find_element_ok('Select a training population', 'partial_link_text', 'toggle trial search')->click();
sleep(5);
my $trial_search = $d->find_element_ok('population_search_entry', 'id', 'population search form');
$trial_search->send_keys('trial2 NACRRI');
sleep(5);
$d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
sleep(5);
$d->find_element_ok('trial2', 'partial_link_text', 'click training pop')->click();
sleep(5);
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(5);
$d->find_element_ok('run_pheno_correlation', 'id', 'run pheno correlation')->click();
sleep(10);
$d->find_element_ok('dry matter content percentage', 'link_text', 'build model')->click();
sleep(3);
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(30);

$d->while_logged_in_as("submitter", sub {
    $d->get_ok('/solgs', 'solgs home page');
    $d->find_element_ok('Select a list-based', 'partial_link_text', 'toogle list training pops')->click();
    sleep(5);		      
});


done_testing();

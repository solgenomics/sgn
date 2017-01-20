
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;


$d->while_logged_in_as("submitter", sub {

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
sleep(2);
my $tr_pop_page = $d->driver->get_current_url();
sleep(5);
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(5);

$d->find_element_ok('run_pheno_correlation', 'id', 'run pheno correlation')->click();
sleep(30);
$d->find_element_ok('dry matter content percentage', 'link_text', 'build model')->click();
sleep(3);
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(30);
$d->find_element_ok('run_pca', 'id', 'run pca')->click();
sleep(40);
  
$d->find_element_ok('//select[@id="prediction_genotypes_list_select"]/option[text()="trial2 NaCRRI clones"]', 'xpath', 'select list tr pop')->click();
sleep(10);
$d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list tr pop')->click();
sleep(30);
$d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[2]/td[2]/a', 'xpath', 'select list tr pop')->click();  
sleep(40);
$d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[2]/td[2]/a', 'xpath', 'go sl pop page')->click();  
sleep(40);
$d->find_element_ok('run_pca', 'id', 'run pca')->click();
sleep(40);
$d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
sleep(20);
$d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
sleep(20);

$d->get_ok('/solgs', 'homepage');
$d->find_element_ok('Select a training population', 'partial_link_text', 'toggle trial search')->click();
sleep(5);
$d->find_element_ok('trial2', 'partial_link_text', 'click training pop')->click();
sleep(2);
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(5);
$d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
$d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
$d->find_element_ok('runGS', 'id',  'build multi models')->click();
$d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
sleep(30);
$d->find_element_ok('//table[@id="selection_index_table"]/tbody/tr[1]/td[2]/input', 'xpath', 'rel wt 1st')->send_keys(3);
$d->find_element_ok('//table[@id="selection_index_table"]/tbody/tr[1]/td[4]/input', 'xpath', 'rel wt 2st')->send_keys(5);
$d->find_element_ok('rank_genotypes', 'id',  'calc selection index')->click();
sleep(20);
  
});





done_testing();

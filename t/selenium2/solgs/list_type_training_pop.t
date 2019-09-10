
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;

$d->get_ok('/solgs', 'solgs home page');
sleep(2);

$d->while_logged_in_as("submitter", sub {
    $d->get_ok('/solgs', 'solgs home page');
    $d->find_element_ok('Search for a trait', 'link_text', 'toggle trait search')->click();
    sleep(5);
    $d->find_element_ok('a list-based', 'partial_link_text', 'toogle list training pops')->click();
    sleep(20);
    $d->find_element_ok('//select[@id="list_type_training_pops_list_select"]/option[text()="trial2 NaCRRI plots"]', 'xpath', 'select list tr pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list tr pop')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run pheno correlation')->click();
    sleep(40);
    $d->find_element_ok('Download correlation', 'partial_link_text', 'download correlation')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(5);
    $d->find_element_ok('dry matter content percentage', 'link_text', 'build DM model')->click();
    sleep(30);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click(); 
    sleep(60);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'download pca')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);

    ### list type training population: single trait prediction of trial type selection population
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(5);
  $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[contains(text(), "Predict")]', 'xpath',  'predict trait DMCP')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[text()="DMCP"]', 'xpath',  'check trait DMCP prediction')->click();
    sleep(5);
    
    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;
    
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'download pca')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);

    $d->driver->go_back();
    sleep(3);
    ###list type training population:  single trait prediction of list type selection population
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="trial2 NaCRRI clones"]', 'xpath', 'select list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    
    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;

    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'download pca')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);

    $d->driver->go_back(); ##to triat model page
    sleep(3);
    $d->driver->go_back(); ##to training pop page
    sleep(3);
### list type training population: multiple traits modeling and prediction

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(30);


###list type training population: multi traits prediction of a trial type selection population
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[1]/a[contains(text(), "trial2")]', 'xpath',  'predict trait DMCP')->click(); 
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[text()="DMCP"]', 'xpath',  'check trait DMCP prediction')->click();
    $d->driver->go_back();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[text()="FRW"]', 'xpath',  'check trait DMCP prediction')->click();
    sleep(5);
    
    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;
    
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'download pca')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);

    $d->driver->go_back();
    sleep(5);
##list type training populaltion: multi traits simultenous prediction of list type selection population 
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="trial2 NaCRRI clones"]', 'xpath', 'select list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[1]/td[2]/a[text()="DMCP"]', 'xpath',  'check trait DMCP prediction')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(5);
    $d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[1]/td[2]/a[text()="FRW"]', 'xpath',  'check trait FRW prediction')->click();
    sleep(5);
    
    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;

    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'download pca')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);

    $d->driver->go_back();
    sleep(2);
    ###list type training population: selection index calculation
    $d->find_element_ok('//table[@id="selection_index_table"]/tbody/tr[1]/td[2]/input', 'xpath', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('//table[@id="selection_index_table"]/tbody/tr[1]/td[4]/input', 'xpath', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(20);
    # TO-DO = check listing of all predicted populations  
});


done_testing();

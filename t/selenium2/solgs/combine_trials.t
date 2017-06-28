
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
    $d->find_element_ok('//table[@id="all_trials_table"]/tbody/tr[2]/td[1]/form/input', 'xpath', 'select trial Kasese')->click();
    sleep(2);
    $d->find_element_ok('done_selecting', 'id', 'done selecting')->click();
    sleep(2);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(90);

    ### combined trials training population: single trait modeling and prediction
    $d->find_element_ok('dry matter content percentage', 'link_text', 'build model')->click();
    sleep(20);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);

    ### combined trials training population: single trait prediction of trial type selection population
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(15);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[contains(text(), "Predict")]', 'xpath',  'predict trait DMCP')->click(); 
    sleep(40);
    $d->find_element_ok('no_queue', 'id', 'no job queueing combo')->click();
    sleep(10);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[text()="DMCP"]', 'xpath',  'check trait DMCP prediction')->click();
    sleep(5);

    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;

    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);

    $d->driver->go_back();
    sleep(3);
    ### combined trials training population:  single trait prediction of list type selection population
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="trial2 NaCRRI clones"]', 'xpath', 'select list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);

    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;

    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);

    $d->driver->go_back(); ## to trait model page
    sleep(3);
    $d->driver->go_back(); ## to training pop page
    sleep(3);
    ### combined trials training population:  multiple traits modeling and prediction

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);


    ### combined trials training population: multi traits prediction of a trial type selection population
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[1]/a[contains(text(), "trial2")]', 'xpath', 'multi traits sel pred')->click(); 
 
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[text()="DMCP"]', 'xpath',  'check trait DMCP prediction')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('//table[@id="selection_pops_list"]/tbody/tr[1]/td[4]/a[text()="FRW"]', 'xpath',  'check trait DMCP prediction')->click();
    sleep(5);
    
    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;

    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);
    $d->driver->go_back();
    sleep(3);

    ### combined trials training population: multi traits simultenous prediction of list type selection population 

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="trial2 NaCRRI clones"]', 'xpath', 'select list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(10);
    $d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[1]/td[2]/a[text()="DMCP"]', 'xpath',  'check trait DMCP prediction')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(5);
    $d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[1]/td[2]/a[text()="FRW"]', 'xpath',  'check trait FRW prediction')->click();
    sleep(5);
    
    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/pca`;

    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
    $d->find_element_ok('Download PCA', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(3);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);

    $d->driver->go_back();
    sleep(3);
    ### combined trials training population: selection index calculation
    $d->find_element_ok('//table[@id="selection_index_table"]/tbody/tr[1]/td[2]/input', 'xpath', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('//table[@id="selection_index_table"]/tbody/tr[1]/td[4]/input', 'xpath', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('rank_genotypes', 'id',  'calc selection index')->click();

    # TO-DO = check listing of all predicted populations

    sleep(20);


});
done_testing();

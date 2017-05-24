
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
    $d->find_element_ok('dry matter content percentage', 'link_text', 'build DM model')->click();
    sleep(30);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click(); $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(60);

    $d->find_element_ok('//select[@id="prediction_genotypes_list_select"]/option[text()="trial2 NaCRRI clones"]', 'xpath', 'select list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(20);
    $d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[2]/td[2]/a', 'xpath', 'select list sel pop')->click();  
    sleep(20);
    $d->find_element_ok('//table[@id="uploaded_selection_pops_table"]/tbody/tr[2]/td[2]/a', 'xpath', 'go sl pop page')->click();  
    sleep(60);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(60);
    $d->find_element_ok('compare_gebvs', 'id', 'compare gebvs')->click();
    sleep(20);
    $d->find_element_ok('normalLegend', 'id', 'gebvs plot gebvs legend');
    sleep(20);



    ###list of trials####
    $d->get_ok('/solgs', 'solgs home page');
    $d->find_element_ok('a list-based', 'partial_link_text', 'toogle list training pops')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="list_type_training_pops_list_select"]/option[text()="Trials list"]', 'xpath', 'select list trials pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list trials pop')->click();
    sleep(30);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    $d->find_element_ok('dry matter content percentage', 'link_text', 'build combined DM model')->click();
    sleep(30);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(60);
});


done_testing();

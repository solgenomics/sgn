
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

`rm -r /tmp/localhost/`;

$d->while_logged_in_as("submitter", sub {

    $d->get_ok('/pca/analysis', 'pca home page');
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', 'geno pca job')->send_keys('Geno pca job');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(80);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(5);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno  pca plot')->click();
    sleep(5);

    `rm -r /tmp/localhost/`;
    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno  pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="60 plots nacrri"]', 'xpath', 'plots list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="Trials list"]', 'xpath', 'select clones list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno  pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="Trials list"]', 'xpath', 'plots list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    `rm -r /tmp/localhost/`;

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="two trials dataset"]', 'xpath', 'trials dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(3);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(180);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="two trials dataset"]', 'xpath', 'trials dt')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(3);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

    `rm -r /tmp/localhost/`;

    $d->get_ok('/breeders/trial/139', 'trial detail home page');
    sleep(10);

    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis')->click();
    sleep(5);
    $d->find_element_ok('ANOVA', 'partial_link_text', 'expand PCA')->click();
    sleep(1);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand PCA')->click();
    sleep(1);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(10);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(70);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('correlation', 'partial_link_text', 'collapse correlation')->click();
    sleep(3);
    $d->find_element_ok('ANOVA', 'partial_link_text', 'collapse anova')->click();
    sleep(3);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand PCA')->click();
    sleep(1);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(70);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno pca plot')->click();
    sleep(5);

    `rm -r /tmp/localhost/`;

    $d->get_ok('/solgs', 'solgs homepage');
    sleep(10);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'Test Kasese Tr pop')->send_keys('Test Kasese Tr pop');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(80);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'Test DMCP model Kasese')->send_keys('Test DMCP model Kasese');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(7);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(5);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(70);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(3);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select genotype')->click();
    sleep(5);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(70);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(10);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', ' sel pred job queueing')->send_keys('Test DMCP selection pred Kasese');
    sleep(3);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(3);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(180);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(8);
    $d->find_element_ok('DMCP', 'partial_link_text', 'go back')->click();
    sleep(5);

    # $d->get_ok('/solgs/selection/141/model/139/trait/70666/gp/1', 'selection prediction page');
    # sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

    `rm -r /tmp/localhost/`;

    $d->get_ok('/solgs', 'solgs homepage');
    sleep(4);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('nacrri');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(3);

    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(2);
    $d->find_element_ok('done_selecting', 'id', 'done selecting')->click();
    sleep(2);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'combo trials tr pop')->send_keys('combo trials tr pop');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(80);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);


    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('nacrri');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);

    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(3);
    $d->find_element_ok('done_selecting', 'id', 'done selecting')->click();
    sleep(3);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(20);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'Test DMCP model combo')->send_keys('Test DMCP model combo');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(120);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(7);


    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geeno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(4);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(20);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click sel pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(4);
    $d->find_element_ok('analysis_name', 'id', 'Test DMCP selection pred nacrri')->send_keys('Test DMCP selection pred nacrri');
    sleep(4);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(3);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(160);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(8);
    $d->find_element_ok('DMCP', 'partial_link_text', 'go back')->click();
    sleep(5);

    # $d->get_ok('/solgs/selection/141/model/139/trait/70666/gp/1', 'selection prediction page');
    # sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="pca_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('run_pca', 'id', 'run PCA')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot')->click();
    sleep(5);

});


done_testing();


use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Test::solGSData;


my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

my $solgs_data = SGN::Test::solGSData->new({'fixture' => $f, 'accessions_list_subset' => 60, 'plots_list_subset' => 60});
my $cache_dir = $solgs_data->site_cluster_shared_dir();
print STDERR "\nsite_cluster_shared_dir-- $cache_dir\n";

my $accessions_list =  $solgs_data->load_accessions_list();
my $accessions_list_name = $accessions_list->{list_name};
my $accessions_list_id = $accessions_list->{list_id};

my $plots_list =  $solgs_data->load_plots_list();
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = $plots_list->{list_id};
print STDERR "\nadding trials list\n";
my $trials_list =  $solgs_data->load_trials_list();
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = $trials_list->{list_id};
print STDERR "\nadding trials dataset\n";
my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = $trials_dt->{dataset_id};
print STDERR "\nadding accessions dataset\n";
my $accessions_dt = $solgs_data->load_accessions_dataset();
my $accessions_dt_name = $accessions_dt->{dataset_name};
my $accessions_dt_id = $accessions_dt->{dataset_id};

print STDERR "\nadding plots dataset\n";
my $plots_dt = $solgs_data->load_plots_dataset();
my $plots_dt_name = $plots_dt->{dataset_name};
my $plots_dt_id = $plots_dt->{dataset_id};

print STDERR "\ntrials dt: $trials_dt_name -- $trials_dt_id\n";
print STDERR "\naccessions dt: $accessions_dt_name -- $accessions_dt_id\n";
print STDERR "\nplots dt: $plots_dt_name -- $plots_dt_id\n";

print STDERR "\ntrials list: $trials_list_name -- $trials_list_id\n";
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
print STDERR "\nplots list: $plots_list_name -- $plots_list_id\n";

`rm -r $cache_dir`;

$d->while_logged_in_as("submitter", sub {

    $d->get_ok('/pca/analysis', 'pca home page');
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $accessions_list_name. '"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run pca')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'queue pca job')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', 'clones list job name')->send_keys('Geno pca job');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(140);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back to pca pg')->click();
    sleep(3);

   $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $accessions_list_name. '"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run pca accessions list (genotype)')->click();
    sleep(5);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check accessions list geno  pca plot')->click();
    sleep(5);

    `rm -r $cache_dir`;
    $d->driver->refresh();
    sleep(5);

   $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $accessions_list_name. '"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(140);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check accessions list geno  pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="'. $plots_list_name . '"]', 'xpath', 'plots list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(140);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check plots list pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $trials_list_name . '"]', 'xpath', 'select clones list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(140);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check trials list geno  pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

   $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $trials_list_name . '"]', 'xpath', 'select trials list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check trials list pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    `rm -r $cache_dir`;

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'accessions dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check accessions dataset geno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $plots_dt_name . '"]', 'xpath', 'plots dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check plots dataset  pheno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);


    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $trials_dt_name . '"]', 'xpath', 'trials dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(180);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check trials dataset geno pca plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="pca_pops_list_select"]/option[text()="' . $trials_dt_name . '"]', 'xpath', 'trials dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check trials dataset pheno pca plot')->click();
    sleep(5);

    `rm -r $cache_dir`;

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
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(10);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check trial page pheno pca plot')->click();
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
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check trials page geno pca plot')->click();
    sleep(5);

    `rm -r $cache_dir`;

    $d->get_ok('/solgs', 'solgs homepage');
    sleep(10);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
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
    sleep(100);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back to solgs homepage')->click();
    sleep(3);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'modeling job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'modeling analysis name')->send_keys('Test DMCP model Kasese');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back to training pop page')->click();
    sleep(7);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model -- go to model page')->click();
    sleep(3);
    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno pca plot in model page')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(3);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select genotype')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot in model page')->click();
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
    $d->find_element_ok('analysis_name', 'id', ' sel pred analysis name')->send_keys('Test DMCP selection pred Kasese');
    sleep(3);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(3);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(100);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back to model page')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(8);
    $d->find_element_ok('DMCP', 'partial_link_text', 'go to selection pop prediction page')->click();
    sleep(5);

    # $d->get_ok('/solgs/selection/141/model/139/trait/70666/gp/1', 'selection prediction page');
    # sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno pca plot in selection pop page')->click();
    sleep(5);

    `rm -r $cache_dir`;

    $d->get_ok('/solgs', 'solgs homepage');
    sleep(4);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
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
    $d->find_element_ok('queue_job', 'id', 'submit combine trials job ')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'combo trials tr pop')->send_keys('combo trials tr pop');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(100);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back to solgs homepage')->click();
    sleep(3);


    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
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
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials -- go to combined trials training pop page')->click();
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
    sleep(140);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back to training pop page')->click();
    sleep(7);


    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(2);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno pca plot in model page')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(4);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(10);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check pheno pca plot in model page')->click();
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
    $d->find_element_ok('analysis_name', 'id', 'selection pop prediction analysis name')->send_keys('Test DMCP selection pred nacrri');
    sleep(4);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(3);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(160);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back to model page')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(8);
    $d->find_element_ok('DMCP', 'partial_link_text', 'go to selection pop prediction page')->click();
    sleep(5);

    # $d->get_ok('/solgs/selection/141/model/139/trait/70666/gp/1', 'selection prediction page');
    # sleep(5);

    my $pca = $d->find_element('PCA', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $pca);
    sleep(5);
    $d->find_element_ok('PCA', 'partial_link_text', 'expand pca')->click();
    sleep(3);
    $d->find_element_ok('//select[starts-with(@id,"pca_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(10);
    $d->find_element_ok('//*[starts-with(@id, "run_pca")]', 'xpath', 'run_pca')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(100);
    $d->find_element_ok('//*[contains(text(), "PC2")]', 'xpath', 'check geno pca plot in selection pop page')->click();
    sleep(5);

});

foreach my $list_id ($trials_list_id, $accessions_list_id, $plots_list_id) {
    $solgs_data->delete_list($list_id);
}

foreach my $dataset_id ($trials_dt_id, $accessions_dt_id, $plots_dt_id) {
    $solgs_data->delete_dataset($dataset_id);
}



done_testing();

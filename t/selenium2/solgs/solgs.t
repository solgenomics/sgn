
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Test::solGSData;
use Config::Any;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

my $solgs_data = SGN::Test::solGSData->new({'fixture' => $f, 'accessions_list_subset' => 60, 'plots_list_subset' => 60});
my $cache_dir = $solgs_data->site_cluster_shared_dir();
print STDERR "\nsite_cluster_shared_dir-- $cache_dir\n";


my $accessions_list =  $solgs_data->load_accessions_list();
# my $accessions_list = $solgs_data->get_list_details('accessions');
my $accessions_list_name = $accessions_list->{list_name};
my $accessions_list_id = $accessions_list->{list_id};
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
my $plots_list =  $solgs_data->load_plots_list();
# my $plots_list =  $solgs_data->get_list_details('plots');
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = $plots_list->{list_id};
print STDERR "\nadding trials list\n";
my $trials_list =  $solgs_data->load_trials_list();
# my $trials_list =  $solgs_data->get_list_details('trials');
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = $trials_list->{list_id};
print STDERR "\nadding trials dataset\n";
# my $trials_dt =  $solgs_data->get_dataset_details('trials');
my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = $trials_dt->{dataset_id};
print STDERR "\nadding accessions dataset\n";
# my $accessions_dt =  $solgs_data->get_dataset_details('accessions');
my $accessions_dt = $solgs_data->load_accessions_dataset();
my $accessions_dt_name = $accessions_dt->{dataset_name};
my $accessions_dt_id = $accessions_dt->{dataset_id};

print STDERR "\nadding plots dataset\n";
# my $plots_dt =  $solgs_data->get_dataset_details('plots');
my $plots_dt = $solgs_data->load_plots_dataset();
my $plots_dt_name = $plots_dt->{dataset_name};
my $plots_dt_id = $plots_dt->{dataset_id};

#$accessions_dt_name = 'Dataset Kasese Clones';
print STDERR "\ntrials dt: $trials_dt_name -- $trials_dt_id\n";
print STDERR "\naccessions dt: $accessions_dt_name -- $accessions_dt_id\n";
print STDERR "\nplots dt: $plots_dt_name -- $plots_dt_id\n";

print STDERR "\ntrials list: $trials_list_name -- $trials_list_id\n";
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
print STDERR "\nplots list: $plots_list_name -- $plots_list_id\n";


`rm -r $cache_dir`;
sleep(5);

$d->while_logged_in_as("submitter", sub {
    sleep(2);
    $d->get('/solgs', 'solgs home page');
    sleep(4);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('Test Kasese Tr pop');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(90);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);
 
    $d->find_element_ok('Genotype data', 'partial_link_text',  'download training pop genotype data');
    sleep(3);
    $d->find_element_ok('Phenotype data', 'partial_link_text',  'download training pop phenotype data');
    sleep(3);
    sleep(3);
   # #  #trial type training population: single trait modeling

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP model Kasese');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(7);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(15);
    
    my $sel_pred = $d->find_element('Model accuracy statistics', 'partial_link_text', 'scroll to accuracy');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(2);
    $d->find_element_ok('Download model accuracy', 'partial_link_text',  'download accuracy');
    sleep(3);

    my $sel_pred = $d->find_element('GEBVs vs observed', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $sel_pred);
    sleep(2);
    $d->find_element_ok('download_gebvs_histo_plot', 'id',  'download gebvs');
    sleep(3);

	my $sel_pred = $d->find_element('GEBVs vs observed', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(120);
	$d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);

    $d->driver->go_back();
    sleep(15);

    my $sel_pred = $d->find_element('Marker effects', 'partial_link_text', 'scroll to marker effects');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $sel_pred);
    sleep(2);
    $d->find_element_ok('Marker effects', 'partial_link_text', 'expand marker effects')->click();
    sleep(2);
    $d->find_element_ok('Download marker', 'partial_link_text',  'download marker effects');
    sleep(3);

    my $download = $d->find_element('Download data', 'partial_link_text', 'download model data section');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $download);
    sleep(2);
    $d->find_element_ok('Genotype data', 'partial_link_text',  'download model genotype data');
    sleep(3);
    $d->find_element_ok('Phenotype data', 'partial_link_text',  'download model phenotype data');
    sleep(3);
    $d->find_element_ok('Analysis log', 'partial_link_text',  'download analysis log');
    sleep(3);
    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(30);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('Test DMCP selection pred Kasese');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(180);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(8);
    $d->find_element_ok('DMCP', 'partial_link_text', 'go back')->click();
    sleep(5);
    
	my $sel_pred = $d->find_element('Check Expected Genetic Gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
    sleep(2);
    $d->find_element_ok('Genotype data', 'partial_link_text',  'download selection pop genotype data');
    sleep(3);
    $d->find_element_ok('Analysis log', 'partial_link_text',  'download analysis log');
    sleep(3);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(120);
	$d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);
    
    $d->driver->go_back();
    sleep(15);

    $d->driver->go_back();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_list_name. '"]', 'xpath', 'select clones list')->click();
    sleep(15);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('clones list sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(10);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_list_name. '"]',  'xpath', 'select list sl pop')->click();
    sleep(15);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(15);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "DMCP")]', 'xpath', 'click list sel pred')->click();
    sleep(10);

	my $sel_pred = $d->find_element('Check Expected Genetic Gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(80);
	$d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);

    $d->driver->go_back();
    sleep(15);

    $d->driver->go_back();
    sleep(5);

#####################
	# $d->get('/solgs/trait/70741/population/139/gp/1');
	# sleep(5);
#####################

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(12);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'dataset')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]/tbody/tr/td/a[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(2);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('dataset clones sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select list sl pop')->click();
     sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]/tbody/tr/td/a[contains(text(), "DMCP")]', 'xpath', 'click list sel pred')->click();
    sleep(10);

	my $sel_pred = $d->find_element('Check Expected Genetic Gain', 'partial_link_text', 'scroll to GEBvs');
	my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
	sleep(2);
	$d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
	sleep(80);
	$d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
	sleep(20);

	$d->driver->go_back();
	sleep(15);

    $d->driver->refresh();
    sleep(3);

      $d->find_element_ok('Kasese solgs trial', 'partial_link_text', 'back to model page')->click();
    sleep(5);
	$d->find_element_ok('Kasese solgs trial', 'partial_link_text', 'back to training pop page')->click();
	sleep(5);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('Test DMCP-FRW modeling  Kasese');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

#####################
	# $d->get('/solgs/population/139/gp/1');
	# sleep(5);
#####################

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(5);


    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('Test DMCP-FRW selection pred naccri');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "FRW")]', 'xpath', 'go back')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(6);

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_list_name. '"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('clones list dmc-frw sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_list_name. '"]',  'xpath', 'list sl page')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "FRW")]', 'xpath', 'click list sel pred')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select list sl pop')->click();
     sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('dataset clones sel pred2');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'dataset')->click();
     sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "FRW")]', 'xpath', 'dataset dmcp-frw pred')->click();
    sleep(10);

    foreach my $list_id ($trials_list_id, $accessions_list_id, $plots_list_id) {
        $solgs_data->delete_list($list_id);
    }

    foreach my $dataset_id ($trials_dt_id, $accessions_dt_id, $plots_dt_id) {
        $solgs_data->delete_dataset($dataset_id);
    }




});



done_testing();

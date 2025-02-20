
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Test::solGSData;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

my $solgs_data = SGN::Test::solGSData->new({
    'fixture' => $f, 
    'accessions_list_subset' => 60, 
    'plots_list_subset' => 60,
    'user_id' => 40,
});

my $cache_dir = $solgs_data->site_cluster_shared_dir();

my $accessions_list =  $solgs_data->load_accessions_list();
my $accessions_list_name = $accessions_list->{list_name};
my $accessions_list_id = 'list_' . $accessions_list->{list_id};

my $plots_list =  $solgs_data->load_plots_list();
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = 'list_' . $plots_list->{list_id};

my $trials_list =  $solgs_data->load_trials_list();
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = 'list_' . $trials_list->{list_id};

my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = 'dataset_' . $trials_dt->{dataset_id};

my $accessions_dt = $solgs_data->load_accessions_dataset();
my $accessions_dt_name = $accessions_dt->{dataset_name};
my $accessions_dt_id = 'dataset_' . $accessions_dt->{dataset_id};

my $plots_dt = $solgs_data->load_plots_dataset();
my $plots_dt_name = $plots_dt->{dataset_name};
my $plots_dt_id = 'dataset_' . $plots_dt->{dataset_id};

print STDERR "\ntrials dt: $trials_dt_name -- $trials_dt_id\n";
print STDERR "\naccessions dt: $accessions_dt_name -- $accessions_dt_id\n";
print STDERR "\nplots dt: $plots_dt_name -- $plots_dt_id\n";

print STDERR "\ntrials list: $trials_list_name -- $trials_list_id\n";
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
print STDERR "\nplots list: $plots_list_name -- $plots_list_id\n";


`rm -r $cache_dir`;


$d->while_logged_in_as("submitter", sub {
    $d->get_ok('/solgs', 'solgs home page');
    sleep(2);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(2);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 nacrri');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(5);

    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(2);
    $d->find_element_ok('select_trials_btn', 'id', 'done selecting')->click();
    sleep(2);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('combined trials');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);


    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(2);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(3);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 nacrri');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(5);

    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(3);
    $d->find_element_ok('select_trials_btn', 'id', 'done selecting')->click();
    sleep(3);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(20);

# $d->get('/solgs/populations/combined/2804608595/gp/1', 'combo trials tr pop page');
   # sleep(4);

    $d->find_element_ok('Genotype data', 'partial_link_text',  'download training pop genotype data');
    sleep(3);
    $d->find_element_ok('Phenotype data', 'partial_link_text',  'download training pop phenotype data');
    sleep(3);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('Test DMCP model combo');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(350);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(40);

    ### combined trials training population: single trait prediction of trial type selection population

    #$d->get('/solgs/model/combined/populations/2804608595/trait/70741/gp/1', 'combo trials tr pop page');
   # sleep(2);

   my $sel_pred = $d->find_element('Model accuracy statistics', 'partial_link_text', 'scroll to accuracy');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(2);
    $d->find_element_ok('Download model accuracy', 'partial_link_text',  'download accuracy');
    sleep(3);

    my $sel_pred = $d->find_element('GEBVs vs observed', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $sel_pred);
    sleep(5);
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
    $d->find_element_ok('Download marker', 'partial_link_text',  ' download marker effects');
    sleep(3);

    my $download = $d->find_element('Download data', 'partial_link_text', 'download model data section');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $download);
    sleep(2);
    $d->find_element_ok('Genotype data', 'partial_link_text',  'download model genotype data');
    sleep(3);
    $d->find_element_ok('Phenotype data', 'partial_link_text',  'download model phenotype data');
    sleep(3);

	my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
	my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
	$d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 NaCRRI');
	sleep(5);
	$d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
	sleep(100);
	$d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
	sleep(5);
	$d->find_element_ok('queue_job', 'id', 'job queueing')->click();
	sleep(2);
	$d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('Test DMCP selection pred combo trials model');
	sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
	$d->find_element_ok('submit_job', 'id', 'submit')->click();
	sleep(360);
	$d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
	sleep(5);

	my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
	my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
	sleep(5);
	$d->find_element_ok('DMCP', 'partial_link_text', 'go back')->click();
	sleep(5);

	my $sel_pred = $d->find_element('Expected genetic gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(120);
    $d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);
    $d->driver->go_back();
    sleep(15);
	$d->driver->go_back();

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('clones list sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);

    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(3);
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "DMCP")]', 'xpath', 'click list sel pred')->click();
    sleep(10);

	my $sel_pred = $d->find_element('Expected genetic gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(120);
    $d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);

    $d->driver->go_back();
    sleep(15);
	$d->driver->go_back();
	sleep(10);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'dataset accession sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('dataset clones sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'dataset accessions sel pred')->click();
    sleep(3);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "DMCP")]', 'xpath', 'dataset accessions sel pred')->click();
    sleep(10);

#$d->get('/solgs/combined/model/2804608595/selection/dataset_5/trait/70741/gp/1', 'combo trials tr pop page');

	my $sel_pred = $d->find_element('Expected genetic gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(120);
    $d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);

    $d->driver->go_back();
    sleep(5);
    # $d->driver->go_back();
	# sleep(10);
    # $d->driver->go_back();
	# sleep(10);
	$d->find_element_ok('Training population 280', 'partial_link_text', 'back to model page')->click();
    sleep(5);
	$d->find_element_ok('Training population 280', 'partial_link_text', 'back to training pop page')->click();
	sleep(5);

    #$d->get('/solgs/populations/combined/2804608595/gp/1', 'combo trials tr pop page');

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('Test DMCP-FRW modeling combo trials');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(3);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(5);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(20);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('Test DMCP-FRW selection pred naccri');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

	#$d->get_ok('/solgs/models/combined/trials/2804608595/traits/1971973596/gp/1');

	sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "FRW")]', 'xpath', 'go back')->click();
    sleep(5);
	$d->driver->go_back();
	sleep(3);

    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('clones list dmc-frw sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);

    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(3);
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "FRW")]', 'xpath', 'click list sel pred')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('dataset clones sel pred2');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(3);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "FRW")]', 'xpath', 'click list sel pred')->click();
    sleep(10);

    `rm -r $cache_dir`;

    $d->get_ok('/solgs', 'solgs home page');
    sleep(2);

    my $tr_search= $d->find_element('search for a trait', 'partial_link_text', 'scroll trait search');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $tr_search);
    sleep(5);
    $d->find_element_ok('search for a trait', 'partial_link_text', 'trait search')->click();
    sleep(5);
    $d->find_element_ok('search_trait_entry', 'id', 'trait search form')->send_keys('dry matter');
    sleep(5);
    $d->find_element_ok('search_trait', 'id', 'search for gs trait')->click();
    sleep(5);
    $d->find_element_ok('dry matter', 'partial_link_text', 'trait earch results')->click();
    sleep(10);


    $d->find_element_ok('//table[@id="all_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="all_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(2);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('combined trait trials');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);


    $d->find_element_ok('//table[@id="all_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="all_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(2);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(5);

    foreach my $list_id ($trials_list_id, $accessions_list_id, $plots_list_id) {
        $list_id =~ s/\w+_//g;
        $solgs_data->delete_list($list_id);
    }

    foreach my $dataset_id ($trials_dt_id, $accessions_dt_id, $plots_dt_id) {
        $dataset_id =~ s/\w+_//g;
        $solgs_data->delete_dataset($dataset_id);
    }

});

done_testing();


use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;


$d->while_logged_in_as("submitter", sub {
    $d->get_ok('/solgs', 'solgs home page');
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 nacrri');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);

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
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('combined trials');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);


    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(3);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 nacrri');
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

# $d->get('/solgs/populations/combined/2804608595/gp/1', 'combo trials tr pop page');
   # sleep(4);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('Test DMCP model combo');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
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
   my $sel_pred = $d->find_element('GEBVs vs observed', 'partial_link_text', 'scroll to GEBvs');
   my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
   sleep(2);
   $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
   sleep(120);
   $d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
   sleep(20);
   $d->driver->go_back();
   sleep(15);

    my $sel_pred = $d->find_element('Model accuracy statistics', 'partial_link_text', 'scroll to accuracy');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(2);
    $d->find_element_ok('Download model accuracy', 'partial_link_text',  'download accuracy')->click();
    sleep(3);
    $d->driver->go_back();
    sleep(5);

    my $sel_pred = $d->find_element('GEBVs vs observed', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
    sleep(2);
    $d->find_element_ok('Download all GEBVs', 'partial_link_text',  'download gebvs')->click();
    sleep(3);
    $d->driver->go_back();
    sleep(5);

    my $sel_pred = $d->find_element('Marker Effects', 'partial_link_text', 'scroll to marker effects');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
    sleep(2);
    $d->find_element_ok('Marker Effects', 'partial_link_text', 'expand marker effects')->click();
    sleep(2);
    $d->find_element_ok('Download all marker', 'partial_link_text',  'build marker effects')->click();
    sleep(3);
    $d->driver->go_back();
    sleep(5);

	my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
	my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
	$d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
	sleep(5);
	$d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
	sleep(100);
	$d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
	sleep(5);
	$d->find_element_ok('queue_job', 'id', 'job queueing')->click();
	sleep(2);
	$d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('Test DMCP selection pred combo trials model');
	sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
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

	my $sel_pred = $d->find_element('Check Genetic Gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(90);
    $d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);
    $d->driver->go_back();
    sleep(15);
	$d->driver->go_back();

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'list sl pop')->click();
     sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('clones list sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "DMCP")]', 'xpath', 'click list sel pred')->click();
    sleep(10);

	my $sel_pred = $d->find_element('Check Genetic Gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(90);
    $d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);
    $d->driver->go_back();
    sleep(15);
	$d->driver->go_back();
	sleep(10);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'dataset')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]/tbody/tr/td/a[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('dataset clones sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select list sl pop')->click();
     sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]/tbody/tr/td/a[contains(text(), "DMCP")]', 'xpath', 'click list sel pred')->click();
    sleep(10);

#$d->get('/solgs/combined/model/2804608595/selection/dataset_5/trait/70741/gp/1', 'combo trials tr pop page');

	my $sel_pred = $d->find_element('Check Genetic Gain', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $sel_pred);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(60);
    $d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);
    $d->driver->go_back();
    sleep(5);
	# $d->driver->go_back();
	# sleep(5);
	# $d->driver->go_back();
    # sleep(5);
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
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(5);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(20);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('Test DMCP-FRW selection pred naccri');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

	#$d->get_ok('/solgs/models/combined/trials/2804608595/traits/1971973596/gp/1');
	
	sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "FRW")]', 'xpath', 'go back')->click();
    sleep(5);
	$d->driver->go_back();
	sleep(3);

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(20);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('clones list dmc-frw sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'list sl page')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "FRW")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(5);

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select list sl pop')->click();
     sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('dataset clones sel pred2');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'dataset')->click();
     sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "FRW")]', 'xpath', 'dataset dmcp-frw pred')->click();
    sleep(10);

    `rm -r /tmp/localhost/`;

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
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('iyt2');
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



});
done_testing();

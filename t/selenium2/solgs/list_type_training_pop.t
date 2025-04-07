
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
    'user_id' => 40,
});

my $cache_dir = $solgs_data->site_cluster_shared_dir();
print STDERR "\nsite_cluster_shared_dir-- $cache_dir\n";

my $accessions_list =  $solgs_data->load_accessions_list();
my $accessions_list_name = $accessions_list->{list_name};
my $accessions_list_id = 'list_' . $accessions_list->{list_id};
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
my $plots_list =  $solgs_data->load_plots_list();
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = 'list_' . $plots_list->{list_id};

print STDERR "\nadding trials list\n";
my $trials_list =  $solgs_data->load_trials_list();
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = 'list_' . $trials_list->{list_id};
print STDERR "\nadding trials dataset\n";
my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = 'dataset_' . $trials_dt->{dataset_id};
print STDERR "\nadding accessions dataset\n";
my $accessions_dt = $solgs_data->load_accessions_dataset();
my $accessions_dt_name = $accessions_dt->{dataset_name};
my $accessions_dt_id = 'dataset_' . $accessions_dt->{dataset_id};

print STDERR "\nadding plots dataset\n";
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
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $plots_list_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'query plots list tr pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('plots list tr pop');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);

    $d->driver->go_back();
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $plots_list_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'open plots list tr pop')->click();
    sleep(5);
    
    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP model list tr');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);
    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(10);

	my $gebvs_section = $d->find_element('GEBVs vs observed', 'partial_link_text', 'scroll to GEBvs');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $gebvs_section);
    sleep(2);
    $d->find_element_ok('save_gebvs', 'id',  'store gebvs')->click();
    sleep(120);
	$d->find_element_ok('View stored GEBVs', 'partial_link_text',  'view store gebvs')->click();
    sleep(20);
    $d->driver->go_back();
    sleep(15);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(3);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(130);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP selection pred list tr');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(180);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('DMCP', 'partial_link_text', 'go back')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);

#  ##########################
#     # $d->get_ok('/solgs/population/' . $plots_list_id);
#     # sleep(5);
#     # $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
#     # sleep(3);
#  ##########################

    my $sel_pred = $d->find_element('Predict GEBVs', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(10);
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing name')->send_keys('clones list sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions list sel pred')->click();
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "DMCP")]', 'xpath', 'click list sel pred')->click();
    sleep(10);

    $d->driver->go_back();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions dataset sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing name')->send_keys('dataset  accessions sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict GEBVs', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions list sel pred')->click();
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "DMCP")]', 'xpath', 'dataset accessions sel pred result')->click();
    sleep(10);

    $d->driver->go_back();
    sleep(5);

    $d->driver->execute_script( "window.scrollTo(0, 50)");
    sleep(5);
    $d->find_element_ok('plots list', 'partial_link_text', 'get training pop page')->click();
    sleep(5);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(2);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW modeling list tr');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(2);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(15);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW selection pred kasese');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "FRW")]', 'xpath', 'go back')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions list sel multi traits pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('clones list dmc-frw sel pred');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions list sel pred')->click();
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_list_id .'"]//*[contains(text(), "FRW")]', 'xpath', 'Go to FRW selection prediction page')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions dataset sel multi traits pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('dataset clones sel pred multi');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "Predict")]', 'xpath', 'accessions list sel pred')->click();
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $accessions_dt_id .'"]//*[contains(text(), "FRW")]', 'xpath', 'accessions dataset dmcp-frw pred')->click();
    sleep(10);


    `rm -r $cache_dir`;
    $d->driver->refresh();
    sleep(5);
    $d->get('/solgs', 'solgs home page');
    sleep(4);


    $d->find_element_ok('//tr[@id="' . $trials_list_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'trials list sel pred')->click(); 
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('trials list tr pop');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);

    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);

    $d->find_element_ok('//tr[@id="' . $trials_list_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'trials list sel pred')->click();
    sleep(10);


    # $d->get('/solgs/populations/combined/2804608595/gp/1', 'plots list tr pop page');
    # sleep(4);


####### datasets
    $d->driver->go_back();
    sleep(5);

    `rm -r $cache_dir`;
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    # $d->find_element_ok('//tr[@id="' . $plots_dt_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'query plots dataset tr pop')->click();
    # sleep(3);
    # $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    # sleep(5);
    # $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('plots dataset tr pop');
    # sleep(5);
	# $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    # sleep(5);
    # $d->find_element_ok('submit_job', 'id', 'submit')->click();
    # sleep(250);

    # $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    # sleep(10);

    # $d->find_element_ok('//tr[@id="' . $plots_dt_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'go to plots dataset tr pop')->click();
    # sleep(5);

    # $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    # sleep(3);
    # $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    # sleep(2);
    # $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP model plots dataset tr');
    # sleep(2);
	# $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    # sleep(2);
    # $d->find_element_ok('submit_job', 'id', 'submit')->click();
    # sleep(150);

    # $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    # sleep(10);

    # $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    # sleep(10);

    # $d->driver->go_back();
    # sleep(5);

    # `rm -r $cache_dir`;
    # sleep(5);

    # $d->driver->refresh();
    # sleep(5);

    $d->find_element_ok('//tr[@id="' . $trials_dt_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'create trials dataset tr pop')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('trials dataset tr pop');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);

    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);

    $d->find_element_ok('//tr[@id="' . $trials_dt_id .'"]//*[starts-with(@id, "run_solgs")]', 'xpath', 'go to trials dataset tr pop')->click();
    sleep(5);
    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP model trials dataset tr');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);

    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(10);


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

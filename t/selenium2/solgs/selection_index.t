
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
print STDERR "\nsite_cluster_shared_dir-- $cache_dir\n";


my $accessions_list =  $solgs_data->load_accessions_list();
# my $accessions_list = $solgs_data->get_list_details('accessions');
my $accessions_list_name = $accessions_list->{list_name};
my $accessions_list_id = 'list_' . $accessions_list->{list_id};
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
my $plots_list =  $solgs_data->load_plots_list();
# my $plots_list =  $solgs_data->get_list_details('plots');
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = 'list_' . $plots_list->{list_id};

print STDERR "\nadding trials list '\n";
my $trials_list =  $solgs_data->load_trials_list();
# my $trials_list =  $solgs_data->get_list_details('trials');
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = 'list_' . $trials_list->{list_id};
print STDERR "\nadding trials dataset\n";
# my $trials_dt =  $solgs_data->get_dataset_details('trials');
my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = 'dataset_' . $trials_dt->{dataset_id};
print STDERR "\nadding accessions dataset\n";
# my $accessions_dt =  $solgs_data->get_dataset_details('accessions');
my $accessions_dt = $solgs_data->load_accessions_dataset();
my $accessions_dt_name = $accessions_dt->{dataset_name};
my $accessions_dt_id = 'dataset_' . $accessions_dt->{dataset_id};

print STDERR "\nadding plots dataset\n";
# my $plots_dt =  $solgs_data->get_dataset_details('plots');
my $plots_dt = $solgs_data->load_plots_dataset();
my $plots_dt_name = $plots_dt->{dataset_name};
my $plots_dt_id = 'dataset_' . $plots_dt->{dataset_id};

#$accessions_dt_name = '' . $accessions_dt_name . '';
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
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
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
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);


    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
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
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(5);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('Test DMCP-FRW selection pred naccri');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(170);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);


    my $si = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_pops_select"]/option[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(80);

    my $si = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-10);", $si);
    sleep(5);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Values")]', 'xpath', 'check caption')->click();
    sleep(2);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'check caption')->click();
    sleep(2);
    # $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Indices")]', 'xpath', 'check caption')->click();
    # sleep(2);

    $d->driver->refresh();
    sleep(2);

    my $cor = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
    sleep(5);
    $d->find_element_ok('si_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(2);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(4);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(60);

    my $si = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-10);", $si);
    sleep(5);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Values")]', 'xpath', 'check caption')->click();
    sleep(2);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'check caption')->click();
    sleep(2);
    # $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Indices")]', 'xpath', 'check caption')->click();
    # sleep(2);


    `rm -r $cache_dir`;
    $d->get('/solgs');

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
    sleep(180);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
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
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $si = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_pops_select"]/option[contains(text(), "Training population 280")]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(80);

    my $si = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-10);", $si);
    sleep(5);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Values")]', 'xpath', 'check caption')->click();
    sleep(2);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'check caption')->click();
    sleep(2);

    $d->driver->refresh();
    sleep(2);
    
    my $cor = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
    sleep(5);
    $d->find_element_ok('si_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(2);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(4);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(60);

    my $si = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-10);", $si);
    sleep(5);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Values")]', 'xpath', 'check caption')->click();
    sleep(2);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'check caption')->click();
    sleep(2);

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

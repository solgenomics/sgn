
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
# my $accessions_list = $solgs_data->get_list_details('accessions');
my $accessions_list_name = $accessions_list->{list_name};
my $accessions_list_id = 'list_' . $accessions_list->{list_id};
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
my $plots_list =  $solgs_data->load_plots_list();
# my $plots_list =  $solgs_data->get_list_details('plots');
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = 'list_' . $plots_list->{list_id};

print STDERR "\nadding trials list  \n";
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

print STDERR "\n' . $trials_list_name . ': $trials_list_name -- $trials_list_id\n";
print STDERR "\naccessions list: $accessions_list_name -- $accessions_list_id\n";
print STDERR "\nplots list: $plots_list_name -- $plots_list_id\n";


`rm -r $cache_dir`;

$d->while_logged_in_as("submitter", sub {
    sleep(2);
    $d->get_ok('/kinship/analysis', 'kinship home page');
    sleep(5);
    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);

    my $sel = $d->find_element('//div[@class="select_menu_block"]//*[contains(text(), "Select")]', 'xpath', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -50);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);
    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $trials_list_name . '"]', 'xpath', 'select trials list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(150);
    my $sel = $d->find_element('//div[@class="select_menu_block"]//*[contains(text(), "Select")]', 'xpath', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -50);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);
    
    `rm -r $cache_dir`;
    sleep(3);

    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('kinship analysis');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(60);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);

    # $d->get_ok('/kinship/analysis/list_17/gp/1', 'cluster home page');
    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select clones list')->click();
    sleep(3);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, 150);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select clones list')->click();
    sleep(4);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(140);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $trials_dt_name . '"]', 'xpath', 'select trials dataset')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(160);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);

    $d->driver->refresh();
    sleep(3);

    `rm -r $cache_dir`;
    sleep(3);
    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('kinship analysis');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(120);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    # $d->get_ok('/kinship/analysis/dataset_4/gp/1', 'cluster home page');
    # sleep(20);
    $d->find_element_ok('//select[@id="kinship_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(5);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, 150);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->get_ok('/breeders/trial/139', 'trial detail home page');
    sleep(5);
    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    my $analysis_tools = $d->find_element('Kinship', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-60);", $analysis_tools);
    sleep(2);
    $d->find_element_ok('Kinship', 'partial_link_text', 'expand kinship')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'select k number')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(2);

    `rm -r $cache_dir`;
    $d->get_ok('/solgs', 'solgs homepage');
    sleep(4);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test Kasese Tr pop');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(80);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW modeling  Kasese');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);

    my $analysis_tools = $d->find_element('Kinship', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Kinship', 'partial_link_text', 'toogle kinship')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(2);

    $d->driver->refresh();
    sleep(10);
    my $clustering = $d->find_element('Models summary', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('//table[@id="model_summary"]//*[contains(text(), "FRW")]', 'xpath', 'click training pop')->click();
    sleep(5);
    my $analysis_tools = $d->find_element('Kinship', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Kinship', 'partial_link_text', 'toogle kinship')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(120);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(4);


    #########
    $d->get_ok('/solgs', 'solgs homepage');
    sleep(4);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 nacrri');
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
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('combo trials tr pop');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(80);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);


    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 nacrri');
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
    sleep(15);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW modeling combo trials');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(300);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);

    my $kin = $d->find_element('Kinship', 'partial_link_text', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $kin);
    sleep(5);
    $d->find_element_ok('Kinship', 'partial_link_text', 'toogle kinship')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel);
    sleep(5);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(2);

    $d->driver->refresh();
    sleep(10);

    $d->find_element_ok('//table[@id="model_summary"]//*[contains(text(), "FRW")]', 'xpath', 'click training pop')->click();
    sleep(5);
    my $kin = $d->find_element('Kinship', 'partial_link_text', 'scroll up kinship section');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $kin);
    sleep(5);
    $d->find_element_ok('Kinship', 'partial_link_text', 'toogle kinship')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "run_kinship")]', 'xpath', 'run kinship')->click();
    sleep(120);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);

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

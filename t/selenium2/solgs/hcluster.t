
use strict;

use lib 't/lib';

use File::Spec::Functions qw / catfile catdir/;
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
my $protocol_dir = $solgs_data->default_protocol_dir();
my $cluster_dir =  catdir($protocol_dir, 'cluster');
my $log_dir = catdir($protocol_dir, 'log');

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
#`rm -r $log_dir`;
$d->while_logged_in_as("submitter", sub {
    sleep(1);
    $d->get_ok('/cluster/analysis', 'cluster home page');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
  $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, 500);", $sel_pops);
    sleep(40);
    $d->find_element_ok('//img[@id="hierarchical-plot-' . $accessions_list_id . '-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $plots_list_name . '"]', 'xpath', 'select plots list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, 500);", $sel_pops);
    sleep(5);
    $d->find_element_ok('//img[@id="hierarchical-plot-' . $plots_list_id . '-phenotype"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $trials_list_name . '"]', 'xpath', 'select trials list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(200);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, 600);", $sel_pops);

    $d->find_element_ok('//img[@id="hierarchical-plot-' . $trials_list_id . '-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);


    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $trials_list_name . '"]', 'xpath', 'select trials list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
     sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(200);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, 500);", $sel_pops);
    $d->find_element_ok('//img[@id="hierarchical-plot-' . $trials_list_id . '-phenotype"]', 'xpath', 'check heirarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $trials_dt_name . '"]', 'xpath', 'select trials dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(200);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, 500);", $sel_pops);
    $d->find_element_ok('//img[@id="hierarchical-plot-' . $trials_dt_id . '-genotype-gp-1"]', 'xpath', 'plot displayed')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $trials_dt_name . '"]', 'xpath', 'select trials dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(200);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, 500);", $sel_pops);
    sleep(5);
    $d->find_element_ok('//img[@id="hierarchical-plot-' . $trials_dt_id . '-phenotype"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    `rm -r /tmp/localhost`;
    sleep(5);

    $d->get_ok('/breeders/trial/139', 'trial detail home page');
    sleep(5);

    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('Clustering', 'partial_link_text', 'expand cluster sec')->click();
    sleep(5);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-phenotype"]', 'xpath', 'plot displayed')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $analysis_tools = $d->find_element('cluster_canvas', 'id', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('Clustering', 'partial_link_text', 'expand cluster sec')->click();
    sleep(5);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(2);

   `rm -r $cache_dir`;
    $d->get_ok('/solgs', 'solgs homepage');
    sleep(4);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
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
    sleep(130);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
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
    sleep(5);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);
#
# # ###############################################################
 # $d->get_ok('solgs/traits/all/population/139/traits/1971973596/gp/1', 'models page');
# sleep(15);
# # ######################################################################
# #
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(30);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW selection pred nacrri');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);

    $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'accessions list sl pop')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'accessions list sl pop job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'accessions list sl pop analysis name')->send_keys('clones list dmc-frw sel pred');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);


    $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select list sl pop')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'dataset accessions job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'dataset accessions job analysis  name')->send_keys('dataset clones sel pred');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);



    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -200);", $sel_pops);

    $d->find_element_ok('//div[ @id="list_type_selection_pop_go_btn"]/input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $list = $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select list sel pop');
    $list->click();
    sleep(5);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel_pops);
    $d->find_element_ok('//div[ @id="list_type_selection_pop_go_btn"]/input[@value="View"]', 'xpath', 'select list sel pop')->click();
     sleep(15);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select list sel pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-' . $accessions_list_id . '-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -600);", $sel_pops);
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_select', 'id', 'select clones list menu')->click();
    sleep(5);

    my $dataset = $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select dataset sel pop');
    $dataset->click();
    sleep(5);
    $d->find_element_ok('//div[ @id="list_type_selection_pop_go_btn"]/input[@value="View"]', 'xpath', 'GO select dataset sel popp')->click();
     sleep(15);
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(180);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-' . $accessions_dt_id . '-traits-1971973596-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -600);", $sel_pops);
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $dataset = $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select dataset sel pop');
    $dataset->click();
    sleep(5);
    $d->find_element_ok('//div[ @id="list_type_selection_pop_go_btn"]/input[@value="View"]', 'xpath', 'select list sel pop')->click();
     sleep(15);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
   $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-' . $accessions_dt_id . '-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select ghenotype')->click();
    sleep(2);
   $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-traits-1971973596-phenotype"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-traits-1971973596-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();

    $d->driver->refresh();
    sleep(3);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
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
    sleep(130);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="139-DMCP-3-FRW-5"]', 'xpath', 'select sel index pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "selection_proportion_input")]', 'xpath', 'fill in sel prop')->send_keys('15');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-139-DMCP-3-FRW-5-genotype-gp-1-sp-15"]', 'xpath', 'plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-141-traits-1971973596-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-141-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    `rm -r $cluster_dir`;
    sleep(3);
    `rm -r $log_dir`;
    sleep(5);

# $d->get_ok('solgs/traits/all/population/139/traits/1971973596/gp/1', 'models page');
# sleep(15);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', 'geno hierarchical job')->send_keys('Nacrri sel pop geno clustering');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(130);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(10);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-141-traits-1971973596-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', 'geno hierarchical job')->send_keys('Nacrri sel pop gebv clustering');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(130);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(10);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-141-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
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
    sleep(130);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="139-DMCP-3-FRW-5"]', 'xpath', 'select sel index pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "selection_proportion_input")]', 'xpath', 'fill in sel prop')->send_keys('15');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', 'geno hierarchical job')->send_keys('Nacrri sel pop sindex clustering');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(130);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);


    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
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
    sleep(130);
    #
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="139-DMCP-3-FRW-5"]', 'xpath', 'select sel index pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "selection_proportion_input")]', 'xpath', 'fill in sel prop')->send_keys('15');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(10);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-139-DMCP-3-FRW-5-genotype-gp-1-sp-15"]', 'xpath', 'plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    `rm -r $cluster_dir`;
    sleep(3);
    `rm -r $log_dir`;
    sleep(5);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-141-traits-1971973596-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

#    #  #######    #
#    #  $d->get_ok('/solgs/trait/70666/population/139/gp/1', 'open model page');
#    #  sleep(5);
#    #

    my $clustering = $d->find_element('Models summary', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('//table[@id="model_summary"]//*[contains(text(), "FRW")]', 'xpath', 'click training pop')->click();
    sleep(5);
    ######

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-139-70666-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

   #  #$d->get_ok('/solgs/model/combined/populations/2804608595/trait/70741/gp/1', 'open combined trials model page');
   # # sleep(2);
   #

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
    sleep(1);

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
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('combined trials');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);

   #  #$d->get('/solgs/populations/combined/2804608595/gp/1', 'combo trials tr pop page');
   #  #sleep(5);
   #

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(2);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 nacrri');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(3);

    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(2);
    $d->find_element_ok('select_trials_btn', 'id', 'done selecting')->click();
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
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);


    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(1);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(1);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);

    ## $d->get_ok('/solgs/models/combined/trials/2804608595/traits/1971973596/gp/1', 'combined trials models summary page');
    # #sleep(5);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(20);
    $d->find_element_ok('//table[@id="selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('combo DMCP-FRW selection pred nacrri');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);

    $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(20);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('combo clones list dmc-frw sel pred');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

########
 #$d->get_ok('/solgs/models/combined/trials/2804608595/traits/1971973596/gp/1', 'combined trials models summary page');
  #sleep(5);
########

    $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select list sl pop')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'accessions dataset queue')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'accessions dataset analysis name')->send_keys('combo dataset clones sel pred');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="Training population 2804608595"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
   $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-traits-1971973596-phenotype"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="Training population 2804608595"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'click cluster pops')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="Training population 2804608595"]', 'xpath', 'select tr pop')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-traits-1971973596-genotype-gp-1"]', 'xpath', 'plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
    sleep(5);
    $d->find_element_ok('si_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_pops_select"]/option[text()="Training population 2804608595"]', 'xpath', 'select combo pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(50);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'click cluster pops')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="2804608595-DMCP-3-FRW-5"]', 'xpath', 'si')->click();
    sleep(5);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "selection_proportion_input")]', 'xpath', 'fill in sel prop')->send_keys('15');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-2804608595-DMCP-3-FRW-5-genotype-gp-1-sp-15"]', 'xpath', 'plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -600);", $sel_pops);
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $dataset = $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select dataset sel pop');
    $dataset->click();
    sleep(5);
    $d->find_element_ok('//div[ @id="list_type_selection_pop_go_btn"]/input[@value="View"]', 'xpath', 'select list sel pop')->click();
     sleep(15);


    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $accessions_dt_name . '"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-' . $accessions_dt_id . '-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(5);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -200);", $sel_pops);

    $d->find_element_ok('//div[ @id="list_type_selection_pop_go_btn"]/input[@value="View"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $list = $d->find_element_ok('//select[@id="list_type_selection_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select list sel pop');
    $list->click();
    sleep(5);
    $d->find_element_ok('//div[ @id="list_type_selection_pop_go_btn"]/input[@value="View"]', 'xpath', 'select list sel pop')->click();
     sleep(15);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="' . $accessions_list_name . '"]', 'xpath', 'select list sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-' . $accessions_list_id . '-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-141-traits-1971973596-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="cluster_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-141-traits-1971973596-gebv"]', 'xpath', 'check hierarchical plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Models summary', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('//table[@id="model_summary"]//*[contains(text(), "DMCP")]', 'xpath', 'click training pop')->click();
    sleep(5);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);

    $d->find_element_ok('//*[starts-with(@id, "cluster_type_select")]', 'xpath', 'select hierarchical')->send_keys('Hierarchical');
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "cluster_data_type_select")]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_cluster")]', 'xpath', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(130);
    $d->find_element_ok('//img[@id="hierarchical-plot-2804608595-70741-genotype-gp-1"]', 'xpath', 'check hierarchical plot')->click();
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

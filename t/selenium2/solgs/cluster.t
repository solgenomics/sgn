
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use File::Spec::Functions qw / catfile catdir/;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

 `rm -r /tmp/localhost/`;

$d->while_logged_in_as("submitter", sub {

    $d->get_ok('/cluster/analysis', 'cluster home page');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -10);", $sel_pops);
    sleep(40);
    $d->find_element_ok('//img[@id="k-means-plot-list_16-genotype-k-4-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="60 plots nacrri"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -10);", $sel_pops);
    sleep(5);
    $d->find_element_ok('//img[@id="k-means-plot-list_17-phenotype-k-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="Trials list"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -10);", $sel_pops);

    $d->find_element_ok('//img[@id="k-means-plot-list_10-genotype-k-4-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(5);


    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="Trials list"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(90);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -10);", $sel_pops);
    $d->find_element_ok('//img[@id="k-means-plot-list_10-phenotype-k-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="two trials dataset"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);

    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -10);", $sel_pops);
    $d->find_element_ok('//img[@id="k-means-plot-dataset_2-genotype-k-4-gp-1"]', 'xpath', 'plot displayed')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="two trials dataset"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    my $sel_pops = $d->find_element('//*[contains(text(), "Select a")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -10);", $sel_pops);
    sleep(5);
    $d->find_element_ok('//img[@id="k-means-plot-dataset_2-phenotype-k-4"]', 'xpath', 'check k-means plot')->click();
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
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-phenotype-k-5"]', 'xpath', 'plot displayed')->click();
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
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    $d->find_element_ok('//img[@id="k-means-plot-139-genotype-k-5-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(2);


   `rm -r /tmp/localhost/`;
    $d->get_ok('/solgs', 'solgs homepage');
    sleep(4);

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
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

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
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
    sleep(5);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);
#
# # ###############################################################
# #     # $d->get_ok('solgs/traits/all/population/139/traits/1971973596/gp/1', 'models page');
# #     # sleep(15);
# # ######################################################################
# #
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(30);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
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

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'list sl pop')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
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
    sleep(15);

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select list sl pop')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('dataset clones sel pred');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -200);", $sel_pops);

    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_list_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $list = $d->find_element_ok('//div[@id="list_type_selection_pops_list"]/select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select list sel pop');
    $list->click();
    sleep(5);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel_pops);
    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
     sleep(15);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="34 clones"]', 'xpath', 'select list sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    $d->find_element_ok('//img[@id="k-means-plot-139-list_16-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();
    sleep(3);
####126######
    $d->driver->refresh();
    sleep(3);

   my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -600);", $sel_pops);
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_list_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $dataset = $d->find_element_ok('//div[@id="list_type_selection_pops_list"]/select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop');
    $dataset->click();
    sleep(5);
    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
     sleep(15);
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('//img[@id="k-means-plot-139-dataset_1-traits-1971973596-genotype-k-5-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -600);", $sel_pops);
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_list_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $dataset = $d->find_element_ok('//div[@id="list_type_selection_pops_list"]/select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop');
    $dataset->click();
    sleep(5);
    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
     sleep(15);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-dataset_1-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select ghenotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="k-means-plot-139-traits-1971973596-phenotype-k-5"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="k-means-plot-139-traits-1971973596-genotype-k-5-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();

    $d->driver->refresh();
    sleep(3);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
    sleep(5);
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(60);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="139-DMCP-3-FRW-5"]', 'xpath', 'select sel index pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('selection_proportion', 'id', 'select k number')->send_keys('15');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="k-means-plot-139-139-DMCP-3-FRW-5-genotype-k-5-gp-1-sp-15"]', 'xpath', 'plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-141-traits-1971973596-genotype-k-5-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="k-means-plot-139-141-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/cluster/`;
    sleep(3);
    `rm -r /tmp/localhost/GBSApeKIgenotypingv4/log/`;
    sleep(5);

# $d->get_ok('solgs/traits/all/population/139/traits/1971973596/gp/1', 'models page');
# sleep(15);

my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
sleep(5);
$d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
sleep(3);
$d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
sleep(2);
$d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
sleep(2);
$d->find_element_ok('k_number', 'id', 'clear k number')->clear();
$d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
sleep(2);
$d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
sleep(3);
$d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
sleep(3);
$d->find_element_ok('analysis_name', 'id', 'geno pca job')->send_keys('Nacrri sel pop geno clustering');
sleep(2);
$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
sleep(2);
$d->find_element_ok('submit_job', 'id', 'submit')->click();
sleep(80);
$d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
sleep(3);

$d->driver->refresh();
sleep(3);

my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
sleep(5);
$d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
sleep(3);
$d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
sleep(2);
$d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
sleep(2);
$d->find_element_ok('k_number', 'id', 'clear k number')->clear();
$d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
sleep(2);
$d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
sleep(10);
$d->find_element_ok('//img[@id="k-means-plot-139-141-traits-1971973596-genotype-k-5-gp-1"]', 'xpath', 'check k-means plot')->click();
sleep(3);

$d->driver->refresh();
sleep(3);

my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
sleep(5);
$d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
sleep(3);
$d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
sleep(2);
$d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
sleep(2);
$d->find_element_ok('k_number', 'id', 'clear k number')->clear();
$d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
sleep(2);
$d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
sleep(3);
$d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
sleep(3);
$d->find_element_ok('analysis_name', 'id', 'geno pca job')->send_keys('Nacrri sel pop gebv clustering');
sleep(2);
$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
sleep(2);
$d->find_element_ok('submit_job', 'id', 'submit')->click();
sleep(120);
$d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
sleep(3);

$d->driver->refresh();
sleep(3);

my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
sleep(5);
$d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
sleep(3);
$d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
sleep(2);
$d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
sleep(2);
$d->find_element_ok('k_number', 'id', 'clear k number')->clear();
$d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
sleep(2);
$d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
sleep(10);
$d->find_element_ok('//img[@id="k-means-plot-139-141-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();
sleep(3);

$d->driver->refresh();
sleep(3);

my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
sleep(5);
$d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
sleep(3);
$d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
sleep(5);
$d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
sleep(5);
$d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
sleep(60);

my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
sleep(5);
$d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="139-DMCP-3-FRW-5"]', 'xpath', 'select sel index pop')->click();
sleep(3);
$d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
sleep(2);
$d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
sleep(2);
$d->find_element_ok('selection_proportion', 'id', 'select k number')->send_keys('15');
sleep(2);
$d->find_element_ok('k_number', 'id', 'clear k number')->clear();
$d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
sleep(2);
$d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
sleep(3);
$d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
sleep(3);
$d->find_element_ok('analysis_name', 'id', 'geno pca job')->send_keys('Nacrri sel pop sindex clustering');
sleep(2);
$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
sleep(2);
$d->find_element_ok('submit_job', 'id', 'submit')->click();
sleep(120);
$d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
sleep(3);


my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
sleep(5);
$d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
sleep(3);
$d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
sleep(5);
$d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
sleep(5);
$d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
sleep(60);
#
my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
sleep(5);
$d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
sleep(3);
$d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="139-DMCP-3-FRW-5"]', 'xpath', 'select sel index pop')->click();
sleep(3);
$d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
sleep(2);
$d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
sleep(2);
$d->find_element_ok('selection_proportion', 'id', 'select k number')->send_keys('15');
sleep(2);
$d->find_element_ok('k_number', 'id', 'clear k number')->clear();
$d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
sleep(2);
$d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
sleep(10);
$d->find_element_ok('//img[@id="k-means-plot-139-139-DMCP-3-FRW-5-genotype-k-5-gp-1-sp-15"]', 'xpath', 'plot')->click();
sleep(5);

$d->driver->refresh();
sleep(3);

`rm -r /tmp/localhost/GBSApeKIgenotypingv4/cluster/`;
sleep(5);
`rm -r /tmp/localhost/GBSApeKIgenotypingv4/log/`;
sleep(5);


    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-141-traits-1971973596-genotype-k-5-gp-1"]', 'xpath', 'check k-means plot')->click();
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
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-70666-genotype-k-4-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

#    #  #$d->get_ok('/solgs/model/combined/populations/2804608595/trait/70741/gp/1', 'open combined trials model page');
#    # # sleep(2);
#    #

    $d->get_ok('/solgs', 'solgs home page');
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('nacrri');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);

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
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('combined trials');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);
#
#    #  #$d->get('/solgs/populations/combined/2804608595/gp/1', 'combo trials tr pop page');
#    #  #sleep(5);
#    #

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

#     #  $d->get_ok('/solgs/models/combined/trials/2804608595/traits/1971973596/gp/1', 'combined trials models summary page');
#     # sleep(5);
#
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(20);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
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

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'list sl pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
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

    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select list sl pop')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('combo dataset clones sel pred');
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
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Training population 2804608595"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-traits-1971973596-phenotype-k-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Training population 2804608595"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-traits-1971973596-gebv-k-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'click cluster pops')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Training population 2804608595"]', 'xpath', 'select tr pop')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-traits-1971973596-genotype-k-4-gp-1"]', 'xpath', 'plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
    sleep(5);
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="Training population 2804608595"]', 'xpath', 'select combo pop')->click();
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
    $d->find_element_ok('cluster_dropdown', 'class', 'click cluster pops')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="2804608595-DMCP-3-FRW-5"]', 'xpath', 'si')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'genotype')->click();
    sleep(2);
    $d->find_element_ok('selection_proportion', 'id', 'select k number')->send_keys('15');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-2804608595-DMCP-3-FRW-5-genotype-k-4-gp-1-sp-15"]', 'xpath', 'plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(5);

     ## $d->get_ok('/solgs/models/combined/trials/2804608595/traits/1971973596/gp/1', 'combined trials models summary page');
    ## sleep(5);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -600);", $sel_pops);
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_list_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $dataset = $d->find_element_ok('//div[@id="list_type_selection_pops_list"]/select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop');
    $dataset->click();
    sleep(5);
    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
     sleep(15);


    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-dataset_1-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(5);

    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -200);", $sel_pops);

    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_list_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $list = $d->find_element_ok('//div[@id="list_type_selection_pops_list"]/select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select list sel pop');
    $list->click();
    sleep(5);
    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
     sleep(15);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="34 clones"]', 'xpath', 'select list sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-list_16-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-141-traits-1971973596-genotype-k-5-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(3);
# #
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="GEBV"]', 'xpath', 'select gebv')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-141-traits-1971973596-gebv-k-5"]', 'xpath', 'check k-means plot')->click();
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

    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('//select[@id="cluster_data_type_select"]/option[text()="Genotype"]', 'xpath', 'select genotype')->click();
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(3);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-2804608595-70741-genotype-k-4-gp-1"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

});





done_testing();

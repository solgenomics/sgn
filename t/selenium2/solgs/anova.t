
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
my $trait = "dry matter content percentage";

`rm -r $cache_dir`;

$d->while_logged_in_as("submitter", sub {


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

    my $anova = $d->find_element('ANOVA', 'partial_link_text', 'scroll to anova');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $anova);
    sleep(2);
    # $d->find_element_ok('anova_select_a_trait_div', 'id', 'click dropdown menu')->click();
    # sleep(3);
    $d->find_element_ok('anova_select_traits', 'id', 'select a trait')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="anova_select_traits"]/option[text()="' . $trait . '"]', 'xpath', 'select list sel pop')->click();
    sleep(2);
    $d->find_element_ok('run_anova', 'id', 'run anova')->click();
    sleep(180);
    $d->find_element_ok('//div[contains(., "ANOVA result")]', 'xpath', 'anova result')->get_text();

    sleep(5);

    `rm -r $cache_dir`;
    sleep(3);

    $d->get_ok('/breeders/trial/139', 'trial detail home page');
    sleep(5);
    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    # $d->find_element_ok('anova_select_a_trait_div', 'id', 'click dropdown menu')->click();
    # sleep(3);
    $d->find_element_ok('anova_select_traits', 'id', 'select a trait')->click();
    sleep(2);
     $d->find_element_ok('//select[@id="anova_select_traits"]/option[text()="' . $trait . '"]', 'xpath', 'select list sel pop')->click();
    sleep(2);
    $d->find_element_ok('run_anova', 'id', 'run anova')->click();
    sleep(160);
    $d->find_element_ok('//div[contains(., "ANOVA result")]', 'xpath', 'anova result')->get_text();
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

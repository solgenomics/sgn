
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

my $trait = "dry matter content percentage";

`rm -r $cache_dir`;

$d->while_logged_in_as("submitter", sub {


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
    sleep(180);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
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
    sleep(240);
    $d->find_element_ok('//div[contains(., "ANOVA result")]', 'xpath', 'anova result')->get_text();
    sleep(5);

    
});


done_testing();

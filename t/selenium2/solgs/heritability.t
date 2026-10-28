use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Test::solGSData;
use File::Spec::Functions qw / catfile catdir/;
use File::Path qw /remove_tree/;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

my $solgs_data = SGN::Test::solGSData->new({
    'fixture' => $f, 
    'accessions_list_subset' => 60,
    'plots_list_subset' => 60,
    'user_id' => 40,
});

my $cache_dir = $solgs_data->base_analyses_cache_dir();
print STDERR "\nsite_cluster_shared_dir-- $cache_dir\n";
my $heritability_dir  = catdir($cache_dir, 'heritability');

my $remove_tree = remove_tree($cache_dir, {safe => 1});
print STDERR "\nremove_tree result: $remove_tree\n";

$d->while_logged_in_as("submitter", sub {

    $d->get('/solgs', 'solgs home page');
    sleep(4);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('Test Kasese Tr pop');
    sleep(2);
	$d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    my $heri = $d->find_element('heritability', 'partial_link_text', 'scroll to heritability');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $heri);
    sleep(2);
    $d->find_element_ok('run_pheno_heritability', 'id', 'run heritability')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="heritability_canvas"]//*[contains(., "DMCP")]', 'xpath', 'heritability result')->get_text();
    sleep(3);
    # $d->find_element_ok('Download heritability', 'partial_link_text',  'download  heritability')->click();
    #  sleep(3);

    # $d->driver->go_back();
    # sleep(5);

    remove_tree($heritability_dir, {safe => 1});
    sleep(3);

    $d->get_ok('/breeders/trial/139', 'trial detail home page');
    sleep(5);

    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('run_pheno_heritability', 'id', 'run heritability')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="heritability_canvas"]//*[contains(., "DMCP")]', 'xpath', 'heritability result')->get_text();
    sleep(3);
    # $d->find_element_ok('Download heritability', 'partial_link_text',  'download  heritability')->click();
    # sleep(3);
    # $d->driver->go_back();
    # sleep(5);

    # foreach my $list_id ($trials_list_id, $accessions_list_id, $plots_list_id) {
    #     $list_id =~ s/\w+_//g;
    #     $solgs_data->delete_list($list_id);
    # }

    # foreach my $dataset_id ($trials_dt_id, $accessions_dt_id, $plots_dt_id) {
    #     $dataset_id =~ s/\w+_//g;
    #     $solgs_data->delete_dataset($dataset_id);
    # }

});


done_testing();

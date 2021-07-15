use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;

$d->while_logged_in_as("submitter", sub {


    $d->get('/solgs', 'solgs home page');
    sleep(4);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
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
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    my $heri = $d->find_element('heritability', 'partial_link_text', 'scroll to heritability');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $heri);
    sleep(2);
    $d->find_element_ok('run_pheno_heritability', 'id', 'run heritability')->click();
    sleep(30);
    $d->find_element_ok('//div[@id="heritability_canvas"]//*[contains(., "DMCP")]', 'xpath', 'heritability result')->get_text();
    sleep(3);
    $d->find_element_ok('Download heritability', 'partial_link_text',  'download  heritability')->click();
     sleep(3);
     $d->find_element_ok('//*[contains(text(), "DMCP")]', 'xpath', 'check heritability download')->click();
     sleep(5);
     $d->driver->go_back();
    sleep(5);

    `rm -r /tmp/localhost/`;
    sleep(3);

    $d->get_ok('/breeders/trial/139', 'trial detail home page');
    sleep(5);
    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('run_pheno_heritability', 'id', 'run heritability')->click();
    sleep(30);
    $d->find_element_ok('//div[@id="heritability_canvas"]//*[contains(., "DMCP")]', 'xpath', 'heritability result')->get_text();
    sleep(3);
    $d->find_element_ok('Download heritability', 'partial_link_text',  'download  heritability')->click();
     sleep(3);
     $d->find_element_ok('//*[contains(text(), "DMCP")]', 'xpath', 'check heritability download')->click();
     sleep(5);
     $d->driver->go_back();
    sleep(5);

});


done_testing();

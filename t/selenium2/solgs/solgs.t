
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $d = SGN::Test::WWW::WebDriver->new();
#my $f = SGN::Test::Fixture->new();
`rm -r /tmp/localhost/`;

sleep(5);
$d->while_logged_in_as("submitter", sub {
    sleep(2);
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
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test Kasese Tr pop');
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

  
   # #  #trial type training population: single trait modeling

    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP model Kasese');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(7);
 
    $d->find_element_ok('dry matter', 'partial_link_text',  'build model')->click();
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
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(40);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP selection pred Kasese');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(180);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(8);
    $d->find_element_ok('DMCP', 'partial_link_text', 'go back')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);
  
    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'list sl pop')->click();
    sleep(15);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('clones list sel pred');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(10);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select list sl pop')->click();
    sleep(15);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]//*[contains(text(), "DMCP")]', 'xpath', 'click list sel pred')->click();
    sleep(10);
    $d->driver->go_back();
    sleep(3);

    my $sel_pred = $d->find_element('Predict', 'partial_link_text', 'scroll to selection pred');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $sel_pred);
    sleep(5);
    $d->find_element_ok('//select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'dataset')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select dataset sel pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="list_type_selection_pops_table"]/tbody/tr/td/a[contains(text(), "Predict")]', 'xpath', 'click list sel pred')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('dataset clones sel pred');
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


    $d->get_ok('/solgs', 'homepage');
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2); 
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(2); 
    $d->find_element_ok('Kasese', 'partial_link_text', 'click training pop')->click();
    sleep(5);
  
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW modeling  Kasese');
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
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
    sleep(5);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW selection pred naccri');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "FRW")]', 'xpath', 'go back')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(6);

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
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
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
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('dataset clones sel pred');
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



});



done_testing();

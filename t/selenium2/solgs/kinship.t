
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use File::Spec::Functions qw/ catfile catdir/;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;

$d->while_logged_in_as("submitter", sub {
    sleep(2);
    $d->get_ok('/kinship/analysis', 'kinship home page');
    sleep(5);
    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(40);

    my $sel = $d->find_element('//div[@class="list_upload"]//*[contains(text(), "Select")]', 'xpath', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -50);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);
    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="Trials list"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    my $sel = $d->find_element('//div[@class="list_upload"]//*[contains(text(), "Select")]', 'xpath', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -50);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="Single kasese trial"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(80);

    my $sel = $d->find_element('//div[@class="list_upload"]//*[contains(text(), "Select")]', 'xpath', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -50);", $sel);
    sleep(2);

    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(3);

    `rm -r /tmp/localhost/`;
    sleep(3);

    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
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
    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(3);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(2);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, -50);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
    sleep(3);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="Dataset trial kasese"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);

    $d->driver->refresh();
    sleep(3);

    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="two trials dataset"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(120);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);

    $d->driver->refresh();
    sleep(3);

    `rm -r /tmp/localhost/`;
    sleep(3);
    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'job queueing')->click();
    sleep(3);
    $d->find_element_ok('analysis_name', 'id', 'job queueing')->send_keys('kinship analysis');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(90);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(10);

    # $d->get_ok('/kinship/analysis/dataset_4/gp/1', 'cluster home page');
    # sleep(20);
    $d->find_element_ok('//select[@id="kinship_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select clones list')->click();
    sleep(2);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(3);
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(5);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, -50);", $sel);
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
    $d->find_element_ok('run_kinship', 'id', 'select k number')->click();
    sleep(2);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(60);
    my $sel = $d->find_element('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'scroll up');
    my $elem =$d->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel);
    sleep(2);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);
    $d->find_element_ok('//div[@id="kinship_div"]//*[contains(text(), "Download")]', 'xpath', 'check output')->click();
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
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
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
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(60);
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
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
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
    $d->find_element_ok('run_kinship', 'id', 'run kinship')->click();
    sleep(90);
    $d->find_element_ok('//*[contains(text(), "Diagonals")]', 'xpath', 'check output')->click();
    sleep(4);

});


done_testing();


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

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(5);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
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
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
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

    my $cor = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
    sleep(5);
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
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


    `rm -r /tmp/localhost/`;
    $d->get('/solgs');

    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(1);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 nacrri');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);

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
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('combined trials');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);


    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(2);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(3);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 nacrri');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);

    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(3);
    $d->find_element_ok('done_selecting', 'id', 'done selecting')->click();
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

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(5);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(20);
    $d->find_element_ok('//table[@id="selection_pops_list"]//*[contains(text(), "Predict")]', 'xpath', 'click training pop')->click();
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
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[contains(text(), "Training population 280")]', 'xpath', 'select trial type tr pop')->click();
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

    my $cor = $d->find_element('selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $cor);
    sleep(5);
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
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


});



done_testing();

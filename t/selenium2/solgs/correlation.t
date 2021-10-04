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
    sleep(3);
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

    my $corr = $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $corr);
    sleep(2);
    $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation')->click();
    sleep(1);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run correlation')->click();
    sleep(60);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
    $d->find_element_ok('Download correlation', 'partial_link_text',  'download  corr coefs')->click();
    sleep(3);
    $d->find_element_ok('//*[contains(text(), "DMCP")]', 'xpath', 'check corr download')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);
    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(2);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW modeling  Kasese');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
	sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(350);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(3);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);

    # # # ###############################################################
    #     $d->get_ok('solgs/traits/all/population/139/traits/1971973596/gp/1', 'models page');
    #     sleep(15);
    # # # ######################################################################
    # #
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(3);
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

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corre_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="corre_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(40);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);

    $d->driver->refresh();

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corre_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="corre_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(40);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);


    my $si = $d->find_element('Calculate selection', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[contains(text(), "Kasese")]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(20);
    my $si = $d->find_element('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "> 0")]', 'xpath', 'check corr plot')->click();
    sleep(5);

    `rm -r /tmp/localhost/`;
    sleep(5);

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

    my $corr = $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $corr);
    sleep(2);
    $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation')->click();
    sleep(1);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run correlation')->click();
    sleep(60);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
    $d->find_element_ok('Download correlation', 'partial_link_text',  'download  corr coefs')->click();
    sleep(3);
    $d->find_element_ok('//*[contains(text(), "DMCP")]', 'xpath', 'check corr download')->click();
    sleep(5);

    $d->driver->go_back();
    sleep(5);
    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(2);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW modeling  Kasese');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(3);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);


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
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corre_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="corre_dropdown"]/dd/ul/li/a[text()="Training population 2804608595"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(70);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);

    $d->driver->refresh();

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corre_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="corre_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(70);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);


    my $si = $d->find_element('Calculate selection', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[contains(text(), "Training population")]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(20);
    my $si = $d->find_element('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "> 0")]', 'xpath', 'check corr plot')->click();
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
    $d->find_element_ok('Phenotypic correlation', 'partial_link_text', 'expand correlation')->click();
    sleep(1);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run correlation')->click();
    sleep(70);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
    $d->find_element_ok('Download correlation', 'partial_link_text',  'download  corr coefs')->click();
    sleep(3);
    $d->find_element_ok('//*[contains(text(), "DMCP")]', 'xpath', 'check corr download')->click();
    sleep(5);

});


done_testing();

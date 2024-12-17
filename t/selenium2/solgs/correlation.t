use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Test::solGSData;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

my $solgs_data = SGN::Test::solGSData->new({
    'fixture' => $f, 
    'accessions_list_subset' => 160, 
    'plots_list_subset' => 160, 
    'user_id' => 40,
});

my $cache_dir = $solgs_data->site_cluster_shared_dir();

my $plots_list =  $solgs_data->load_plots_list();
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = 'list_' . $plots_list->{list_id};

my $trials_list =  $solgs_data->load_trials_list();
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = 'list_' . $trials_list->{list_id};

my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = 'dataset_' . $trials_dt->{dataset_id};

my $plots_dt = $solgs_data->load_plots_dataset();
my $plots_dt_name = $plots_dt->{dataset_name};
my $plots_dt_id = 'dataset_' . $plots_dt->{dataset_id};


`rm -r  $cache_dir`;
sleep(5);

$d->while_logged_in_as("submitter", sub {
    sleep(2);

    $d->get_ok('/correlation/analysis', 'correlation home page');
    sleep(5);
    $d->find_element_ok('//tr[@id="' . $plots_list_id .'"]//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $trials_list_id .'"]//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(200);
   $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//tr[@id="' . $plots_dt_id .'"]//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

    $d->driver->refresh();
    sleep(5);

    `rm -r $cache_dir`;

    $d->find_element_ok('//tr[@id="' . $trials_dt_id .'"]//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);


    `rm -r $cache_dir`;
    sleep(3);

    ########## trial detail page ##########
    $d->get_ok('/breeders/trial/139', 'trial detail home page');
    sleep(5);
    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('Phenotypic correlation', 'partial_link_text', 'expand correlation')->click();
    sleep(1);
    $d->find_element_ok('run_correlation', 'id', 'run correlation')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot -- trial detail page')->click();
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table');
    sleep(2);

    `rm -r $cache_dir`;

    ########## solGS ##########
    $d->get('/solgs', 'solgs home page');
    sleep(3);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
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
    sleep(200);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    my $corr = $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-170);", $corr);
    sleep(2);
    $d->find_element('ANOVA', 'partial_link_text', 'scroll to correlation')->click();
    sleep(2);
    $d->find_element_ok('run_correlation', 'id', 'run correlation')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

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
    #   $d->get_ok('solgs/traits/all/population/139/traits/1971973596/gp/1', 'models page');
    #   sleep(15);
    # # ######################################################################
    #
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 NaCRRI');
    sleep(2);
    $d->find_element_ok('search_selection_pop', 'id', 'search for selection pop')->click();
    sleep(3);
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

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corr_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_pops_select"]/option[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(2);
    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corr_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);


    my $si = $d->find_element('Selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_pops_select"]/option[contains(text(), "Kasese")]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(250);
    my $si = $d->find_element('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
   $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table');
    sleep(2);

    `rm -r $cache_dir`;
    sleep(5);

    $d->get('/solgs');
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
    sleep(5);

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
    $d->find_element_ok('analysis_name', 'id', 'analysis name')->send_keys('combined trials');
    sleep(2);
    $d->find_element_ok('user_email', 'id', 'user email')->send_keys('email@email.com');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(250);

    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);

    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(2);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(3);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->clear();
    sleep(2);
    $d->find_element_ok('trial_search_box', 'id', 'population search form')->send_keys('trial2 nacrri');
    sleep(5);
    $d->find_element_ok('search_trial', 'id', 'search for training pop')->click();
    sleep(5);

    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="139"]', 'xpath', 'select trial kasese')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="searched_trials_table"]//input[@value="141"]', 'xpath', 'select trial nacrri')->click();
    sleep(3);
    $d->find_element_ok('select_trials_btn', 'id', 'done selecting')->click();
    sleep(3);
    $d->find_element_ok('combine_trait_trials', 'id', 'combine trials')->click();
    sleep(20);

    my $corr = $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-270);", $corr);
    sleep(2);
    $d->find_element('Acronyms', 'partial_link_text', 'scroll to correlation')->click();
    sleep(1);
    $d->find_element_ok('run_correlation', 'id', 'run correlation')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table');
    sleep(2);
    
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
    sleep(250);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(15);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corr_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_pops_select"]/option[text()="Training population 2804608595"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);

    $d->driver->refresh();
    sleep(2);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corr_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_pops_select"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(200);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);

    my $si = $d->find_element('Selection index', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_pops_select', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_pops_select"]/option[contains(text(), "Training population")]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(250);
    my $si = $d->find_element('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'scroll up');
   sleep(1);
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(2);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table');
    sleep(2);

   
    foreach my $list_id ($trials_list_id,  $plots_list_id) {
        $list_id =~ s/\w+_//g;
        $solgs_data->delete_list($list_id);
    }

    foreach my $dataset_id ($trials_dt_id,  $plots_dt_id) {
        $dataset_id =~ s/\w+_//g;
        $solgs_data->delete_dataset($dataset_id);
    }

});


done_testing();

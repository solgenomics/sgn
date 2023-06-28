use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Test::solGSData;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

my $solgs_data = SGN::Test::solGSData->new({'fixture' => $f, 'accessions_list_subset' => 160, 'plots_list_subset' => 160});
my $cache_dir = $solgs_data->site_cluster_shared_dir();
print STDERR "\nadding plots list '\n";
my $plots_list =  $solgs_data->load_plots_list();
my $plots_list_name = $plots_list->{list_name};
my $plots_list_id = 'list_' . $plots_list->{list_id};

print STDERR "\nadding trials list '\n";
my $trials_list =  $solgs_data->load_trials_list();
my $trials_list_name = $trials_list->{list_name};
my $trials_list_id = 'list_' . $trials_list->{list_id};
my $trials_dt = $solgs_data->load_trials_dataset();
my $trials_dt_name = $trials_dt->{dataset_name};
my $trials_dt_id = 'dataset_' . $trials_dt->{dataset_id};

print STDERR "\nadding plots dataset\n";
my $plots_dt = $solgs_data->load_plots_dataset();
my $plots_dt_name = $plots_dt->{dataset_name};
my $plots_dt_id = 'dataset_' . $plots_dt->{dataset_id};


`rm -r  $cache_dir`;
sleep(5);

$d->while_logged_in_as("submitter", sub {
    sleep(2);

    $d->get_ok('/correlation/analysis', 'correlation home page');
    sleep(5);

    $d->find_element_ok('//select[@id="corr_pops_list_select"]/option[text()="'. $plots_list_name . '"]', 'xpath', 'plots list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"corr_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(100);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="corr_pops_list_select"]/option[text()="' . $trials_list_name . '"]', 'xpath', 'select trials list')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(5);
    $d->find_element_ok('//select[starts-with(@id,"corr_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(2);
    $d->find_element_ok('//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(100);
   $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

    $d->driver->refresh();
    sleep(5);

    $d->find_element_ok('//select[@id="corr_pops_list_select"]/option[text()="' . $plots_dt_name . '"]', 'xpath', 'plots dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[starts-with(@id,"corr_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(100);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

    $d->driver->refresh();
    sleep(5);

    `rm -r $cache_dir`;

    $d->find_element_ok('//select[@id="corr_pops_list_select"]/option[text()="' . $trials_dt_name . '"]', 'xpath', 'trials dataset')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="View"]', 'xpath', 'go btn')->click();
    sleep(20);
    $d->find_element_ok('//select[starts-with(@id,"corr_data_type_select")]/option[text()="Phenotype"]', 'xpath', 'select phenotype')->click();
    sleep(3);
    $d->find_element_ok('//*[starts-with(@id, "run_correlation")]', 'xpath', 'run correlation')->click();
    sleep(100);
   $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);
    $d->find_element_ok('coefficients', 'partial_link_text',  'download corr coef table'); 
    sleep(2);

    `rm -r $cache_dir`;

    $d->get('/solgs', 'solgs home page');
    sleep(3);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
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
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    my $corr = $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $corr);
    sleep(2);
    $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation')->click();
    sleep(2);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run correlation')->click();
    sleep(60);
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
    $d->find_element_ok('corr_select_pops', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_select_pops"]/option[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(40);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);

    $d->driver->refresh();
    sleep(2);
    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corr_select_pops', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_select_pops"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(40);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);


    my $si = $d->find_element('Calculate selection', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_select_pops', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_select_pops"]/option[contains(text(), "Kasese")]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(80);
    my $si = $d->find_element('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "> 0")]', 'xpath', 'check corr plot')->click();
    sleep(5);

    `rm -r $cache_dir`;
    sleep(5);

    $d->get('/solgs');
    sleep(2);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
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


    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese solgs trial');
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
    $d->find_element_ok('corr_select_pops', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_select_pops"]/option[text()="Training population 2804608595"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(70);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);

    $d->driver->refresh();
    sleep(2);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5);
    $d->find_element_ok('corr_select_pops', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="corr_select_pops"]/option[text()="trial2 NaCRRI"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(70);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot');
    sleep(5);

    my $si = $d->find_element('Calculate selection', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5);
    $d->find_element_ok('si_select_pops', 'id', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//select[@id="si_select_pops"]/option[contains(text(), "Training population")]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(80);
    my $si = $d->find_element('//div[@id="si_canvas"]//*[contains(text(), "Index Name")]', 'xpath', 'scroll up');
   sleep(1);
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(2);
    $d->find_element_ok('//div[@id="si_canvas"]//*[contains(text(), "> 0")]', 'xpath', 'check corr plot')->click();
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
    $d->find_element_ok('Phenotypic correlation', 'partial_link_text', 'expand correlation')->click();
    sleep(1);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run correlation')->click();
    sleep(70);
    $d->find_element_ok('//div[@id="corr_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
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

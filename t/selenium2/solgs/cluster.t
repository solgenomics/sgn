
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use File::Spec::Functions qw / catfile catdir/;

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

`rm -r /tmp/localhost/`;

$d->while_logged_in_as("submitter", sub {

    $d->get_ok('/cluster/analysis', 'cluster home page');     
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="34 clones"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);   
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('Run Cluster', 'partial_link_text', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-34-clones-genotype-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->get_ok('/cluster/analysis', 'cluster home page');     
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="60 plot naccri"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);   
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Phenotype');
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('Run Cluster', 'partial_link_text', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-60-plot-naccri-phenotype-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->get_ok('/cluster/analysis', 'cluster home page');     
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="Trials list"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);   
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('Run Cluster', 'partial_link_text', 'run cluster')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-Trials-list-genotype-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->get_ok('/cluster/analysis', 'cluster home page');     
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="Trials list"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);   
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Phenotype');
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('Run Cluster', 'partial_link_text', 'run cluster')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-Trials-list-phenotype-4"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    $d->get_ok('/cluster/analysis', 'cluster home page');     
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="two trials dataset"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);   
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('Run Cluster', 'partial_link_text', 'run cluster')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-two-trials-dataset-genotype-4"]', 'xpath', 'plot displayed')->click();    
    sleep(5);

    $d->get_ok('/cluster/analysis', 'cluster home page');     
    sleep(1);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="two trials dataset"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'go btn')->click();
    sleep(5);   
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Phenotype');
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(1);
    $d->find_element_ok('Run Cluster', 'partial_link_text', 'run cluster')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-two-trials-dataset-phenotype-4"]', 'xpath', 'check k-means plot')->click();  
    sleep(5);

    
    $d->get_ok('/breeders/trial/139', 'trial detail home page');     
    sleep(5);
    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $analysis_tools);
    sleep(5);    
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Phenotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-phenotype-5"]', 'xpath', 'plot displayed')->click();  
    sleep(5);

    my $analysis_tools = $d->find_element('cluster_canvas', 'id', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-400);", $analysis_tools);
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(1);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(1);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(1);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(60);
    $d->find_element_ok('//img[@id="k-means-plot-139-genotype-5"]', 'xpath', 'check k-means plot')->click();
    
    $d->get_ok('/solgs', 'solgs homepage');
    sleep(4);

    my $solgs_data = $f->config->{basepath} . "/t/data/solgs/";  
    `cp -r $solgs_data /tmp/localhost/GBSApeKIgenotypingv4/`;
    sleep(10);  
  
    $d->get_ok('solgs/traits/all/population/139/traits/1039861645', 'models page');
    sleep(5);
   
    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -600);", $sel_pops);
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_list_select', 'id', 'select clones list menu')->click();
    sleep(5);
    my $dataset = $d->find_element_ok('//div[@id="list_type_selection_pops_list"]/select[@id="list_type_selection_pops_list_select"]/option[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop');
    $dataset->click();
    sleep(5);
    
    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -200);", $sel_pops);
    
    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('list_type_selection_pops_list_select', 'id', 'select clones list menu')->click();
     sleep(5);
    my $list = $d->find_element_ok('//div[@id="list_type_selection_pops_list"]/select[@id="list_type_selection_pops_list_select"]/option[text()="kasese clones 50"]', 'xpath', 'select list sel pop');
    $list->click();
    sleep(5);
   
    my $sel_pops = $d->find_element('Predict', 'partial_link_text', 'scroll up');
    my $elem =$d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0, -100);", $sel_pops);
    $d->find_element_ok('//div[@id="list_type_selection_pop_load"]/input[@value="Go"]', 'xpath', 'select list sel pop')->click();
     sleep(15);
    
    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
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
    sleep(20);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="kasese clones 50"]', 'xpath', 'select list sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(10);
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('//img[@id="k-means-plot-list_24-genotype-5"]', 'xpath', 'check k-means plot')->click();  


    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="kasese clones 50"]', 'xpath', 'select list sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('GEBV');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-list_24-gebv-5"]', 'xpath', 'check k-means plot')->click();

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('//img[@id="k-means-plot-dataset_4-genotype-5"]', 'xpath', 'check k-means plot')->click();  


    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Dataset Kasese Clones"]', 'xpath', 'select dataset sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('GEBV');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-dataset_4-gebv-5"]', 'xpath', 'check k-means plot')->click();  
    
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Phenotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139-phenotype-5"]', 'xpath', 'check k-means plot')->click();  
    sleep(5);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(2);
     $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139-genotype-5"]', 'xpath', 'check k-means plot')->click();
    sleep(5);

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial tr pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('GEBV');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139-gebv-5"]', 'xpath', 'check k-means plot')->click();  

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-141-genotype-5"]', 'xpath', 'check k-means plot')->click();  
    sleep(5);


    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="trial2 NaCRRI"]', 'xpath', 'select trial sel pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('GEBV');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-141-gebv-5"]', 'xpath', 'check k-means plot')->click();  

    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);
    $d->find_element_ok('//dl[@class="cluster_dropdown"]/dd/ul/li/a[text()="139-DMCP-3-FRW-5"]', 'xpath', 'select sel index pop')->click();
    sleep(3);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('5');
    sleep(2);
    $d->find_element_ok('selection_proportion', 'id', 'select k number')->send_keys('15');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139-DMCP-3-FRW-5-genotype-5-15"]', 'xpath', 'check k-means plot')->click();  
    sleep(5);
    
    $d->get_ok('/solgs/trait/70666/population/139', 'open model page');
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Phenotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139-phenotype-4-70666"]', 'xpath', 'check k-means plot')->click();  
    sleep(5);
	
    my $clustering = $d->find_element('Clustering', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $clustering);
    sleep(5);
    $d->find_element_ok('cluster_type_select', 'id', 'select k-means')->send_keys('K-means');
    sleep(2);
    $d->find_element_ok('cluster_data_type_select', 'id', 'select data type')->send_keys('Genotype');
    sleep(2);
    $d->find_element_ok('k_number', 'id', 'clear k number')->clear();
    $d->find_element_ok('k_number', 'id', 'select k number')->send_keys('4');
    sleep(2);
    $d->find_element_ok('run_cluster', 'id', 'run cluster')->click();
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139-genotype-4-70666"]', 'xpath', 'check k-means plot')->click();  
    sleep(5);
        
});





done_testing();

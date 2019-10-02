
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

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
    $d->find_element_ok('//img[@id="k-means-plot-34-clones"]', 'xpath', 'plot displayed')->click();
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
    $d->find_element_ok('//img[@id="k-means-plot-60-plot-naccri"]', 'xpath', 'plot displayed')->click();
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
    $d->find_element_ok('//img[@id="k-means-plot-Trials-list"]', 'xpath', 'plot displayed')->click();
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
    $d->find_element_ok('//img[@id="k-means-plot-Trials-list"]', 'xpath', 'plot displayed')->click();
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
    sleep(70);
    $d->find_element_ok('//img[@id="k-means-plot-two-trials-dataset"]', 'xpath', 'plot displayed')->click();    
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
    sleep(70);
    $d->find_element_ok('//img[@id="k-means-plot-two-trials-dataset"]', 'xpath', 'plot displayed')->click();  
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
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139"]', 'xpath', 'plot displayed')->click();  
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
    sleep(20);
    $d->find_element_ok('//img[@id="k-means-plot-139"]', 'xpath', 'plot displayed')->click();
        
});





done_testing();

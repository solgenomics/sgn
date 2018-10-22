
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;

$d->while_logged_in_as("submitter", sub {

    $d->get_ok('/cluster/analysis', 'cluster home page');    
    sleep(5);
    $d->find_element_ok('//select[@id="cluster_genotypes_list_select"]/option[text()="trial2 NaCRRI clones"]', 'xpath', 'select clones list')->click();
    sleep(5);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list sel pop')->click();
    sleep(5);
    $d->find_element_ok('//input[@id="k_means_select"]', 'xpath', 'select k-means')->click();
    sleep(5);
    $d->find_element_ok('Run Cluster', 'partial_link_text', 'run cluster')->click();
    sleep(60);
    $d->find_element_ok('K-means plot', 'partial_link_text', 'download plot')->click();
    sleep(5);
   
});





done_testing();

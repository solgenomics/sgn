
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();


$d->get_ok('/solgs', 'solgs home page');
sleep(2);

$d->while_logged_in_as("submitter", sub {
    $d->get_ok('/solgs', 'solgs home page');
    $d->find_element_ok('Search for a trait', 'link_text', 'toggle trait search')->click();
    sleep(5);
    $d->find_element_ok('a list-based', 'partial_link_text', 'toogle list training pops')->click();
    sleep(2);
    $d->find_element_ok('//select[@id="reference_genotypes_list_select"]/option[@value=8]', 'xpath', 'select list tr pop')->click();
    sleep(10);
    $d->find_element_ok('//input[@value="Go"]', 'xpath', 'select list tr pop')->click();
    sleep(30);
    $d->find_element_ok('Build', 'partial_link_text', 'open list training pop')->click();
    sleep(20);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run pheno correlation')->click();
    sleep(40);
    $d->find_element_ok('dry matter content percentage', 'link_text', 'build model')->click();
    sleep(10);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(30);
    $d->find_element_ok('run_pca', 'id', 'run pca')->click();
    sleep(40);
});


done_testing();

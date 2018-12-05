
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/`;

$d->while_logged_in_as("submitter", sub {

    $d->get_ok('/solgs', 'solgs home page');
    sleep(5);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(5); 
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);    
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(5);
    $d->find_element_ok('no_queue', 'id', 'no job queueing')->click();
    sleep(15);
    $d->find_element_ok("anova_select_a_trait_div", 'id', 'click dropdown menu')->click();
    sleep(15);
    $d->find_element_ok("anova_dropdown", 'class', 'select a trait')->click();
    sleep(5); 
    $d->find_element_ok('run_anova', 'id', 'run anova')->click();
    sleep(120); 
    $d->find_element_ok('//div[contains(., "ANOVA result")]', 'xpath', 'anova result')->get_text(); 
    sleep(5);
   
});


done_testing();

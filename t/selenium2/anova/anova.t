
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

`rm -r /tmp/localhost/GBSApeKIgenotypingv4/`;
`rm -r ~/cxgn/sgn/static/documents/tempfiles/anova`;

$d->while_logged_in_as("submitter", sub {

    my $trial_id = 139;
    $d->get_ok('/breeders/trial/' . $trial_id, 'trial detail page');
    sleep(10);
  
    $d->find_element_ok('//div[@id="anova_canvas"]//dt/a', 'xpath', 'select anova trait')->click();
    sleep(120);

    $d->find_element_ok('//div[@id="anova_canvas"]//dd/ul/li[1]/a', 'xpath', 'select anova trait')->click();
    sleep(10);

    $d->find_element_ok('run_anova', 'id', 'run anova')->click();
    sleep(120);

    $d->find_element_ok('Anova table', 'partial_link_text', 'download anova table')->click();
     

});





done_testing();

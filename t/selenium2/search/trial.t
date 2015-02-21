
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok('/search/trials');

ok($d->driver->get_page_source()=~/test_trial/, "find trial search result content");

ok($d->driver->get_page_source()=~/2014/, "find trial year in trial search results");

my $input_trial_name = $d->find_element_ok("trial_name", "id", "find trial name input element");

$input_trial_name->send_keys("Kasese");

my $submit_button = $d->find_element_ok("trial_search_submit_button", "id", "find trial search submit button");

$submit_button->click();

sleep(2);

my $page_source = $d->driver->get_page_source();

ok($page_source=~m/loaded into the fixture to test solgs/, "find trial description");

sleep(3);

ok($page_source!~m/test_trial/, "Do not find the test trial now");

sleep(3);

done_testing();



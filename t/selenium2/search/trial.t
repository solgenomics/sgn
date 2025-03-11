
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->while_logged_in_as (
    "submitter", sub {
	sleep(2);
	
	$d->get_ok('/search/trials');
	
	sleep(2);
	
	ok($d->driver->get_page_source()=~/Kasese/, "find trial search result content");
	
	ok($d->driver->get_page_source()=~/2014/, "find trial year in trial search results");
	
	my $trial_search_input = $d->find_element("//div[\@id=\"trial_search_results_filter\"]/descendant::label/descendant::input", "xpath");
	
	$trial_search_input->send_keys("Kasese");
	
	sleep(5);
	
	my $page_source = $d->driver->get_page_source();
	
	ok($page_source=~m/loaded into the fixture to test solgs/, "find trial description");
	
	sleep(2);
	
	ok($page_source!~m/test_trial/, "Do not find the test trial now");
	
	ok($d->find_element_ok("Kasese solgs trial", "link_text", "verify search")->click());
	
	
	sleep(2);
	
    });

done_testing();



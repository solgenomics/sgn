
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();


$d->while_logged_in_as ( "submitter", sub { 
    sleep(2);
    $d->get_ok('/search/stocks');
    sleep(2);
    my $page_source = lc($d->driver()->get_page_source());
    
    ok($page_source =~ /search accessions/, "Search page title presence");
    
    ok($page_source =~ /project location/, "Search options present");
    
    sleep(2);
    
    $d->find_element_ok("any_name", "id", "find any_name html input element")->send_keys("test_accession1");
    
    $d->find_element("//select[\@id=\"stock_type_select\"]/option[text()='accession']", "xpath","select stock type")->click();
    
    $d->find_element_ok("submit_stock_search", "id", "submit search")->click();
    sleep(5);
    $d->find_element_ok("test_accession1", "partial_link_text", "verify search")->click();
    
    $d->driver->quit();

		     });
    
    done_testing();

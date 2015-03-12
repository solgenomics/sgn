
use strict;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok("/breeders/home");
    
    my $page_source = $t->driver->get_page_source();
    
    ok($page_source =~ /Breeding Programs/, "check breeder home page content, breeding programs");
    
    ok($page_source =~ /Download Data/, "check breeder home page content, download data");
    
		       });

done_testing();

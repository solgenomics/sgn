
use strict;
use lib 't/lib';

use Test::More 'tests' => 6;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok("/search/people");
ok($d->driver()->get_page_source() =~ /Search People/, "find people search page title");
my $last_name = $d->find_element_ok("last_name", "id", "find last_name html element");
$last_name->send_keys("Sanger");
my $submit = $d->find_element_ok("submit_people_search", "id", "find people search submit button");
$submit->click();
sleep(2);
ok($d->driver()->get_page_source() !~ /Doe/, "terms not searched must not be on page");
ok($d->driver()->get_page_source() =~ /Sanger/, "search term must appear on page");

done_testing();

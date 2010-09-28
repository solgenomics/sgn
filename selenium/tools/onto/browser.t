
use strict;

use Test::More tests=>8;

use Test::WWW::Selenium;

my $server = $ENV{SELENIUM_TEST_SERVER} || die "Need the ENV SELENIUM_TEST_SERVER set";
my $host   = $ENV{SELENIUM_HOST} || die "Need the ENV SELENIUM_HOST set";
my $browser = $ENV{SELENIUM_BROWSER} || die "Need the ENV SELENIUM_BROWSER set";

my $s = Test::WWW::Selenium->new(
    host        => $host,
    port        => 4444,
    browser     => $browser,
    browser_url => $server."/tools/onto/",
    );

$s->open_ok($server."/tools/onto/");

sleep(4); # wait for the page to load completely (AJAX actions)
my $source    = $s->get_html_source();
my $body_text = $s->get_body_text();

like($body_text, qr/biological_process/, "GO biological process displayed");
like($body_text, qr/cellular_component/, "GO cellular component displayed");
like($body_text, qr/molecular_function/, "GO molecular function displayed");
like($body_text, qr/plant structure/,    "plant structure test");
like($body_text, qr/PATO:0000001/, "PATO present");
like($body_text, qr/Solanaceae phenotype ontology/, "SP ontology displayed");
like($body_text, qr/plant growth and development stages/, "plant growth devel stages");


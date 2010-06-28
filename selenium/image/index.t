
use strict;
use Test::More tests=>4;
use Test::WWW::Selenium;

my $server = $ENV{SELENIUM_TEST_SERVER} || die "Need the ENV SELENIUM_TEST_SERVER set";
my $host   = $ENV{SELENIUM_HOST} || die "Need the ENV SELENIUM_HOST set";
my $browser = $ENV{SELENIUM_BROWSER} || die "Need the ENV SELENIUM_BROWSER set";

my $s = Test::WWW::Selenium->new(
    host        => $host,
    port        => 4444,
    browser     => $browser,
    browser_url => $server."/image/index.pl?image_id=1",
    );

$s->open_ok($server."/image/index.pl?image_id=1");

my $source    = $s->get_html_source();
my $body_text = $s->get_body_text();

like($body_text, qr/SGN Image/, "String match on page");
like($source, qr/<img src=/, "Image tag string present");
like($body_text, qr/Image Description/, "Input field match");

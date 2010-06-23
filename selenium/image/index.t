
use strict;
use Test::More tests=>4;
use Test::WWW::Selenium;

my $server = 'http://pg83-devel.sgn.cornell.edu'; #$ENV{SGN_TEST_SERVER};
$server || die "need SGN_TEST_SERVER environment variable set";

my $s = Test::WWW::Selenium->new(
    host        => 'selenium.sgn.cornell.edu',
    port        => 4444,
    browser     => "*firefox",
    browser_url => $server."/image/index.pl?image_id=1",
    );

$s->open_ok($server."/image/index.pl?image_id=1");

my $source    = $s->get_html_source();
my $body_text = $s->get_body_text();

like($body_text, qr/SGN Image/, "String match on page");
like($source, qr/<img src=/, "Image tag string present");
like($body_text, qr/Image Description/, "Input field match");

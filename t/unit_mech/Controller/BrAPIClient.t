use strict;
use warnings;

use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Test::WWW::Mechanize skip_cgi => 1;
use URI;
use JSON;

my $f = SGN::Test::Fixture->new();
my $mech = SGN::Test::WWW::Mechanize->new;

# look at the login redirect instead of following it
$mech->requests_redirectable([]);

sub authorize_path {
    my $redirect_uri = shift;
    my $uri = URI->new('/brapi/authorize');
    $uri->query_form(redirect_uri => $redirect_uri);
    return $uri->as_string;
}

# a registered callback with its own query string survives the login redirect
my $callback = 'https://phenoapps.org/field-book?state=abc&mode=sync';
$mech->get(authorize_path($callback));
is($mech->status, 302, 'anonymous user is sent to the login page');
my $login_uri = URI->new($mech->response->header('Location'));
is($login_uri->path, '/user/login', 'redirected to /user/login');
my %login_query = $login_uri->query_form;
my $goto_uri = URI->new($login_query{goto_url});
is($goto_uri->path, '/brapi/authorize', 'goto_url returns to the authorize page');
my %goto_query = $goto_uri->query_form;
is($goto_query{redirect_uri}, $callback, 'goto_url keeps the complete redirect_uri');

my @look_alikes = (
    'https://climmob.net.attacker.example/',
    'https://climmob.net@attacker.example/',
    'https://climmobxnet.example/',
    'https://phenoapps.org/field-book-attacker',
    'https://phenoapps.org/field-book/../attacker',
);

foreach my $bad (@look_alikes) {
    $mech->get(authorize_path($bad));
    is($mech->status, 404, "anonymous request: no authorized client for $bad");
}

$mech->post_ok('/brapi/v1/token', [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ], 'login');
my $access_token = decode_json($mech->content)->{access_token};
ok($access_token, 'got a session token');

foreach my $bad (@look_alikes) {
    $mech->get(authorize_path($bad));
    is($mech->status, 404, "logged in: no authorized client for $bad");
    $mech->content_lacks($access_token, "session token is not offered to $bad");
}

# the redirect_uri is echoed on the 404 page, it has to be escaped
$mech->get(authorize_path('https://attacker.example/<script>alert(1)</script>'));
is($mech->status, 404, 'unregistered callback gets a 404');
$mech->content_lacks('<script>alert(1)</script>', 'redirect_uri is not echoed as html');
$mech->content_contains('&lt;script&gt;alert(1)&lt;/script&gt;', 'redirect_uri is echoed escaped');

# a quote in a registered callback must not end up inside javascript
my $quoted_callback = "https://phenoapps.org/field-book?state=');alert(document.cookie);//";
$mech->get_ok(authorize_path($quoted_callback), 'consent page for a registered client');
is($mech->response->header('Cache-Control'), 'no-store', 'consent page is not cached');
is($mech->response->header('Referrer-Policy'), 'no-referrer', 'consent page sends no referrer');
$mech->content_unlike(qr/onclick="[^"]*phenoapps\.org/, 'callback urls are not written into onclick javascript');
$mech->content_lacks("state=');alert(document.cookie);//", 'callback url is html escaped');

my $authorize_link = $mech->find_link(text => 'Authorize Access');
my $deny_link = $mech->find_link(text => 'Deny Access');
ok($authorize_link, 'authorize link found');
ok($deny_link, 'deny link found');
is($authorize_link && $authorize_link->url, $quoted_callback.'&status=200&access_token='.$access_token, 'authorize link returns the token to the callback');
is($deny_link && $deny_link->url, $quoted_callback.'&status=401', 'deny link appends status to the existing query string');

# callback without a query string
$mech->get_ok(authorize_path('fieldbook://'), 'consent page for a native app');
$authorize_link = $mech->find_link(text => 'Authorize Access');
$deny_link = $mech->find_link(text => 'Deny Access');
is($authorize_link && $authorize_link->url, 'fieldbook://?status=200&access_token='.$access_token, 'authorize link for a native app');
is($deny_link && $deny_link->url, 'fieldbook://?status=401', 'deny link for a native app');

done_testing();

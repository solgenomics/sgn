use strict;
use warnings;

use Test::More;
use JSON;
use SGN::Controller::BrAPIClient;

sub matches {
    return SGN::Controller::BrAPIClient::_redirect_uri_matches(@_) ? 1 : 0;
}

# every client registered in the default sgn.conf still accepts its own callbacks
open(my $conf, '<', 'sgn.conf') or die "Cannot open sgn.conf: $!";
my ($clients_json) = map { /^authorized_clients_JSON\s+(.*?)\s*$/ ? $1 : () } <$conf>;
close($conf);
my $clients = decode_json($clients_json);
ok(scalar(keys %$clients), 'default authorized clients found in sgn.conf');

foreach my $url (sort keys %$clients) {
    is(matches($url, $url), 1, "$url matches itself");
    my $callback = $url . ($url =~ m{/$} ? '' : '/') . 'callback?state=1';
    is(matches($callback, $url), 1, "$url accepts $callback");
}

my @accepted = (
    [ 'https://climmob.net', 'https://climmob.net' ],
    [ 'https://climmob.net/', 'https://climmob.net' ],
    [ 'https://climmob.net?state=1', 'https://climmob.net' ],
    [ 'https://climmob.net#state', 'https://climmob.net' ],
    [ 'https://phenoapps.org/field-book/sync?state=1', 'https://phenoapps.org/field-book' ],
    [ 'https://phenoapps.org/field-book?next=/../x', 'https://phenoapps.org/field-book' ],
    [ 'https://fieldbook.phenoapps.org/.app/callback', 'https://fieldbook.phenoapps.org/' ],
    [ 'fieldbook://callback', 'fieldbook://' ],
);

my @rejected = (
    [ 'https://climmob.net.attacker.example/', 'https://climmob.net' ],
    [ 'https://climmob.net@attacker.example/', 'https://climmob.net' ],
    [ 'https://climmob.net:8443/', 'https://climmob.net' ],
    [ 'https://climmob.net%2eattacker.example/', 'https://climmob.net' ],
    [ 'https://climmobxnet.example/', 'https://climmob.net' ],
    [ "https://climmob.net\t.attacker.example/", 'https://climmob.net' ],
    [ 'http://climmob.net/', 'https://climmob.net' ],
    [ 'https://attacker.example/?https://climmob.net', 'https://climmob.net' ],
    [ 'https://phenoapps.org/field-book-attacker', 'https://phenoapps.org/field-book' ],
    [ 'https://phenoapps.org/field-book/../attacker', 'https://phenoapps.org/field-book' ],
    [ 'https://phenoapps.org/field-book/%2E%2E/attacker', 'https://phenoapps.org/field-book' ],
    [ 'https://phenoapps.org/field-book/..\\attacker', 'https://phenoapps.org/field-book' ],
    [ 'https://fieldbook.phenoapps.org/../attacker', 'https://fieldbook.phenoapps.org/' ],
    [ undef, 'https://climmob.net' ],
    [ '', 'https://climmob.net' ],
);

foreach my $case (@accepted) {
    is(matches(@$case), 1, "$case->[0] is accepted for $case->[1]");
}
foreach my $case (@rejected) {
    is(matches(@$case), 0, (defined $case->[0] ? $case->[0] : 'undef') . " is rejected for $case->[1]");
}

done_testing();

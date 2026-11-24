# CXGN::Satellite: the satellites offered (free ones always; a paid one only
# with its key and its search written) and that a key never leaves the server.

use strict;
use warnings;

use Test::More;
use JSON;
use LWP::UserAgent;
use CXGN::Satellite;

my $ua = LWP::UserAgent->new();
my @requests;
$ua->add_handler(request_send => sub { push @requests, shift->uri . ''; return HTTP::Response->new(500, 'no network in this test') });

my $free = CXGN::Satellite->new({ ua => $ua });
is_deeply([ map { $_->{id} } @{ $free->sources } ], [ 'sentinel2', 'landsat' ], 'no key: the two free satellites');
my ($s2) = @{ $free->sources };
is_deeply($s2, { id => 'sentinel2', name => 'Sentinel-2', res => 10, revisit => 5, since => 2017, paid => 0 }, 'satellite description');
ok($free->source_available('landsat'), 'Landsat available');
ok(!$free->source_available('planet'), 'PlanetScope not available without key');
ok(!$free->source_available('modis'), 'unknown satellite not available');
is_deeply([ $free->source_without_search ], [], 'no key: nothing to warn about');

# a key is set, but the PlanetScope search is not written yet: still not offered
my $key = 'PLAK-secret-0123456789';
my $keyed = CXGN::Satellite->new({ ua => $ua, planet_api_key => $key });
SKIP: {
    skip 'the PlanetScope search is written: update the tests below', 4 if CXGN::Satellite->can('_planet');
    is_deeply([ map { $_->{id} } @{ $keyed->sources } ], [ 'sentinel2', 'landsat' ], 'key without search: not offered');
    ok(!$keyed->source_available('planet'), 'key without search: not available');
    is_deeply([ $keyed->source_without_search ], [ 'planet' ], 'key without search: reported for the server log');
    like($keyed->scenes({ bbox => [ -44.26, -19.47, -44.24, -19.45 ], start => '2026-11-01', end => '2026-11-20', sources => [ 'planet' ] })->{error},
        qr/PlanetScope is not available on this server/, 'asking for it anyway: refused before any request');
}
is(scalar @requests, 0, 'no request sent');
unlike(encode_json($keyed->sources), qr/\Q$key\E/, 'the key is never in the list sent to the page');

# when a paid satellite has its search: offered only with its key
{
    no warnings 'once';
    local *CXGN::Satellite::_planet = sub { return { scenes => [] } };
    is_deeply([ map { $_->{id} } @{ $keyed->sources } ], [ 'sentinel2', 'landsat', 'planet' ], 'search written + key: offered');
    my ($p) = grep { $_->{id} eq 'planet' } @{ $keyed->sources };
    is_deeply($p, { id => 'planet', name => 'PlanetScope', res => 3, revisit => 1, since => 2016, paid => 1 }, 'paid satellite described, no key');
    is_deeply([ map { $_->{id} } @{ $free->sources } ], [ 'sentinel2', 'landsat' ], 'search written, no key: not offered');
    is_deeply([ $keyed->source_without_search ], [], 'search written: nothing to warn about');
    my $res = $keyed->scenes({ bbox => [ -44.26, -19.47, -44.24, -19.45 ], start => '2026-11-01', end => '2026-11-20', sources => [ 'planet' ] });
    ok(!$res->{error}, 'search dispatched to its method') or diag($res->{error});
    unlike(encode_json($res), qr/\Q$key\E/, 'the key is not in the search answer');
}

done_testing();

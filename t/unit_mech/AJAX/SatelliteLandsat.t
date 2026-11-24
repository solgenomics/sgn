# Satellite page endpoints with Landsat 8/9 (/ajax/satellite/scenes?sources=...,
# /ajax/satellite/landsat_token). The real catalogue and token service are only
# used with SATELLITE_NETWORK_TESTS=1.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $base = 'http://localhost:3010';
my $mech = Test::WWW::Mechanize->new;
my $area = 'west=-76.48&south=42.44&east=-76.46&north=42.46';

END {
    local $?;
    eval { $f->clean_up_db(); 1 } or diag("clean_up_db failed: $@");
}

# logged out
$mech->get("$base/ajax/satellite/landsat_token");
is($mech->status, 401, 'token needs login');
$mech->get("$base/ajax/satellite/sources");
is($mech->status, 401, 'satellite list needs login');

$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ]);

$mech->get_ok("$base/breeders/satellite", 'page');
$mech->content_contains('id="sat_sources"', 'satellite choice on the page');
$mech->get_ok("$base/ajax/satellite/sources", 'satellites offered');
is_deeply([ map { $_->{id} } @{ decode_json($mech->content)->{sources} } ], [ 'sentinel2', 'landsat' ], 'Sentinel-2 and Landsat offered, no paid one without key');
$mech->get_ok("$base/ajax/satellite/scenes?$area&start=2026-01-01&end=2026-02-01&sources=planet");
like(decode_json($mech->content)->{error}, qr/PlanetScope is not available/, 'PlanetScope refused without key');

# validation (no request leaves)
$mech->get_ok("$base/ajax/satellite/scenes?$area&start=2026-01-01&end=2026-02-01&sources=");
like(decode_json($mech->content)->{error}, qr/No satellite chosen/, 'a satellite is needed');
$mech->get_ok("$base/ajax/satellite/scenes?$area&start=2026-01-01&end=2026-02-01&sources=sentinel2,modis");
like(decode_json($mech->content)->{error}, qr/Unknown satellite: modis/, 'unknown satellite');
$mech->get_ok("$base/ajax/satellite/scenes?$area&start=2012-01-01&end=2013-01-01&sources=sentinel2,landsat");
like(decode_json($mech->content)->{error}, qr/Landsat 8 images start/, 'before Landsat 8');

SKIP: {
    skip 'set SATELLITE_NETWORK_TESTS=1 to search the real Landsat catalogue', 7 if !$ENV{SATELLITE_NETWORK_TESTS};
    $mech->get_ok("$base/ajax/satellite/scenes?$area&start=2025-06-01&end=2025-07-31&sources=sentinel2,landsat");
    my $r = decode_json($mech->content);
    ok(!$r->{error}, 'no error') or diag($r->{error});
    my @ls = grep { $_->{source} eq 'landsat' } @{ $r->{scenes} || [] };
    ok(@ls >= 3, 'several Landsat dates over Ithaca in June-July');
    like($ls[0]{qa} // '', qr{^https://.+_QA_PIXEL\.TIF$}, 'Landsat cloud mask');
    ok(($r->{landsat_token} || {})->{token}, 'read token');
    $mech->get_ok("$base/ajax/satellite/landsat_token");
    ok(decode_json($mech->content)->{token}, 'fresh token');
}

done_testing();


# Weather page endpoints (/ajax/weather/*) on the fixture. Requests that reach
# the external weather services only run with WEATHER_NETWORK_TESTS=1.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $base = 'http://localhost:3010';
my $mech = Test::WWW::Mechanize->new;

my $loc = $schema->resultset('NaturalDiversity::NdGeolocation')->find({ description => 'test_location' });
ok($loc, 'fixture location');
my $loc_id = $loc->nd_geolocation_id;
my ($old_lat, $old_lon) = ($loc->latitude, $loc->longitude);
$loc->update({ latitude => -22.70, longitude => -47.62, altitude => 580 });

# logged out
$mech->get("$base/ajax/weather/config");
is($mech->status, 401, 'config needs login');

$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ]);

$mech->get_ok("$base/breeders/weather", 'page');
$mech->content_contains('wx-app', 'page body');

$mech->get_ok("$base/ajax/weather/config");
my $cfg = decode_json($mech->content);
is($cfg->{range}, 200, 'default range 200');
is($cfg->{unit}, 'km', 'default unit km');
ok($cfg->{networks}{airport}, 'airport network enabled');
is($cfg->{can_save}, 1, 'janedoe (curator) can save');

$mech->get_ok("$base/ajax/weather/locations");
my ($l) = grep { $_->{id} == $loc_id } @{decode_json($mech->content)->{locations}};
ok($l, 'location listed');
is($l->{lat} + 0, -22.7, 'with latitude');
ok(!$l->{station}, 'no weather station yet');

# validation
$mech->get_ok("$base/ajax/weather/nearby?location_id=999999999");
like(decode_json($mech->content)->{error}, qr/not found/, 'unknown location');
$mech->get_ok("$base/ajax/weather/daily?location_id=$loc_id&network=airport&station=SBKP&start=2026-02-01&end=2026-01-01");
like(decode_json($mech->content)->{error}, qr/before/, 'start after end');
$mech->get_ok("$base/ajax/weather/daily?location_id=$loc_id&network=airport&station=SBKP&start=2020-01-01&end=2026-01-01");
like(decode_json($mech->content)->{error}, qr/too long/, 'date range limit');
$mech->get_ok("$base/ajax/weather/daily?location_id=$loc_id&network=airport&station=bad%3Cid&start=2026-01-01&end=2026-01-02");
like(decode_json($mech->content)->{error}, qr/Choose a weather station/, 'bad station id');
$mech->get_ok("$base/ajax/weather/daily?location_id=$loc_id&network=other&station=SBKP&start=2026-01-01&end=2026-01-02");
like(decode_json($mech->content)->{error}, qr/Choose a weather station/, 'unknown network');

# save and clear the station of the location
$mech->post_ok("$base/ajax/weather/save_station", [ location_id => $loc_id, network => 'airport', station_id => 'SBKP',
    name => 'Campinas/Viracopos', lat => -23.007, lon => -47.135, elev => 659, distance_km => 58.6, range => 100, unit => 'mi' ]);
my $saved = decode_json($mech->content);
is($saved->{success}, 1, 'station saved');
is($saved->{station}{unit}, 'mi', 'unit kept');

$mech->get_ok("$base/ajax/weather/locations");
($l) = grep { $_->{id} == $loc_id } @{decode_json($mech->content)->{locations}};
is($l->{station}{station_id}, 'SBKP', 'location now has its weather station');
is($l->{station}{range}, 100, 'with its range');

$mech->post_ok("$base/ajax/weather/save_station", [ location_id => $loc_id, network => 'airport', station_id => 'SBGR', name => 'Guarulhos', range => 200, unit => 'km' ]);
my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'weather_station', 'geolocation_property')->cvterm_id;
is($schema->resultset('NaturalDiversity::NdGeolocationprop')->search({ nd_geolocation_id => $loc_id, type_id => $type_id })->count, 1, 'saving again replaces the station');

# a rain gauge with a second station for temperature
$mech->post_ok("$base/ajax/weather/save_station", [ location_id => $loc_id, network => 'cemaden', station_id => '19563', name => 'G2-316720201A (Sete Lagoas)',
    range => 200, unit => 'km', temp_network => 'airport', temp_station_id => 'SBCF', temp_name => 'Belo Horizonte/Neves Intl', temp_distance_km => 34.9 ]);
$saved = decode_json($mech->content);
is($saved->{station}{temp_station_id}, 'SBCF', 'temperature station saved with the rain gauge');
$mech->post_ok("$base/ajax/weather/save_station", [ location_id => $loc_id, network => 'cemaden', station_id => '19563', temp_network => 'moon', temp_station_id => 'X1' ]);
like(decode_json($mech->content)->{error}, qr/temperature station/, 'network of the temperature station checked');

$mech->post_ok("$base/ajax/weather/save_station", [ location_id => $loc_id, network => 'nowhere', station_id => 'SBGR' ]);
like(decode_json($mech->content)->{error}, qr/Unknown station network/, 'network checked');

$mech->post_ok("$base/ajax/weather/clear_station", [ location_id => $loc_id ]);
is(decode_json($mech->content)->{success}, 1, 'station removed');
is($schema->resultset('NaturalDiversity::NdGeolocationprop')->search({ nd_geolocation_id => $loc_id, type_id => $type_id })->count, 0, 'prop deleted');

$mech->get_ok("$base/ajax/weather/trials?location_id=$loc_id");
ok(ref(decode_json($mech->content)->{trials}) eq 'ARRAY', 'trials of the location');

SKIP: {
    skip 'set WEATHER_NETWORK_TESTS=1 to query the weather services', 4 if !$ENV{WEATHER_NETWORK_TESTS};
    $mech->get_ok("$base/ajax/weather/nearby?location_id=$loc_id&range=200&unit=km");
    my $n = decode_json($mech->content);
    ok(scalar(grep { $_->{id} eq 'SBKP' } @{$n->{stations}}), 'Viracopos within 200 km');
    $mech->get_ok("$base/ajax/weather/daily?location_id=$loc_id&network=airport&station=SBKP&start=2026-10-01&end=2026-10-07&lat=-23.007&lon=-47.135&elev=659");
    ok(scalar(@{decode_json($mech->content)->{days}}) >= 5, 'daily observations of an airport');
}

$loc->update({ latitude => $old_lat, longitude => $old_lon });
$f->clean_up_db();

done_testing();

# Satellite page endpoints (/ajax/satellite/*) on the fixture. The search in the
# real Sentinel-2 catalogue only runs with SATELLITE_NETWORK_TESTS=1.

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
my $trial = $schema->resultset('Project::Project')->find({ name => 'test_trial' });
ok($trial, 'fixture trial');
my $trial_id = $trial->project_id;

my @added;
END {
    local $?;
    eval { $_->delete for @added; 1 } or diag("could not remove the test plot coordinates: $@");
    eval { $f->clean_up_db(); 1 } or diag("clean_up_db failed: $@");
}

# logged out
$mech->get("$base/ajax/satellite/locations");
is($mech->status, 401, 'locations need login');
$mech->get("$base/breeders/satellite");
like($mech->uri, qr{/user/login}, 'page sends to login');

$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ]);

$mech->get_ok("$base/breeders/satellite", 'page');
$mech->content_contains('sat-app', 'page body');

$mech->get_ok("$base/ajax/satellite/locations");
my ($l) = grep { $_->{id} == $loc_id } @{ decode_json($mech->content)->{locations} };
ok($l, 'location listed');
is($l->{name}, 'test_location', 'location name');

$mech->get_ok("$base/ajax/satellite/trials?location_id=$loc_id");
my ($t) = grep { $_->{id} == $trial_id } @{ decode_json($mech->content)->{trials} };
ok($t, 'test_trial listed for its location');
$mech->get_ok("$base/ajax/satellite/trials");
like(decode_json($mech->content)->{error}, qr/No location/, 'trials need a location');

# field: no plot coordinates in the fixture
$mech->get_ok("$base/ajax/satellite/field?trial_id=$trial_id");
my $field = decode_json($mech->content);
is($field->{count}, 0, 'no plot coordinates yet');
is_deeply($field->{plots}, [], 'no plots');

# give two plots GPS coordinates (a polygon and a point)
my $geo_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_geo_json', 'stock_property');
ok($geo_type, 'plot_geo_json cvterm');
my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id;
my @plots = map { $_->[0] } @{ $schema->storage->dbh->selectall_arrayref(
    "SELECT DISTINCT s.stock_id FROM stock s
     JOIN nd_experiment_stock nes ON (nes.stock_id = s.stock_id)
     JOIN nd_experiment_project nep ON (nep.nd_experiment_id = nes.nd_experiment_id)
     WHERE s.type_id = ? AND nep.project_id = ? ORDER BY s.stock_id LIMIT 2", undef, $plot_type_id, $trial_id) };
is(scalar @plots, 2, 'two plots of test_trial');
my %geo = (
    $plots[0] =>{ type => 'Feature', geometry => { type => 'Polygon', coordinates => [ [ [-76.47, 42.45], [-76.4699, 42.45], [-76.4699, 42.4501], [-76.47, 42.4501], [-76.47, 42.45] ] ] }, properties => { format => 'WGS84' } },
    $plots[1] =>{ type => 'Feature', geometry => { type => 'Point', coordinates => [ -76.4697, 42.4503 ] }, properties => { format => 'WGS84' } },
);
foreach my $id (keys %geo) {
    push @added, $schema->resultset('Stock::Stockprop')->create({ stock_id => $id, type_id => $geo_type->cvterm_id, value => encode_json($geo{$id}), rank => 0 });
}
$mech->get_ok("$base/ajax/satellite/field?trial_id=$trial_id");
$field = decode_json($mech->content);
is($field->{count}, 2, 'two plots with coordinates');
is_deeply($field->{bbox}, [ -76.47, 42.45, -76.4697, 42.4503 ], 'field bounding box');
$mech->get_ok("$base/ajax/satellite/field?trial_id=abc");
like(decode_json($mech->content)->{error}, qr/No trial/, 'field needs a trial id');

# scenes: validation (no request leaves)
$mech->get_ok("$base/ajax/satellite/scenes?west=-76.48&south=42.44&east=-76.46&north=42.46&start=2026-02-01&end=2026-01-01");
like(decode_json($mech->content)->{error}, qr/after the end/, 'start after end');
$mech->get_ok("$base/ajax/satellite/scenes?west=-76.48&south=42.44&east=-76.46&start=2026-01-01&end=2026-02-01");
like(decode_json($mech->content)->{error}, qr/No area/, 'area needed');

SKIP: {
    skip 'set SATELLITE_NETWORK_TESTS=1 to search the real Sentinel-2 catalogue', 4 if !$ENV{SATELLITE_NETWORK_TESTS};
    $mech->get_ok("$base/ajax/satellite/scenes?west=-76.48&south=42.44&east=-76.46&north=42.46&start=2025-06-01&end=2025-06-30");
    my $r = decode_json($mech->content);
    ok(!$r->{error}, 'no error') or diag($r->{error});
    ok(@{ $r->{scenes} || [] } >= 3, 'several June dates over Ithaca');
    like($r->{scenes}[0]{scl} // '', qr{^https://.+/SCL\.tif$}, 'scene classification image');
}

done_testing();

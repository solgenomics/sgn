# CXGN::Satellite: Sentinel-2 scene search (fake STAC catalogue, no network) and
# the field area from plot GPS coordinates.

use strict;
use warnings;

use Test::More;
use JSON;
use LWP::UserAgent;
use HTTP::Response;
use CXGN::Satellite;

# ------------------------------------------------------------ fake catalogue
my $fake = { pages => [], log => [], down => 0 };
my $ua = LWP::UserAgent->new();
$ua->add_handler(request_send => sub {
    my $req = shift;
    push @{$fake->{log}}, { method => $req->method, uri => $req->uri . '', body => decode_json($req->content) };
    return HTTP::Response->new(503, 'Service Unavailable') if $fake->{down};
    my $page = shift @{$fake->{pages}} // { type => 'FeatureCollection', features => [], links => [] };
    return HTTP::Response->new(200, 'OK', [ 'Content-Type' => 'application/geo+json' ], encode_json($page));
});

sub item {
    my (%a) = @_;
    my $id = $a{id};
    my $base = "https://sentinel-cogs.example/$id";
    return {
        id => $id,
        bbox => $a{bbox} // [ -45.0, -20.0, -43.9, -18.9 ],
        properties => {
            datetime => $a{datetime},
            platform => 'sentinel-2b',
            'eo:cloud_cover' => $a{cloud} // 10.4,
            'proj:epsg' => $a{epsg} // 32723,
            'grid:code' => 'MGRS-' . ($a{tile} // '23KNU'),
            's2:processing_baseline' => '05.11',
            updated => $a{updated} // '2026-11-17T00:00:00Z',
        },
        assets => {
            visual => { href => "$base/TCI.tif" },
            red => { href => "$base/B04.tif", 'raster:bands' => [ { scale => 0.0001, offset => -0.1 } ] },
            nir => { href => "$base/B08.tif" },
            scl => { href => "$base/SCL.tif" },
        },
    };
}

my $sat = CXGN::Satellite->new({ stac_url => 'https://stac.example/v1', ua => $ua });
my $bbox = [ -44.26, -19.47, -44.24, -19.45 ];

# ------------------------------------------------------------ validation
like($sat->scenes({ bbox => [1, 2, 3], start => '2026-01-01', end => '2026-02-01' })->{error}, qr/No area/, 'bbox needs 4 numbers');
like($sat->scenes({ bbox => [1, 'x', 3, 4], start => '2026-01-01', end => '2026-02-01' })->{error}, qr/No area/, 'bbox numbers only');
like($sat->scenes({ bbox => [3, 2, 1, 4], start => '2026-01-01', end => '2026-02-01' })->{error}, qr/Invalid area/, 'west after east');
like($sat->scenes({ bbox => $bbox, start => '2026/01/01', end => '2026-02-01' })->{error}, qr/YYYY-MM-DD/, 'date format');
like($sat->scenes({ bbox => $bbox, start => '2026-03-01', end => '2026-02-01' })->{error}, qr/after the end/, 'start after end');
like($sat->scenes({ bbox => $bbox, start => '2023-01-01', end => '2026-02-01' })->{error}, qr/longer than 731 days/, 'range too long');
like($sat->scenes({ bbox => $bbox, start => '2015-01-01', end => '2016-06-01' })->{error}, qr/start in 2017/, 'before Sentinel-2 L2A');
is(scalar @{$fake->{log}}, 0, 'no request for invalid input');

# ------------------------------------------------------------ search, paging, one scene per date
$fake->{pages} = [
    {
        features => [
            item(id => 'S2B_23KNU_20261116_0_L2A', datetime => '2026-11-16T13:17:38Z'),
            item(id => 'S2B_23KNU_20261116_1_L2A', datetime => '2026-11-16T13:17:38Z'),    # reprocessed copy: kept
            item(id => 'S2C_23KNU_20261111_0_L2A', datetime => '2026-11-11T13:17:40Z', cloud => 76.9),
        ],
        links => [ { rel => 'next', href => 'https://stac.example/v1/search', method => 'POST', body => { next => 'token-2' } } ],
    },
    {
        features => [
            # same date in the neighbour tile, which does not hold the whole area: dropped
            item(id => 'S2C_23KPU_20261111_0_L2A', datetime => '2026-11-11T13:17:41Z', tile => '23KPU', bbox => [ -44.25, -20.0, -43.0, -18.9 ]),
            item(id => 'S2A_23KNU_20261103_0_L2A', datetime => '2026-11-03T13:17:43Z'),
            { id => 'broken', properties => { datetime => '2026-11-01T00:00:00Z' }, assets => {} },    # no images: skipped
        ],
        links => [],
    },
];
my $res = $sat->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20' });
ok(!$res->{error}, 'no error') or diag($res->{error});
is(scalar @{$fake->{log}}, 2, 'two pages read');
my $first = $fake->{log}[0];
is($first->{uri}, 'https://stac.example/v1/search', 'search url');
is($first->{method}, 'POST', 'POST search');
is_deeply($first->{body}{collections}, [ 'sentinel-2-l2a' ], 'collection');
is_deeply($first->{body}{bbox}, $bbox, 'bbox sent');
is($first->{body}{datetime}, '2026-11-01T00:00:00Z/2026-11-20T23:59:59Z', 'datetime sent');
is_deeply($fake->{log}[1]{body}, { next => 'token-2' }, 'next page body sent');

my $sc = $res->{scenes};
is_deeply([ map { $_->{id} } @$sc ], [ 'S2A_23KNU_20261103_0_L2A', 'S2C_23KNU_20261111_0_L2A', 'S2B_23KNU_20261116_1_L2A' ], 'one scene per date, oldest first');
my $s = $sc->[1];
is($s->{date}, '2026-11-11', 'date');
is($s->{tile}, '23KNU', 'tile without MGRS- prefix');
is($s->{tile_cloud}, 77, 'tile cloud rounded');
is($s->{epsg}, 32723, 'epsg');
is($s->{covers}, 1, 'tile holds the area');
like($s->{visual}, qr{/TCI\.tif$}, 'true colour image');
like($s->{scl}, qr{/SCL\.tif$}, 'scene classification');
is($s->{red_offset}, -0.1, 'reflectance offset from raster:bands');
is($s->{red_scale}, 0.0001, 'reflectance scale');
ok(!exists $s->{_rank}, 'internal rank removed');

# an area only in a neighbour tile is still found
$fake->{log} = [];
$fake->{pages} = [ { features => [ item(id => 'S2C_23KPU_20261111_0_L2A', datetime => '2026-11-11T13:17:41Z', tile => '23KPU', bbox => [ -44.25, -20.0, -43.0, -18.9 ]) ] } ];
$res = $sat->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20' });
is(scalar @{$res->{scenes}}, 1, 'partial tile kept when it is the only one');
is($res->{scenes}[0]{covers}, 0, 'marked as not covering');

# proj:code instead of proj:epsg (newer STAC)
$fake->{pages} = [ { features => [ do { my $i = item(id => 'S2A_31TCJ_20260601_0_L2A', datetime => '2026-06-01T10:00:00Z'); delete $i->{properties}{'proj:epsg'}; $i->{properties}{'proj:code'} = 'EPSG:32631'; $i } ] } ];
$res = $sat->scenes({ bbox => $bbox, start => '2026-06-01', end => '2026-06-02' });
is($res->{scenes}[0]{epsg}, 32631, 'epsg from proj:code');

# catalogue down
$fake->{down} = 1;
like($sat->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20' })->{error}, qr/did not answer: 503/, 'catalogue down');
$fake->{down} = 0;

# ------------------------------------------------------------ field geometry
my $poly = encode_json({ type => 'Feature', geometry => { type => 'Polygon', coordinates => [ [ [-44.25, -19.46], [-44.249, -19.46], [-44.249, -19.459], [-44.25, -19.459], [-44.25, -19.46] ] ] }, properties => { format => 'WGS84' } });
my $poly2 = encode_json({ type => 'Polygon', coordinates => [ [ [-44.248, -19.458], [-44.247, -19.458], [-44.247, -19.457], [-44.248, -19.458] ] ] });    # bare geometry
my $point = encode_json({ type => 'Feature', geometry => { type => 'Point', coordinates => [ -44.251, -19.461 ] } });
my $g = $sat->field_geometry($poly, $poly2, $point, 'not json', encode_json({ type => 'Point', coordinates => [ 500, 0 ] }));
is(scalar @{$g->{plots}}, 3, 'two polygons and a point read, bad values skipped');
is_deeply($g->{bbox}, [ -44.251, -19.461, -44.247, -19.457 ], 'bounding box');
is(scalar @{$g->{plots}[2]}, 1, 'a point is a ring of one');
ok(!defined $sat->field_geometry(), 'no plots: undef');
ok(!defined $sat->field_geometry('{}', 'x'), 'unreadable plots: undef');

done_testing();

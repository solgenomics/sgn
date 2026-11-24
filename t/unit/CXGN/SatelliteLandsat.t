# CXGN::Satellite: Landsat 8/9 as a second source next to Sentinel-2 (fake
# catalogues and token service, no network).

use strict;
use warnings;

use Test::More;
use JSON;
use LWP::UserAgent;
use HTTP::Response;
use POSIX qw(strftime);
use CXGN::Satellite;

# ------------------------------------------------------------ fake services
# s2 / landsat: pages of the two catalogues; token: answer of the token service
my $fake = { s2 => [], landsat => [], log => [], s2_down => 0, landsat_down => 0, token_down => 0, token_expiry => undef };
my $ua = LWP::UserAgent->new();
$ua->add_handler(request_send => sub {
    my $req = shift;
    my $uri = $req->uri . '';
    my $body = length($req->content // '') ? decode_json($req->content) : undef;
    push @{$fake->{log}}, { method => $req->method, uri => $uri, body => $body };
    my $json = sub { HTTP::Response->new(200, 'OK', [ 'Content-Type' => 'application/json' ], encode_json(shift)) };
    if ($uri =~ m{^https://token\.example/}) {
        return HTTP::Response->new(500, 'Internal Server Error') if $fake->{token_down};
        return $json->({ 'msft:expiry' => $fake->{token_expiry} // strftime('%Y-%m-%dT%H:%M:%SZ', gmtime(time() + 3600)), token => 'st=x&sig=abc' });
    }
    my $which = $uri =~ m{^https://pc\.example/} ? 'landsat' : 's2';
    return HTTP::Response->new(503, 'Service Unavailable') if $fake->{"${which}_down"};
    my $page = shift @{$fake->{$which}} // { features => [], links => [] };
    return $json->($page);
});

sub s2_item {
    my (%a) = @_;
    my $base = "https://sentinel-cogs.example/$a{id}";
    return {
        id => $a{id}, bbox => [ -45.0, -20.0, -43.9, -18.9 ],
        properties => { datetime => $a{datetime}, platform => 'sentinel-2b', 'eo:cloud_cover' => 5, 'proj:epsg' => 32723, 'grid:code' => 'MGRS-23KNU' },
        assets => { visual => { href => "$base/TCI.tif" }, red => { href => "$base/B04.tif" }, nir => { href => "$base/B08.tif" }, scl => { href => "$base/SCL.tif" } },
    };
}

sub ls_item {
    my (%a) = @_;
    my $base = "https://landsat.example/$a{id}/$a{id}";
    return {
        id => $a{id},
        bbox => $a{bbox} // [ -45.5, -20.5, -43.5, -18.5 ],
        properties => {
            datetime => $a{datetime},
            platform => $a{platform} // 'landsat-9',
            'eo:cloud_cover' => $a{cloud} // 40.6,
            'proj:epsg' => 32623,
            'landsat:wrs_path' => $a{path} // '219',
            'landsat:wrs_row' => $a{row} // '074',
            'landsat:collection_category' => $a{category} // 'T1',
        },
        assets => {
            red => { href => "${base}_SR_B4.TIF", 'raster:bands' => [ { scale => 2.75e-05, offset => -0.2, nodata => 0 } ] },
            green => { href => "${base}_SR_B3.TIF" },
            blue => { href => "${base}_SR_B2.TIF" },
            nir08 => { href => "${base}_SR_B5.TIF" },
            qa_pixel => { href => "${base}_QA_PIXEL.TIF" },
        },
    };
}

my $n_token = 0;
sub sat {    # a new token url each time: the token cache is per url
    $n_token++;
    return CXGN::Satellite->new({ stac_url => 'https://stac.example/v1', landsat_stac_url => 'https://pc.example/api/stac/v1',
        landsat_token_url => "https://token.example/landsat-$n_token", ua => $ua });
}
sub reset_fake { $fake->{log} = []; $fake->{s2} = []; $fake->{landsat} = []; $fake->{$_} = 0 for qw(s2_down landsat_down token_down); $fake->{token_expiry} = undef }
my $bbox = [ -44.26, -19.47, -44.24, -19.45 ];
my $both = [ 'sentinel2', 'landsat' ];

# ------------------------------------------------------------ validation
my $sat = sat();
like($sat->scenes({ bbox => $bbox, start => '2026-01-01', end => '2026-02-01', sources => [] })->{error}, qr/No satellite chosen/, 'a satellite is needed');
like($sat->scenes({ bbox => $bbox, start => '2026-01-01', end => '2026-02-01', sources => [ 'modis' ] })->{error}, qr/Unknown satellite: modis/, 'unknown satellite');
like($sat->scenes({ bbox => $bbox, start => '2012-01-01', end => '2013-01-01', sources => $both })->{error}, qr/Landsat 8 images start in April 2013/, 'before Landsat 8');
like($sat->scenes({ bbox => $bbox, start => '2015-01-01', end => '2016-06-01', sources => [ 'sentinel2' ] })->{error}, qr/start in 2017/, 'Sentinel-2 only: still before 2017');
is(scalar @{$fake->{log}}, 0, 'no request for invalid input');

# ------------------------------------------------------------ both satellites
reset_fake();
$fake->{s2} = [ { features => [ s2_item(id => 'S2B_23KNU_20261116_0_L2A', datetime => '2026-11-16T13:17:38Z') ] } ];
$fake->{landsat} = [
    {
        features => [
            ls_item(id => 'LC09_L2SP_219074_20261116_02_T1', datetime => '2026-11-16T13:04:30Z'),
            # same date, next row, does not hold the whole area: dropped
            ls_item(id => 'LC09_L2SP_219075_20261116_02_T1', datetime => '2026-11-16T13:04:54Z', row => '075', bbox => [ -44.25, -21.0, -43.0, -19.0 ]),
            # Landsat 7 even if the catalogue sends it: skipped
            ls_item(id => 'LE07_L2SP_219074_20261110_02_T1', datetime => '2026-11-10T12:30:00Z', platform => 'landsat-7'),
        ],
        links => [ { rel => 'next', href => 'https://pc.example/api/stac/v1/search', method => 'POST', body => { token => 'next:2' } } ],
    },
    {
        features => [
            ls_item(id => 'LC08_L2SP_219074_20261108_02_T2', datetime => '2026-11-08T13:04:30Z', platform => 'landsat-8', category => 'T2'),
            ls_item(id => 'LC08_L2SP_219074_20261108_02_T1', datetime => '2026-11-08T13:04:31Z', platform => 'landsat-8'),    # Tier 1 preferred
            { id => 'broken', properties => { datetime => '2026-11-01T00:00:00Z', platform => 'landsat-9' }, assets => {} },
        ],
    },
];
my $res = $sat->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20', sources => $both });
ok(!$res->{error}, 'no error') or diag($res->{error});
is_deeply($res->{warnings}, [], 'no warning');

my @ls_req = grep { $_->{uri} =~ m{^https://pc\.example/} } @{$fake->{log}};
is(scalar @ls_req, 2, 'two Landsat pages read');
is($ls_req[0]{uri}, 'https://pc.example/api/stac/v1/search', 'Landsat search url');
is_deeply($ls_req[0]{body}{collections}, [ 'landsat-c2-l2' ], 'Landsat collection');
is_deeply($ls_req[0]{body}{filter}, { op => 'in', args => [ { property => 'platform' }, [ 'landsat-8', 'landsat-9' ] ] }, 'only Landsat 8 and 9 asked');
is($ls_req[0]{body}{'filter-lang'}, 'cql2-json', 'filter language');
is_deeply($ls_req[1]{body}, { token => 'next:2' }, 'next page body sent');
is(scalar(grep { $_->{uri} =~ m{^https://stac\.example/} } @{$fake->{log}}), 1, 'Sentinel-2 searched too');
is(scalar(grep { $_->{uri} =~ m{^https://token\.example/} } @{$fake->{log}}), 1, 'one token asked');

is_deeply([ map { "$_->{source} $_->{id}" } @{$res->{scenes}} ], [
    'landsat LC08_L2SP_219074_20261108_02_T1',
    'landsat LC09_L2SP_219074_20261116_02_T1',
    'sentinel2 S2B_23KNU_20261116_0_L2A',
], 'one scene per satellite and date, oldest first, both satellites');
my ($l) = grep { $_->{id} eq 'LC09_L2SP_219074_20261116_02_T1' } @{$res->{scenes}};
is($l->{date}, '2026-11-16', 'date');
is($l->{platform}, 'landsat-9', 'platform');
is($l->{tile}, '219/074', 'path/row');
is($l->{tile_cloud}, 41, 'scene cloud rounded');
is($l->{epsg}, 32623, 'epsg');
is($l->{covers}, 1, 'scene holds the area');
is($l->{res}, 30, '30 m pixels');
like($l->{nir}, qr/_SR_B5\.TIF$/, 'NIR is band 5 (nir08)');
like($l->{qa}, qr/_QA_PIXEL\.TIF$/, 'cloud mask');
like($l->{$_->[0]}, $_->[1], "$_->[0] band") for [ red => qr/_SR_B4\.TIF$/ ], [ green => qr/_SR_B3\.TIF$/ ], [ blue => qr/_SR_B2\.TIF$/ ];
is($l->{red_scale}, 2.75e-05, 'reflectance scale');
is($l->{red_offset}, -0.2, 'reflectance offset');
ok(!exists $l->{_rank}, 'internal rank removed');
my ($s2) = grep { $_->{source} eq 'sentinel2' } @{$res->{scenes}};
is($s2->{res}, 10, 'Sentinel-2 10 m pixels');
is_deeply($res->{landsat_token}, { token => 'st=x&sig=abc', expiry => $res->{landsat_token}{expiry} }, 'read token returned');
like($res->{landsat_token}{expiry}, qr/^\d{4}-\d\d-\d\dT/, 'token expiry');

# ------------------------------------------------------------ token cache
$fake->{log} = [];
is($sat->landsat_token()->{token}, 'st=x&sig=abc', 'token again');
is(scalar @{$fake->{log}}, 0, 'from the cache');
my $soon = sat();
$fake->{token_expiry} = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime(time() + 300));
$soon->landsat_token();
$soon->landsat_token();
is(scalar(grep { $_->{uri} =~ m{^https://token\.example/} } @{$fake->{log}}), 2, 'a token about to expire is not reused');

# ------------------------------------------------------------ Landsat alone, early dates, failures
reset_fake();
$res = sat()->scenes({ bbox => $bbox, start => '2014-01-01', end => '2014-12-31', sources => [ 'landsat' ] });
ok(!$res->{error}, 'Landsat alone before 2017') or diag($res->{error});
is(scalar(grep { $_->{uri} =~ m{^https://stac\.example/} } @{$fake->{log}}), 0, 'Sentinel-2 not searched');

reset_fake();
$res = sat()->scenes({ bbox => $bbox, start => '2016-06-01', end => '2017-03-01', sources => $both });
like(join(' ', @{$res->{warnings}}), qr/earlier dates are Landsat only/, 'range across 2017: warned');

reset_fake();
$res = sat()->scenes({ bbox => $bbox, start => '2013-01-01', end => '2013-06-01', sources => [ 'landsat' ] });
is($fake->{log}[0]{body}{datetime}, '2013-04-11T00:00:00Z/2013-06-01T23:59:59Z', 'search starts at Landsat 8');

reset_fake();
$fake->{token_down} = 1;
$fake->{s2} = [ { features => [ s2_item(id => 'S2B_23KNU_20261116_0_L2A', datetime => '2026-11-16T13:17:38Z') ] } ];
$fake->{landsat} = [ { features => [ ls_item(id => 'LC09_L2SP_219074_20261116_02_T1', datetime => '2026-11-16T13:04:30Z') ] } ];
$res = sat()->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20', sources => $both });
is_deeply([ map { $_->{source} } @{$res->{scenes}} ], [ 'sentinel2' ], 'no token: Sentinel-2 still shown');
like(join(' ', @{$res->{warnings}}), qr/Landsat images cannot be opened: Planetary Computer did not answer: 500/, 'no token: warned');
ok(!$res->{landsat_token}, 'no token returned');

reset_fake();
$fake->{token_down} = 1;
like(sat()->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20', sources => [ 'landsat' ] })->{error}, qr/cannot be opened/, 'Landsat alone without token: error');

reset_fake();
$fake->{s2_down} = 1;
$fake->{landsat} = [ { features => [ ls_item(id => 'LC09_L2SP_219074_20261116_02_T1', datetime => '2026-11-16T13:04:30Z') ] } ];
$res = sat()->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20', sources => $both });
is_deeply([ map { $_->{source} } @{$res->{scenes}} ], [ 'landsat' ], 'Earth Search down: Landsat still shown');
like(join(' ', @{$res->{warnings}}), qr/\(Earth Search\) did not answer: 503/, 'Earth Search down: warned');

reset_fake();
$fake->{s2_down} = 1;
$fake->{landsat_down} = 1;
like(sat()->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20', sources => $both })->{error},
    qr/Earth Search\) did not answer.*Planetary Computer\) did not answer/, 'both down: error naming both');

# ------------------------------------------------------------ Sentinel-2 reflectance offset
# Earth Search lists offset -0.1 in raster:bands but has already applied it to the pixels
# (earthsearch:boa_offset_applied): applied twice, red goes negative and NDVI near 1.
reset_fake();
my $applied = s2_item(id => 'S2A_23KKQ_20261103_0_L2A', datetime => '2026-11-03T13:17:38Z');
$applied->{properties}{'earthsearch:boa_offset_applied'} = JSON::true;
$applied->{assets}{red}{'raster:bands'} = [ { scale => 0.0001, offset => -0.1 } ];
my $raw = s2_item(id => 'S2A_23KKQ_20261104_0_L2A', datetime => '2026-11-04T13:17:38Z');
$raw->{properties}{'earthsearch:boa_offset_applied'} = JSON::false;
$raw->{assets}{red}{'raster:bands'} = [ { scale => 0.0001, offset => -0.1 } ];
$fake->{s2} = [ { features => [ $applied, $raw ] } ];
$res = sat()->scenes({ bbox => $bbox, start => '2026-11-01', end => '2026-11-20' });
is($res->{scenes}[0]{red_offset}, 0, 'offset already applied by Earth Search: not applied again');
is($res->{scenes}[1]{red_offset}, -0.1, 'offset not applied yet: kept');
ok((grep { $_ eq 'properties.earthsearch:boa_offset_applied' } @{ $fake->{log}[0]{body}{fields}{include} }), 'flag asked from the catalogue');

done_testing();

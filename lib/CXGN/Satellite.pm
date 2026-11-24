package CXGN::Satellite;

=head1 NAME

CXGN::Satellite - free satellite scenes (Sentinel-2, Landsat 8/9) of a field for a date range

=head1 SYNOPSIS

  my $sat = CXGN::Satellite->new();
  my $res = $sat->scenes({ bbox => [$west, $south, $east, $north], start => '2026-01-01', end => '2026-06-30',
      sources => [ 'sentinel2', 'landsat' ] });

=head1 DESCRIPTION

Two free archives, searched in open STAC catalogues (no key):

Sentinel-2 Level-2A (ESA Copernicus, 10 m, a new image every ~5 days since
2017) in Earth Search (earth-search.aws.element84.com). The images are
Cloud-Optimized GeoTIFFs on a public AWS bucket.

Landsat 8 and 9 Collection 2 Level-2 (USGS/NASA, 30 m, together a new image
every ~8 days, Landsat 8 since 2013) in Microsoft Planetary Computer. Its
copies of the images are readable from a browser with a free read token
(B<landsat_token>, valid about an hour), unlike the requester-pays USGS
bucket that Earth Search points to.

The browser reads only the part around the field
(js/source/modules/cog_reader.js).

=head2 Adding a satellite (e.g. a paid one)

Each satellite is an entry in %SOURCES (name, pixel size, revisit, first
date, paid) and a search method C<_E<lt>idE<gt>> that returns
{ scenes => [...] } in the scene format of B<scenes>. A paid satellite names
the attribute that holds its key (C<key>, set from sgn.conf by
SGN::Controller::AJAX::Satellite); B<sources> lists it only when that key is
set and its search method exists.

PlanetScope (3 m, daily) is prepared this way: its key is read from
satellite_planet_api_key, but the method C<_planet> is not written yet (it
needs a Planet account to build and test), so it is never offered. Unlike the
free satellites, its images cannot be read by the browser (the key would be
visible): the server must order the clipped image (Planet Orders API), keep it,
and send it to the page, as a background job (orders take minutes), with a
limit on the area ordered (each km2 uses the organisation's quota).

Earth Search lists some Sentinel-2 dates twice (a reprocessed copy, id ending
_1), and a field near the edge of a tile (Sentinel-2) or of a scene (Landsat
path/row) is in two of them: B<scenes> keeps one scene per satellite and date,
the one that holds the whole area (then: latest processing, Landsat Tier 1).

=head1 AUTHOR

Chris Simoes

=cut

use Moose;
use JSON;
use LWP::UserAgent;
use HTTP::Request;
use Try::Tiny;
use Time::Local;

has 'planet_api_key' => (isa => 'Maybe[Str]', is => 'rw');
has 'stac_url' => (isa => 'Str', is => 'rw', default => 'https://earth-search.aws.element84.com/v1');
has 'collection' => (isa => 'Str', is => 'rw', default => 'sentinel-2-l2a');
has 'landsat_stac_url' => (isa => 'Str', is => 'rw', default => 'https://planetarycomputer.microsoft.com/api/stac/v1');
has 'landsat_collection' => (isa => 'Str', is => 'rw', default => 'landsat-c2-l2');
has 'landsat_token_url' => (isa => 'Str', is => 'rw', default => 'https://planetarycomputer.microsoft.com/api/sas/v1/token/landsat-c2-l2');
has 'max_days' => (isa => 'Int', is => 'rw', default => 731);
has 'timeout' => (isa => 'Int', is => 'rw', default => 15);
has 'max_pages' => (isa => 'Int', is => 'rw', default => 10);
has 'ua' => (is => 'rw', lazy => 1, default => sub {
    my $self = shift;
    my $ua = LWP::UserAgent->new(timeout => $self->timeout, agent => 'Breedbase satellite');
    $ua->env_proxy;
    return $ua;
});

# The satellites, in the order shown. first_text: error when the whole range is before 'first'.
my @ORDER = qw(sentinel2 landsat planet);
my %SOURCES = (
    sentinel2 => { name => 'Sentinel-2', res => 10, revisit => 5, first => '2017-01-01', paid => 0,
        first_text => 'Sentinel-2 Level-2A images start in 2017.' },
    landsat => { name => 'Landsat 8 and 9', res => 30, revisit => 8, first => '2013-04-11', paid => 0,
        first_text => 'Landsat 8 images start in April 2013.' },
    planet => { name => 'PlanetScope', res => 3, revisit => 1, first => '2016-01-01', paid => 1, key => 'planet_api_key',
        first_text => 'PlanetScope images start in 2016.' },
);
my %FIRST = map { $_ => $SOURCES{$_}{first} } keys %SOURCES;
my %TOKENS;    # token url -> { token, expiry, until (epoch) }: shared by the requests of a server process

=head2 sources

The satellites this server can search: [ { id, name, res (m), revisit (days),
since (year), paid } ] - a paid one only when its key is set and its search
is written. Never contains a key.

=cut

sub sources {
    my $self = shift;
    my @out;
    foreach my $id (@ORDER) {
        next if !$self->source_available($id);
        my $d = $SOURCES{$id};
        push @out, { id => $id, name => $d->{name}, res => $d->{res}, revisit => $d->{revisit}, since => substr($d->{first}, 0, 4) + 0, paid => $d->{paid} };
    }
    return \@out;
}

=head2 source_available

Args: source id. True when the satellite can be searched: its search method
exists and, for a paid one, its key is set.

=cut

sub source_available {
    my ($self, $id) = @_;
    my $d = $SOURCES{$id // ''} or return 0;
    return 0 if !$self->can("_$id");
    my $k = $d->{key};
    return 0 if $k && !length($self->$k // '');
    return 1;
}

=head2 source_without_search

Ids of paid satellites whose key is set but whose search is not written yet
(for a warning in the server log).

=cut

sub source_without_search {
    my $self = shift;
    return grep { my $k = $SOURCES{$_}{key}; $k && length($self->$k // '') && !$self->can("_$_") } @ORDER;
}

=head2 scenes

Args: { bbox => [west, south, east, north] (degrees), start, end (YYYY-MM-DD),
sources => [ 'sentinel2' and/or 'landsat' ] (default sentinel2) }.

Returns { scenes => [ ... ] (oldest first), warnings => [ ... ] } and, when
Landsat is asked, landsat_token => { token, expiry } (append "?token" to its
image urls); or { error => '...' } when no satellite could be searched.

Each scene: { id, source (sentinel2 / landsat), date, datetime, platform,
tile (MGRS tile or Landsat path/row), tile_cloud, epsg, covers, res (metres),
red, nir, red_scale, red_offset } plus visual (true-colour image), scl
(scene classification), green, blue, rededge1 and swir16 for Sentinel-2,
green, blue and qa (QA_PIXEL) for Landsat.

=cut

sub scenes {
    my ($self, $args) = @_;
    my $bbox = $args->{bbox};
    return { error => 'No area given.' } if ref $bbox ne 'ARRAY' || @$bbox != 4 || grep { !defined $_ || $_ !~ /^-?\d+(\.\d+)?$/ } @$bbox;
    my ($w, $s, $e, $n) = @$bbox;
    return { error => 'Invalid area.' } if $w >= $e || $s >= $n || $w < -180 || $e > 180 || $s < -90 || $n > 90;
    my ($start, $end) = ($args->{start} // '', $args->{end} // '');
    return { error => 'Dates must be YYYY-MM-DD.' } if $start !~ /^\d{4}-\d\d-\d\d$/ || $end !~ /^\d{4}-\d\d-\d\d$/;
    return { error => 'The start date is after the end date.' } if $start gt $end;
    my $days = _days($start, $end);
    return { error => 'The date range is longer than ' . $self->max_days . ' days.' } if $days > $self->max_days;
    my @sources = @{ $args->{sources} || [ 'sentinel2' ] };
    return { error => 'No satellite chosen.' } if !@sources;
    my ($bad) = grep { !$SOURCES{$_} } @sources;
    return { error => "Unknown satellite: $bad" } if defined $bad;
    my ($off) = grep { !$self->source_available($_) } @sources;
    return { error => "$SOURCES{$off}{name} is not available on this server." } if defined $off;
    my %want = map { $_ => 1 } @sources;
    @sources = grep { $want{$_} } @ORDER;
    my @usable = grep { $end ge $FIRST{$_} } @sources;
    if (!@usable) {
        my ($earliest) = sort { $FIRST{$a} cmp $FIRST{$b} } @sources;
        return { error => $SOURCES{$earliest}{first_text} };
    }

    my $area = [ map { $_ + 0 } $w, $s, $e, $n ];
    my (@scenes, @warnings, @errors, $token);
    foreach my $src (@usable) {
        my $method = "_$src";
        my $res = $self->$method($area, $start, $end);
        if ($res->{error}) { push @errors, $res->{error}; next; }
        if ($src eq 'landsat') {
            $token = $self->landsat_token();
            if ($token->{error}) { push @errors, 'Landsat images cannot be opened: ' . $token->{error}; next; }
        }
        push @scenes, @{ $res->{scenes} };
    }
    return { error => join(' ', @errors) } if @errors == @usable;
    push @warnings, @errors;
    push @warnings, 'Sentinel-2 images start in 2017: earlier dates are Landsat only.' if $want{sentinel2} && $want{landsat} && $start lt $FIRST{sentinel2} && $end ge $FIRST{sentinel2};
    @scenes = sort { $a->{datetime} cmp $b->{datetime} || $a->{source} cmp $b->{source} } @scenes;
    my $out = { scenes => \@scenes, warnings => \@warnings };
    $out->{landsat_token} = { token => $token->{token}, expiry => $token->{expiry} } if $token && !$token->{error};
    return $out;
}

sub _covers {
    my ($fb, $area) = @_;
    my ($w, $s, $e, $n) = @$area;
    return (ref $fb eq 'ARRAY' && @$fb == 4 && $fb->[0] <= $w && $fb->[1] <= $s && $fb->[2] >= $e && $fb->[3] >= $n) ? 1 : 0;
}

sub _epsg {
    my $p = shift;
    my $epsg = $p->{'proj:epsg'};
    $epsg = $1 if !$epsg && ($p->{'proj:code'} // '') =~ /EPSG:(\d+)/;
    return $epsg ? $epsg + 0 : undef;
}

sub _cloud { my $v = shift; return defined $v ? sprintf('%.0f', $v) + 0 : undef }

# one scene per date: the highest _rank
sub _best_per_date {
    my @list = @_;
    my %by_date;
    foreach my $sc (@list) {
        my $old = $by_date{$sc->{date}};
        $by_date{$sc->{date}} = $sc if !$old || $sc->{_rank} gt $old->{_rank};
    }
    my @out = values %by_date;
    delete $_->{_rank} for @out;
    return \@out;
}

sub _sentinel2 {
    my ($self, $area, $start, $end) = @_;
    my $res = $self->_search('Earth Search', $self->stac_url, {
        collections => [ $self->collection ],
        bbox => $area,
        datetime => "${start}T00:00:00Z/${end}T23:59:59Z",
        limit => 100,
        fields => { include => [ 'id', 'bbox', 'properties.datetime', 'properties.platform', 'properties.eo:cloud_cover',
            'properties.proj:epsg', 'properties.proj:code', 'properties.grid:code', 'properties.s2:processing_baseline',
            'properties.updated', 'properties.earthsearch:boa_offset_applied', 'assets.visual.href', 'assets.red',
            'assets.nir.href', 'assets.scl.href', 'assets.green.href', 'assets.blue.href', 'assets.rededge1.href',
            'assets.swir16.href' ] },
    });
    return $res if $res->{error};
    my @list;
    foreach my $f (@{ $res->{features} }) {
        my $p = $f->{properties} || {};
        my $a = $f->{assets} || {};
        next if !$p->{datetime} || !$a->{visual} || !$a->{scl};
        my $covers = _covers($f->{bbox}, $area);
        my ($rb) = @{ ($a->{red} || {})->{'raster:bands'} || [{}] };
        my $tile = $p->{'grid:code'} // '';
        $tile =~ s/^MGRS-//;
        push @list, {
            id => $f->{id},
            source => 'sentinel2',
            date => substr($p->{datetime}, 0, 10),
            datetime => $p->{datetime},
            platform => $p->{platform},
            tile => $tile,
            tile_cloud => _cloud($p->{'eo:cloud_cover'}),
            epsg => _epsg($p),
            covers => $covers,
            res => 10,
            visual => $a->{visual}{href},
            red => ($a->{red} || {})->{href},
            nir => ($a->{nir} || {})->{href},
            scl => $a->{scl}{href},
            # for the models (R/satellite/satellite_models.R): 10 m green / blue, 20 m red edge 1 / SWIR 1.6
            (map { $a->{$_} && $a->{$_}{href} ? ($_ => $a->{$_}{href}) : () } qw(green blue rededge1 swir16)),
            red_scale => $rb->{scale} // 0.0001,
            # Earth Search already removed the -0.1 offset of processing baseline 04.00+ from the pixel values
            # (boa_offset_applied) but still lists it in raster:bands: applying it again makes red negative
            red_offset => $p->{'earthsearch:boa_offset_applied'} ? 0 : ($rb->{offset} // 0),
            _rank => join('|', $covers, ($f->{id} =~ /_(\d+)_L2A$/ ? sprintf('%03d', $1) : '000'), $p->{'s2:processing_baseline'} // '', $p->{updated} // ''),
        };
    }
    return { scenes => _best_per_date(@list) };
}

sub _landsat {
    my ($self, $area, $start, $end) = @_;
    $start = $FIRST{landsat} if $start lt $FIRST{landsat};
    my $res = $self->_search('Planetary Computer', $self->landsat_stac_url, {
        collections => [ $self->landsat_collection ],
        bbox => $area,
        datetime => "${start}T00:00:00Z/${end}T23:59:59Z",
        limit => 100,
        # Landsat 7 has striped gaps since 2003 and Landsat 5 ended in 2013
        'filter-lang' => 'cql2-json',
        filter => { op => 'in', args => [ { property => 'platform' }, [ 'landsat-8', 'landsat-9' ] ] },
        fields => { include => [ 'id', 'bbox', 'properties.datetime', 'properties.platform', 'properties.eo:cloud_cover',
            'properties.proj:epsg', 'properties.proj:code', 'properties.landsat:wrs_path', 'properties.landsat:wrs_row',
            'properties.landsat:collection_category', 'assets.red', 'assets.green.href', 'assets.blue.href',
            'assets.nir08.href', 'assets.qa_pixel.href' ] },
    });
    return $res if $res->{error};
    my @list;
    foreach my $f (@{ $res->{features} }) {
        my $p = $f->{properties} || {};
        my $a = $f->{assets} || {};
        next if !$p->{datetime} || ($p->{platform} // '') !~ /^landsat-[89]$/;
        next if grep { !$a->{$_} || !$a->{$_}{href} } qw(red green blue nir08 qa_pixel);
        my $covers = _covers($f->{bbox}, $area);
        my ($rb) = @{ $a->{red}{'raster:bands'} || [{}] };
        my ($path, $row) = ($p->{'landsat:wrs_path'} // '', $p->{'landsat:wrs_row'} // '');
        push @list, {
            id => $f->{id},
            source => 'landsat',
            date => substr($p->{datetime}, 0, 10),
            datetime => $p->{datetime},
            platform => $p->{platform},
            tile => ($path ne '' ? "$path/$row" : ''),
            tile_cloud => _cloud($p->{'eo:cloud_cover'}),
            epsg => _epsg($p),
            covers => $covers,
            res => 30,
            red => $a->{red}{href},
            green => $a->{green}{href},
            blue => $a->{blue}{href},
            nir => $a->{nir08}{href},
            qa => $a->{qa_pixel}{href},
            red_scale => $rb->{scale} // 0.0000275,
            red_offset => $rb->{offset} // -0.2,
            _rank => join('|', $covers, (($p->{'landsat:collection_category'} // '') eq 'T1' ? 1 : 0), $f->{id}),
        };
    }
    return { scenes => _best_per_date(@list) };
}

=head2 landsat_token

The free read token of the Planetary Computer Landsat images:
{ token, expiry (ISO time) } or { error }. Kept until 10 minutes before it
expires.

=cut

sub landsat_token {
    my $self = shift;
    my $url = $self->landsat_token_url;
    my $c = $TOKENS{$url};
    return { token => $c->{token}, expiry => $c->{expiry} } if $c && $c->{until} > time() + 600;
    my $res = $self->ua->get($url, 'Accept' => 'application/json');
    return { error => 'Planetary Computer did not answer: ' . $res->status_line } if !$res->is_success;
    my $data = try { decode_json($res->decoded_content) };
    return { error => 'Planetary Computer sent an unreadable token.' } if ref $data ne 'HASH' || !$data->{token};
    my $expiry = $data->{'msft:expiry'} // '';
    my $until = $expiry =~ /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/ ? timegm($6, $5, $4, $3, $2 - 1, $1) : time() + 1800;
    $TOKENS{$url} = { token => $data->{token}, expiry => $expiry, until => $until };
    return { token => $data->{token}, expiry => $expiry };
}

sub _search {
    my ($self, $name, $base, $body) = @_;
    my @features;
    my $url = "$base/search";
    my $page = 0;
    while ($url && $page++ < $self->max_pages) {
        my $res = $self->_post($name, $url, $body);
        return $res if $res->{error};
        push @features, @{ $res->{features} || [] };
        my ($next) = grep { ($_->{rel} // '') eq 'next' } @{ $res->{links} || [] };
        last if !$next;
        $url = $next->{href};
        $body = $next->{body} if $next->{body};
    }
    return { features => \@features };
}

sub _post {
    my ($self, $name, $url, $body) = @_;
    my $req = HTTP::Request->new(POST => $url, [ 'Content-Type' => 'application/json', 'Accept' => 'application/geo+json' ], encode_json($body));
    my $res = $self->ua->request($req);
    return { error => "The satellite catalogue ($name) did not answer: " . $res->status_line } if !$res->is_success;
    my $data = try { decode_json($res->decoded_content) };
    return { error => "The satellite catalogue ($name) sent an unreadable answer." } if ref $data ne 'HASH';
    return $data;
}

sub _days {
    my ($a, $b) = @_;
    my $t = sub { my ($y, $m, $d) = split /-/, shift; return timegm(0, 0, 12, $d, $m - 1, $y) };
    return int(($t->($b) - $t->($a)) / 86400) + 1;
}

=head2 field_geometry

Args: list of plot_geo_json values (JSON strings: a GeoJSON Feature or
geometry, Polygon or Point, WGS84 lon/lat). Returns { bbox => [w,s,e,n],
plots => [ [ [lon,lat], ... ], ... ] (polygon rings; a point is a ring of one) }
or undef when none could be read.

=cut

sub field_geometry {
    my ($self, @values) = @_;
    my @plots;
    my ($w, $s, $e, $n);
    foreach my $v (@values) {
        my $g = try { decode_json($v) } or next;
        $g = $g->{geometry} if ref $g eq 'HASH' && $g->{geometry};
        next if ref $g ne 'HASH';
        my $type = $g->{type} // '';
        my $ring;
        if ($type eq 'Polygon') { $ring = ($g->{coordinates} || [])->[0] }
        elsif ($type eq 'Point') { $ring = [ $g->{coordinates} ] }
        next if ref $ring ne 'ARRAY';
        my @pts = grep { ref $_ eq 'ARRAY' && _num($_->[0]) && _num($_->[1]) && abs($_->[0]) <= 180 && abs($_->[1]) <= 90 } @$ring;
        next if !@pts;
        @pts = map { [ $_->[0] + 0, $_->[1] + 0 ] } @pts;
        foreach my $p (@pts) {
            $w = $p->[0] if !defined $w || $p->[0] < $w;
            $e = $p->[0] if !defined $e || $p->[0] > $e;
            $s = $p->[1] if !defined $s || $p->[1] < $s;
            $n = $p->[1] if !defined $n || $p->[1] > $n;
        }
        push @plots, \@pts;
    }
    return if !@plots;
    return { bbox => [ $w, $s, $e, $n ], plots => \@plots };
}

sub _num { my $v = shift; return defined $v && $v =~ /^-?\d+(\.\d+)?([eE][-+]?\d+)?$/ }

1;

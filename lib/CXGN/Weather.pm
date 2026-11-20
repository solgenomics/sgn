package CXGN::Weather;

=head1 NAME

CXGN::Weather - observed weather from real stations near a research station

=head1 SYNOPSIS

  my $wx = CXGN::Weather->new({ cache_dir => '/tmp/breedbase_weather_cache', inmet_token => $token });

  # observing stations within 200 km of a location, nearest first
  my $stations = $wx->nearby_stations($lat, $lon, 200, ['airport', 'inmet']);

  my $daily = $wx->station_daily('airport', 'SBKP', $lat, $lon, $elev, '2026-09-01', '2026-11-14');

=head1 DESCRIPTION

Only OBSERVED data from real stations, never gridded or interpolated data:
far stations are shown with their distance so the user decides.

=over

=item * airport: METAR stations worldwide, all from the Iowa Environmental
Mesonet (Iowa State University): station lists, latest observations, the
METAR archive (hourly METARs summarized per day). Many countries (Brazil included) do not report rain
amounts in METARs: then the rain amount is left empty and the hours with
rain observed (RA, DZ, SH, TS codes) are given instead.

=item * inmet: automatic stations of INMET (Brazil). The station list is
open; the hourly data needs a free token from INMET (config inmet_api_token).
Gives rain, radiation, humidity and wind, so ET0 is FAO-56 Penman-Monteith.

=item * ana: telemetric stations of ANA (Agencia Nacional de Aguas, Brazil),
rain every 15 minutes, open web service.

=item * cemaden: automatic rain gauges of CEMADEN (Brazil), dense in towns,
hourly rain. Only the last 96 hours can be read, and the gauges come without
coordinates: they are placed at the seat of their municipality (IBGE
coordinates), flagged approx_position.

=item * synop: stations of the national weather services (WMO synoptic
network) worldwide: SYNOP messages from OGIMET, positions from the WMO OSCAR
registry. Rain amounts (6, 12 or 24 h groups), max/min temperatures.

=item * cocorahs: CoCoRaHS volunteer rain gauges (USA, Colorado State
University), one reading every morning.

=item * ideam: automatic stations of IDEAM (Colombia), rain every 10
minutes, open data of datos.gov.co.

=back

No NOAA service is used.

Responses are cached on disk for a time that depends on how fast the data
changes, so pages stay fast and the free services are not abused.

=head1 AUTHOR

Chris Simoes

=cut

use Moose;
use utf8;
use LWP::UserAgent;
use JSON;
use Encode qw(decode encode);
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path);
use File::Spec;
use POSIX qw(floor);
use Time::Local qw(timegm);
use Math::Trig qw(deg2rad rad2deg pi);

use constant KM_PER_MILE => 1.609344;
use constant EARTH_RADIUS_KM => 6371.0088;

my $IEM_SITE = 'https://mesonet.agron.iastate.edu';
my $IEM = "$IEM_SITE/cgi-bin/request/asos.py";
my $OGIMET = 'https://www.ogimet.com/cgi-bin/getsynop';
my $OSCAR = 'https://oscar.wmo.int/surface/rest/api/search/station';
my $COCORAHS = 'https://data.cocorahs.org/export/exportreports.aspx';
my $IDEAM = 'https://www.datos.gov.co/resource/s54a-sgyg.json';
my $INMET = 'https://apitempo.inmet.gov.br';
my $ANA = 'https://telemetriaws1.ana.gov.br/ServiceANA.asmx';
my $CEMADEN_LIST = 'https://resources.cemaden.gov.br/graficos/interativo/getJson2.php';
my $CEMADEN_HOURLY = 'https://resources.cemaden.gov.br/graficos/cemaden/hidro/resources/json/AcumuladoResource.php';
my $MUNICIPALITIES = 'https://raw.githubusercontent.com/kelvins/municipios-brasileiros/main/csv/municipios.csv';
my %UF = (11 => 'RO', 12 => 'AC', 13 => 'AM', 14 => 'RR', 15 => 'PA', 16 => 'AP', 17 => 'TO', 21 => 'MA', 22 => 'PI',
    23 => 'CE', 24 => 'RN', 25 => 'PB', 26 => 'PE', 27 => 'AL', 28 => 'SE', 29 => 'BA', 31 => 'MG', 32 => 'ES', 33 => 'RJ',
    35 => 'SP', 41 => 'PR', 42 => 'SC', 43 => 'RS', 50 => 'MS', 51 => 'MT', 52 => 'GO', 53 => 'DF');

# Stations that stand on an Embrapa research centre (the networks do not say who hosts a station).
# Checked 2026-11-16: station inside an Embrapa site mapped in OpenStreetMap (within ~1 km), plus
# A569 at Embrapa Milho e Sorgo. Airports and stations only near an Embrapa building are left out.
my %AT_SITE = (
    'inmet:A569' => 'Embrapa Milho e Sorgo',
    'inmet:A409' => 'Embrapa Tabuleiros Costeiros', 'synop:86616' => 'Embrapa Tabuleiros Costeiros',
    'inmet:A313' => 'Embrapa Algodão', 'synop:81916' => 'Embrapa Algodão',
    'inmet:A840' => 'Embrapa Uva e Vinho', 'synop:86979' => 'Embrapa Uva e Vinho',
    'inmet:A880' => 'Embrapa Uva e Vinho, Vacaria', 'synop:86966' => 'Embrapa Uva e Vinho, Vacaria',
    'inmet:A601' => 'Embrapa Agrobiologia', 'synop:86878' => 'Embrapa Agrobiologia',
    'inmet:B806' => 'Embrapa Florestas',
    'inmet:A046' => 'Embrapa Hortaliças',
    'inmet:A406' => 'Embrapa Mandioca e Fruticultura', 'synop:86657' => 'Embrapa Mandioca e Fruticultura', 'synop:83222' => 'Embrapa Mandioca e Fruticultura',
    'inmet:A312' => 'Embrapa Meio-Norte', 'synop:81827' => 'Embrapa Meio-Norte',
);

# ISO 3166 alpha-2 -> alpha-3 (the WMO registry uses alpha-3)
my %ISO3 = map { substr($_, 0, 2) => substr($_, 2, 3) } split / /, 'ADAND AEARE AFAFG AGATG AIAIA ALALB AMARM AOAGO AQATA ARARG ASASM ATAUT AUAUS AWABW AXALA AZAZE BABIH BBBRB BDBGD BEBEL BFBFA BGBGR BHBHR BIBDI BJBEN BLBLM BMBMU BNBRN BOBOL BQBES BRBRA BSBHS BTBTN BVBVT BWBWA BYBLR BZBLZ CACAN CCCCK CDCOD CFCAF CGCOG CHCHE CICIV CKCOK CLCHL CMCMR CNCHN COCOL CRCRI CUCUB CVCPV CWCUW CXCXR CYCYP CZCZE DEDEU DJDJI DKDNK DMDMA DODOM DZDZA ECECU EEEST EGEGY EHESH ERERI ESESP ETETH FIFIN FJFJI FKFLK FMFSM FOFRO FRFRA GAGAB GBGBR GDGRD GEGEO GFGUF GGGGY GHGHA GIGIB GLGRL GMGMB GNGIN GPGLP GQGNQ GRGRC GSSGS GTGTM GUGUM GWGNB GYGUY HKHKG HMHMD HNHND HRHRV HTHTI HUHUN IDIDN IEIRL ILISR IMIMN ININD IOIOT IQIRQ IRIRN ISISL ITITA JEJEY JMJAM JOJOR JPJPN KEKEN KGKGZ KHKHM KIKIR KMCOM KNKNA KPPRK KRKOR KWKWT KYCYM KZKAZ LALAO LBLBN LCLCA LILIE LKLKA LRLBR LSLSO LTLTU LULUX LVLVA LYLBY MAMAR MCMCO MDMDA MEMNE MFMAF MGMDG MHMHL MKMKD MLMLI MMMMR MNMNG MOMAC MPMNP MQMTQ MRMRT MSMSR MTMLT MUMUS MVMDV MWMWI MXMEX MYMYS MZMOZ NANAM NCNCL NENER NFNFK NGNGA NINIC NLNLD NONOR NPNPL NRNRU NUNIU NZNZL OMOMN PAPAN PEPER PFPYF PGPNG PHPHL PKPAK PLPOL PMSPM PNPCN PRPRI PSPSE PTPRT PWPLW PYPRY QAQAT REREU ROROU RSSRB RURUS RWRWA SASAU SBSLB SCSYC SDSDN SESWE SGSGP SHSHN SISVN SJSJM SKSVK SLSLE SMSMR SNSEN SOSOM SRSUR SSSSD STSTP SVSLV SXSXM SYSYR SZSWZ TCTCA TDTCD TFATF TGTGO THTHA TJTJK TKTKL TLTLS TMTKM TNTUN TOTON TRTUR TTTTO TVTUV TWTWN TZTZA UAUKR UGUGA UMUMI USUSA UYURY UZUZB VAVAT VCVCT VEVEN VGVGB VIVIR VNVNM VUVUT WFWLF WSWSM YEYEM YTMYT ZAZAF ZMZMB ZWZWE';

# seconds a cached answer stays valid
my %TTL = (
    iem_networks => 30 * 86400,
    iem_stations => 7 * 86400,
    iem_currents => 600,
    oscar => 30 * 86400,
    station_list => 6 * 3600,
    inmet_stations => 7 * 86400,
    ana_stations => 7 * 86400,
    municipalities => 30 * 86400,
    cemaden_list => 600,
    metar => 600,
    archive => 86400,
    archive_recent => 1800,
);

has 'cache_dir' => (isa => 'Maybe[Str]', is => 'ro', default => sub { File::Spec->catdir(File::Spec->tmpdir(), 'breedbase_weather_cache') });
has 'inmet_token' => (isa => 'Maybe[Str]', is => 'ro');
has 'timeout' => (isa => 'Int', is => 'ro', default => 15);
has 'ua' => (is => 'ro', lazy => 1, builder => '_build_ua');

sub _build_ua {
    my $self = shift;
    return LWP::UserAgent->new(timeout => $self->timeout, agent => 'Breedbase-weather/1.0');
}

=head1 GEOMETRY AND UNITS

=head2 distance_km($lat1, $lon1, $lat2, $lon2)

Great-circle (haversine) distance in kilometres.

=cut

sub distance_km {
    my ($self, $lat1, $lon1, $lat2, $lon2) = @_;
    my $dlat = deg2rad($lat2 - $lat1);
    my $dlon = deg2rad($lon2 - $lon1);
    my $a = sin($dlat / 2)**2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dlon / 2)**2;
    return 2 * EARTH_RADIUS_KM * atan2(sqrt($a), sqrt(1 - $a));
}

=head2 bearing($lat1, $lon1, $lat2, $lon2)

Initial bearing from point 1 to point 2, degrees 0-360 (0 = north).

=cut

sub bearing {
    my ($self, $lat1, $lon1, $lat2, $lon2) = @_;
    my ($p1, $p2, $dl) = (deg2rad($lat1), deg2rad($lat2), deg2rad($lon2 - $lon1));
    my $y = sin($dl) * cos($p2);
    my $x = cos($p1) * sin($p2) - sin($p1) * cos($p2) * cos($dl);
    my $b = rad2deg(atan2($y, $x)) + 360;
    return $b - 360 * floor($b / 360);
}

=head2 compass($degrees)

16-point compass name (N, NNE, ...).

=cut

sub compass {
    my ($self, $deg) = @_;
    return '' if !defined $deg || $deg !~ /^-?[\d.]+$/;
    my @p = qw(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW);
    return $p[ floor(($deg - 360 * floor($deg / 360)) / 22.5 + 0.5) % 16 ];
}

=head2 to_km($value, $unit)

Converts a distance in 'km' or 'mi' to kilometres.

=cut

sub to_km {
    my ($self, $value, $unit) = @_;
    return ($unit && $unit eq 'mi') ? $value * KM_PER_MILE : $value;
}

=head2 bbox($lat, $lon, $range_km)

Bounding box (min_lat, min_lon, max_lat, max_lon) around a point.

=cut

sub bbox {
    my ($self, $lat, $lon, $km) = @_;
    my $dlat = $km / 111.32;
    my $coslat = cos(deg2rad($lat));
    my $dlon = $coslat > 0.01 ? $km / (111.32 * $coslat) : 180;
    $dlon = 180 if $dlon > 180;
    my $clamp = sub { my ($v, $lo, $hi) = @_; $v < $lo ? $lo : $v > $hi ? $hi : $v };
    return (
        $clamp->($lat - $dlat, -90, 90), $clamp->($lon - $dlon, -180, 180),
        $clamp->($lat + $dlat, -90, 90), $clamp->($lon + $dlon, -180, 180),
    );
}

=head2 relative_humidity($temp_c, $dewpoint_c)

Relative humidity (%) from temperature and dew point (Magnus formula).

=cut

sub relative_humidity {
    my ($self, $t, $td) = @_;
    return if !defined $t || !defined $td || $t eq '' || $td eq '';
    my $e = sub { 6.1094 * exp(17.625 * $_[0] / ($_[0] + 243.04)) };
    my $rh = 100 * $e->($td) / $e->($t);
    $rh = 100 if $rh > 100;
    return sprintf('%.0f', $rh) + 0;
}

sub _tan { return sin($_[0]) / cos($_[0]) }
sub _acos { my $x = shift; return atan2(sqrt(1 - $x * $x), $x) }

sub _doy {
    my ($y, $m, $d) = split /-/, shift;
    return (gmtime(timegm(0, 0, 12, $d, $m - 1, $y)))[7] + 1;
}

=head2 extraterrestrial_radiation($lat, $day_of_year)

Ra (MJ m-2 day-1), FAO-56 eq. 21.

=cut

sub extraterrestrial_radiation {
    my ($self, $lat, $doy) = @_;
    my $phi = deg2rad($lat);
    my $dr = 1 + 0.033 * cos(2 * pi * $doy / 365);
    my $delta = 0.409 * sin(2 * pi * $doy / 365 - 1.39);
    my $x = -_tan($phi) * _tan($delta);
    $x = -1 if $x < -1;
    $x = 1 if $x > 1;
    my $ws = _acos($x);
    return (24 * 60 / pi) * 0.0820 * $dr * ($ws * sin($phi) * sin($delta) + cos($phi) * cos($delta) * sin($ws));
}

=head2 hargreaves_et0($lat, $day_of_year, $tmax, $tmin)

Reference evapotranspiration (mm/day), Hargreaves-Samani (FAO-56 eq. 52):
used when a station measures temperature but not radiation.

=cut

sub hargreaves_et0 {
    my ($self, $lat, $doy, $tmax, $tmin) = @_;
    return if !defined $tmax || !defined $tmin || $tmax < $tmin;
    my $ra = $self->extraterrestrial_radiation($lat, $doy);
    my $et0 = 0.0023 * 0.408 * $ra * (($tmax + $tmin) / 2 + 17.8) * sqrt($tmax - $tmin);
    $et0 = 0 if $et0 < 0;
    return sprintf('%.2f', $et0) + 0;
}

=head2 penman_monteith_et0(%args)

Daily FAO-56 Penman-Monteith reference evapotranspiration (mm/day).
Args: lat, elev (m), doy, tmax, tmin (C), rh (mean %), rs (MJ m-2 day-1),
wind (m/s) measured at wind_height (m, default 10).

=cut

sub penman_monteith_et0 {
    my ($self, %a) = @_;
    for (qw(tmax tmin rh rs wind)) { return if !defined $a{$_} }
    my $elev = $a{elev} // 0;
    my $tmean = ($a{tmax} + $a{tmin}) / 2;
    my $u2 = $a{wind} * 4.87 / log(67.8 * ($a{wind_height} || 10) - 5.42);
    my $p = 101.3 * ((293 - 0.0065 * $elev) / 293)**5.26;
    my $gamma = 0.000665 * $p;
    my $es_f = sub { 0.6108 * exp(17.27 * $_[0] / ($_[0] + 237.3)) };
    my $es = ($es_f->($a{tmax}) + $es_f->($a{tmin})) / 2;
    my $ea = $a{rh} / 100 * $es;
    my $delta = 4098 * $es_f->($tmean) / ($tmean + 237.3)**2;
    my $ra = $self->extraterrestrial_radiation($a{lat}, $a{doy});
    my $rso = (0.75 + 2e-5 * $elev) * $ra;
    my $rns = 0.77 * $a{rs};
    my $ratio = $rso > 0 ? $a{rs} / $rso : 0.5;
    $ratio = 1 if $ratio > 1;
    my $sigma = 4.903e-9;
    my $rnl = $sigma * ((($a{tmax} + 273.16)**4 + ($a{tmin} + 273.16)**4) / 2)
        * (0.34 - 0.14 * sqrt($ea > 0 ? $ea : 0)) * (1.35 * $ratio - 0.35);
    my $rn = $rns - $rnl;
    my $et0 = (0.408 * $delta * $rn + $gamma * 900 / ($tmean + 273) * $u2 * ($es - $ea))
        / ($delta + $gamma * (1 + 0.34 * $u2));
    $et0 = 0 if $et0 < 0;
    return sprintf('%.2f', $et0) + 0;
}

sub _num { my $v = shift; return (defined $v && $v =~ /^\s*-?\d+(\.\d+)?\s*$/) ? $v + 0 : undef }
sub _r1 { my $v = shift; return defined $v ? sprintf('%.1f', $v) + 0 : undef }

=head1 FETCHING

=head2 get_raw($url, $kind)

GET a URL through the disk cache ($kind picks the time to live). Returns the
body ('' for "no content"). Dies with a short message when the service
cannot be reached.

=cut

sub get_raw {
    my ($self, $url, $kind) = @_;
    my $ttl = $TTL{$kind} // 3600;
    my $file;
    if ($self->cache_dir) {
        eval { make_path($self->cache_dir) unless -d $self->cache_dir; };
        $file = File::Spec->catfile($self->cache_dir, $kind . '_' . md5_hex($url));
        if (-e $file && (time() - (stat($file))[9]) < $ttl && open(my $fh, '<:raw', $file)) {
            local $/;
            my $raw = <$fh>;
            close $fh;
            return $raw // '';
        }
    }
    # ANA's service is sometimes slow: short timeout and one more try (pages time out at 20 s)
    my $is_ana = index($url, $ANA) == 0;
    my $tries = ($is_ana || index($url, $IEM_SITE) == 0 || index($url, $OGIMET) == 0) ? 2 : 1;
    my $old_timeout = $self->ua->timeout;
    $self->ua->timeout(8) if $is_ana;
    my $r;
    for my $try (1 .. $tries) {
        $r = $self->ua->get($url);
        last if $r->is_success || $r->code == 404;
        sleep(3) if $r->code == 429 && $try < $tries;    # too many requests: wait a little
        last if index($url, $OGIMET) == 0 && $r->code == 501;    # OGIMET quota: the page waits, not the server
    }
    $self->ua->timeout($old_timeout);
    if (!$r->is_success && $file && -s $file && open(my $fh, '<:raw', $file)) {
        # the service failed: use the last copy we have, however old
        local $/;
        my $raw = <$fh>;
        close $fh;
        $self->{stale}++;
        return $raw // '';
    }
    if (!$r->is_success && index($url, $OGIMET) == 0 && ($r->decoded_content // '') =~ /quota/i) {
        die "OGIMET quota: one query every 20 seconds. The page waits and tries again.\n";
    }
    if (!$r->is_success) {
        my ($host) = $url =~ m{^https?://([^/]+)};
        die "The weather service $host did not answer (" . $r->status_line . "). Try again in a few minutes.\n";
    }
    my $raw = $r->decoded_content(charset => 'none') // '';
    if ($file && open(my $fh, '>:raw', "$file.$$")) {
        print $fh $raw;
        close $fh;
        rename("$file.$$", $file);
    }
    return $raw;
}

=head2 get_json($url, $kind)

get_raw and decode JSON (an empty body gives an empty list).

=cut

sub get_json {
    my ($self, $url, $kind) = @_;
    my $raw = $self->get_raw($url, $kind);
    return [] if $raw =~ /^\s*$/;
    my $data = eval { decode_json($raw) };
    if (!defined $data) {
        my ($host) = $url =~ m{^https?://([^/]+)};
        die "The weather service $host sent an answer that could not be read.\n";
    }
    return $data;
}

=head1 STATIONS

=head2 networks()

Description of the station networks this module knows.

=cut

sub networks {
    my $self = shift;
    return {
        airport => {
            label => 'Airport (METAR)',
            source => 'Iowa Environmental Mesonet (Iowa State University)',
            note => 'Hourly observations of airports. Rain amounts are not reported in many countries (rain hours are given instead).',
        },
        inmet => {
            label => 'INMET automatic station',
            source => 'INMET - Instituto Nacional de Meteorologia (Brazil)',
            note => 'Hourly rain, temperature, humidity, radiation and wind.',
            ready => $self->inmet_token ? 1 : 0,
        },
        ana => {
            label => 'ANA rain gauge',
            source => 'ANA - Agencia Nacional de Aguas e Saneamento Basico (Brazil), telemetry',
            note => 'Rain every 15 minutes (no temperature).',
        },
        synop => {
            label => 'National weather service (SYNOP)',
            source => 'SYNOP messages from OGIMET; station positions from WMO OSCAR',
            note => 'Main stations of the national weather services: rain amounts and max/min temperatures.',
        },
        cocorahs => {
            label => 'CoCoRaHS rain gauge (USA)',
            source => 'CoCoRaHS - Community Collaborative Rain, Hail and Snow Network (Colorado State University)',
            note => 'Volunteer rain gauges read every morning (no temperature).',
        },
        ideam => {
            label => 'IDEAM automatic station (Colombia)',
            source => 'IDEAM - Instituto de Hidrologia, Meteorologia y Estudios Ambientales, open data datos.gov.co',
            note => 'Rain every 10 minutes (no temperature).',
        },
        cemaden => {
            label => 'CEMADEN rain gauge',
            source => 'CEMADEN - Centro Nacional de Monitoramento e Alertas de Desastres Naturais (Brazil)',
            note => 'Hourly rain of the last 96 hours only (no temperature). Position: centre of the municipality.',
        },
    };
}

=head2 nearby_stations($lat, $lon, $range_km, \@networks, $limit)

Observing stations within $range_km, nearest first (at most $limit per
network, default 60). Each: network, id, name, lat, lon, elev, country,
state, distance_km, bearing, direction, has_taf, ready (data can be read),
latest (airports: decoded latest METAR). Errors of one network do not stop
the others: they are returned in { stations, errors }.

=cut

sub nearby_stations {
    my ($self, $lat, $lon, $range_km, $networks, $limit) = @_;
    $limit ||= 60;
    $networks ||= ['airport', 'inmet'];
    my (@stations, @errors);
    foreach my $n (@$networks) {
        my $list = eval {
            $n eq 'airport' ? $self->_airports($lat, $lon, $range_km, $limit)
                : $n eq 'inmet' ? $self->_inmet_stations($lat, $lon, $range_km, $limit)
                : $n eq 'ana' ? $self->_ana_stations($lat, $lon, $range_km, $limit)
                : $n eq 'cemaden' ? $self->_cemaden_stations($lat, $lon, $range_km, $limit)
                : $n eq 'synop' ? $self->_synop_stations($lat, $lon, $range_km, $limit)
                : $n eq 'cocorahs' ? $self->_cocorahs_stations($lat, $lon, $range_km, $limit)
                : $n eq 'ideam' ? $self->_ideam_stations($lat, $lon, $range_km, $limit)
                : [];
        };
        if ($@) { push @errors, $@; next; }
        foreach my $st (@$list) {
            my $site = $AT_SITE{$st->{network} . ':' . uc($st->{id} // '')};
            next if !$site;
            $st->{site} = $site;
            $st->{name} = ($st->{name} // $st->{id}) . " ($site)" if ($st->{name} // '') !~ /embrapa/i;
        }
        push @stations, @$list;
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} } @stations;
    return { stations => \@stations, errors => \@errors };
}

sub _place {
    my ($self, $st, $lat, $lon) = @_;
    my $d = $self->distance_km($lat, $lon, $st->{lat}, $st->{lon});
    my $b = $self->bearing($lat, $lon, $st->{lat}, $st->{lon});
    $st->{distance_km} = _r1($d);
    $st->{bearing} = sprintf('%.0f', $b) + 0;
    $st->{direction} = $self->compass($b);
    return $d;
}

# IEM networks (countries, US states...) whose extent meets the search box
sub _iem_networks_near {
    my ($self, $lat, $lon, $range_km, $pattern) = @_;
    my $geo = $self->get_json("$IEM_SITE/geojson/networks.geojson", 'iem_networks');
    my ($min_lat, $min_lon, $max_lat, $max_lon) = $self->bbox($lat, $lon, $range_km);
    my @ids;
    foreach my $f (@{ref($geo) eq 'HASH' ? $geo->{features} || [] : []}) {
        next if ($f->{id} // '') !~ $pattern;
        my @pts = map { @$_ } @{($f->{geometry} || {})->{coordinates} || []};
        next if !@pts;
        my ($x0, $x1, $y0, $y1) = (180, -180, 90, -90);
        foreach my $pt (@pts) {
            next if ref($pt) ne 'ARRAY';
            $x0 = $pt->[0] if $pt->[0] < $x0; $x1 = $pt->[0] if $pt->[0] > $x1;
            $y0 = $pt->[1] if $pt->[1] < $y0; $y1 = $pt->[1] if $pt->[1] > $y1;
        }
        # a margin: network extents are the box of their stations
        next if $x1 + 0.5 < $min_lon || $x0 - 0.5 > $max_lon || $y1 + 0.5 < $min_lat || $y0 - 0.5 > $max_lat;
        push @ids, $f->{id};
    }
    return \@ids;
}

sub _airports {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    my $nets = $self->_iem_networks_near($lat, $lon, $range_km, qr/^(?:[A-Z]{2}__|[A-Z]{2}_)ASOS$/);
    my (@stations, %seen);
    foreach my $net (@$nets) {
        my $geo = eval { $self->get_json("$IEM_SITE/geojson/network/$net.geojson", 'iem_stations') } or next;
        foreach my $f (@{$geo->{features} || []}) {
            my $pr = $f->{properties} || {};
            my $c = ($f->{geometry} || {})->{coordinates} || [];
            next if !$f->{id} || $seen{$f->{id}}++ || $pr->{archive_end};
            my %st = (
                network => 'airport', id => $f->{id}, iem_network => $net, name => $pr->{sname} // $f->{id},
                lat => _num($c->[1]), lon => _num($c->[0]), elev => _num($pr->{elevation}),
                country => $pr->{country}, state => $pr->{state}, ready => 1, temp => 1,
                has_taf => ($pr->{country} // '') eq 'US' ? 1 : 0,
            );
            next if !defined $st{lat} || !defined $st{lon};
            next if $self->_place(\%st, $lat, $lon) > $range_km;
            push @stations, \%st;
        }
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} } @stations;
    splice(@stations, $limit) if @stations > $limit;

    # latest observation: one request per network
    my %latest;
    foreach my $net (keys %{{ map { $_->{iem_network} => 1 } @stations }}) {
        my $cur = eval { $self->get_json("$IEM_SITE/api/1/currents.json?network=$net", 'iem_currents') } or next;
        foreach my $r (@{$cur->{data} || []}) {
            my $m = $self->_iem_current($r);
            $latest{$r->{station}} = $m if $m->{time} && $m->{time} > time() - 6 * 3600;
        }
    }
    $_->{latest} = $latest{$_->{id}} for @stations;
    return \@stations;
}

sub _f2c { my $f = shift; return defined $f ? _r1(($f - 32) * 5 / 9) : undef }

sub _iso_epoch {
    my ($y, $m, $d, $hh, $mm) = (shift // '') =~ /^(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d)/ or return 0;
    return timegm(0, $mm, $hh, $d, $m - 1, $y);
}

# one record of IEM currents.json as a latest observation
sub _iem_current {
    my ($self, $r) = @_;
    my $kt = _num($r->{sknt});
    my $gust = _num($r->{gust});
    my $alti = _num($r->{alti});
    my $wx = $r->{wxcodes};
    $wx = join(' ', @$wx) if ref($wx) eq 'ARRAY';
    return {
        station => $r->{station},
        time => _iso_epoch($r->{utc_valid}),
        temp_c => _f2c(_num($r->{tmpf})),
        dewpoint_c => _f2c(_num($r->{dwpf})),
        rh => defined _num($r->{relh}) ? sprintf('%.0f', $r->{relh}) + 0 : undef,
        wind_dir => _num($r->{drct}),
        wind_kmh => defined $kt ? sprintf('%.0f', $kt * 1.852) + 0 : undef,
        gust_kmh => defined $gust ? sprintf('%.0f', $gust * 1.852) + 0 : undef,
        visibility_km => defined _num($r->{vsby}) ? _r1($r->{vsby} * KM_PER_MILE) : undef,
        pressure_hpa => defined _num($r->{mslp}) ? _r1($r->{mslp}) : defined $alti ? sprintf('%.0f', $alti * 33.8639) + 0 : undef,
        weather => $wx,
        cover => $r->{skyc1},
        raw => $r->{raw},
    };
}

# can a circle of $range_km around the point reach Brazil?
sub _reaches_brazil {
    my ($self, $lat, $lon, $range_km) = @_;
    my ($min_lat, $min_lon, $max_lat, $max_lon) = $self->bbox($lat, $lon, $range_km);
    return !($max_lat < -34.5 || $min_lat > 5.5 || $max_lon < -74.5 || $min_lon > -28.5);
}

sub _inmet_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    # INMET only covers Brazil: skip the request when the range cannot reach it
    return [] if !$self->_reaches_brazil($lat, $lon, $range_km);
    my $list = $self->get_json("$INMET/estacoes/T", 'inmet_stations');
    $list = [] if ref($list) ne 'ARRAY';
    my @stations;
    foreach my $s (@$list) {
        my %st = (
            network => 'inmet', id => $s->{CD_ESTACAO}, name => $s->{DC_NOME},
            lat => _num($s->{VL_LATITUDE}), lon => _num($s->{VL_LONGITUDE}), elev => _num($s->{VL_ALTITUDE}),
            country => 'BR', state => $s->{SG_ESTADO}, status => $s->{CD_SITUACAO},
            since => substr($s->{DT_INICIO_OPERACAO} // '', 0, 10), wmo => $s->{CD_OSCAR},
            ready => $self->inmet_token ? 1 : 0, has_taf => 0,
        );
        next if !$st{id} || !defined $st{lat} || !defined $st{lon};
        next if $self->_place(\%st, $lat, $lon) > $range_km;
        push @stations, \%st;
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} } @stations;
    splice(@stations, $limit) if @stations > $limit;
    return \@stations;
}


sub _ana_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_reaches_brazil($lat, $lon, $range_km);
    my $xml = _utf8($self->get_raw("$ANA/ListaEstacoesTelemetricas?statusEstacoes=0&origem=", 'ana_stations'));
    my @stations;
    while ($xml =~ m{<Table\b[^>]*>(.*?)</Table>}gs) {
        my $t = $1;
        my %h;
        $h{$1} = $2 while $t =~ m{<([\w-]+)>([^<]*)</\1>}g;
        my %st = (
            network => 'ana', id => $h{CodEstacao}, name => _title($h{NomeEstacao}),
            lat => _num($h{Latitude}), lon => _num($h{Longitude}), elev => _num($h{Altitude}),
            country => 'BR', status => $h{StatusEstacao}, operator => _title(($h{Operadora} // '') =~ s/^\d+\s*-\s*//r),
            river => _title($h{NomeRio}), ready => 1, has_taf => 0, rain_only => 1,
        );
        next if !$st{id} || !defined $st{lat} || !defined $st{lon};
        next if ($st{status} // '') =~ /inativ/i;
        next if $self->_place(\%st, $lat, $lon) > $range_km;
        push @stations, \%st;
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} } @stations;
    splice(@stations, $limit) if @stations > $limit;
    return \@stations;
}

sub _utf8 {
    my $raw = shift // '';
    my $s = eval { decode('UTF-8', $raw, Encode::FB_CROAK) };
    return defined $s ? $s : decode('ISO-8859-1', $raw);
}

sub _title {
    my $s = shift // return '';
    $s =~ s/(\w+)/\u\L$1/g;
    return $s;
}

=head2 municipalities()

Brazilian municipalities by IBGE code: { name, lat, lon, uf } (coordinates
of the municipal seat, open IBGE data compiled in kelvins/municipios-brasileiros).

=cut

sub municipalities {
    my $self = shift;
    return $self->{_municipalities} if $self->{_municipalities};
    my $csv = _utf8($self->get_raw($MUNICIPALITIES, 'municipalities'));
    my %m;
    foreach my $line (split /\r?\n/, $csv) {
        my @f = split /,/, $line;
        next if !@f || $f[0] !~ /^\d{7}$/;
        $m{$f[0]} = { name => $f[1], lat => $f[2] + 0, lon => $f[3] + 0, uf => $UF{$f[5]} // '' };
    }
    return $self->{_municipalities} = \%m;
}

sub _cemaden_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_reaches_brazil($lat, $lon, $range_km);
    my $mun = $self->municipalities();
    my %ufs;
    foreach my $m (values %$mun) {
        $ufs{$m->{uf}} = 1 if $m->{uf} && $self->distance_km($lat, $lon, $m->{lat}, $m->{lon}) <= $range_km + 30;
    }
    my @stations;
    foreach my $uf (sort keys %ufs) {
        my $list = $self->get_json("$CEMADEN_LIST?uf=$uf", 'cemaden_list');
        next if ref($list) ne 'ARRAY';
        foreach my $g (@$list) {
            my $m = $mun->{$g->{codibge} // ''} or next;
            next if ($g->{tipoestacao} // 1) != 1;    # 1 = rain gauge
            my %st = (
                network => 'cemaden', id => $g->{idestacao}, code => $g->{nomeestacao},
                name => $g->{nomeestacao} . ' (' . _title($g->{cidade}) . ')',
                lat => $m->{lat}, lon => $m->{lon}, elev => undef, country => 'BR', state => $uf,
                approx_position => 1, ready => 1, has_taf => 0, rain_only => 1, history_hours => 96,
                latest => {
                    time => _cemaden_time($g->{datahoraUltimovalor}),
                    rain_24h => _num($g->{acc24hr}), rain_72h => _num($g->{acc72hr}), rain_96h => _num($g->{acc96hr}),
                },
            );
            next if !$st{id};
            next if $self->_place(\%st, $lat, $lon) > $range_km;
            push @stations, \%st;
        }
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} || $a->{name} cmp $b->{name} } @stations;
    splice(@stations, $limit) if @stations > $limit;
    return \@stations;
}

# "15/11/26 03:10" (UTC) -> epoch
sub _cemaden_time {
    my $s = shift // return 0;
    my ($d, $m, $y, $hh, $mm) = $s =~ m{^(\d\d)/(\d\d)/(\d\d) (\d\d):(\d\d)} or return 0;
    return timegm(0, $mm, $hh, $d, $m - 1, 2000 + $y);
}



# ------------------------------------------------------------------ SYNOP (national weather services)

sub _synop_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    # countries in range, from the extents of the IEM country networks (CC__ASOS)
    my $nets = $self->_iem_networks_near($lat, $lon, $range_km, qr/^[A-Z]{2}__ASOS$/);
    my @stations;
    my %seen;
    foreach my $cc (map { substr($_, 0, 2) } @$nets) {
        my $iso3 = $ISO3{$cc} or next;
        my $r = eval { $self->get_json("$OSCAR?territoryName=$iso3&stationClass=synopLand", 'oscar') } or next;
        foreach my $o (@{ref($r) eq 'HASH' ? $r->{stationSearchResults} || [] : []}) {
            my ($wmo) = ($o->{wigosId} // '') =~ /^0-20000-0-(\d{5})$/ or next;
            next if $seen{$wmo}++;
            my %st = (
                network => 'synop', id => $wmo, name => _title($o->{name}), lat => _num($o->{latitude}), lon => _num($o->{longitude}),
                elev => _num($o->{elevation}), country => $cc, status => $o->{declaredStatus}, ready => 1, temp => 1, rain_amounts => 1,
            );
            next if !defined $st{lat} || !defined $st{lon};
            next if $self->_place(\%st, $lat, $lon) > $range_km;
            push @stations, \%st;
        }
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} } @stations;
    splice(@stations, $limit) if @stations > $limit;
    return \@stations;
}

my %SYNOP_PERIOD = (1 => 6, 2 => 12, 3 => 18, 4 => 24, 5 => 1, 6 => 2, 7 => 3, 8 => 9, 9 => 15);

sub _synop_rrr {
    my $rrr = shift;
    return if $rrr !~ /^\d{3}$/;
    return 0 if $rrr == 990;                     # trace
    return ($rrr - 990) / 10 if $rrr > 990;      # 0.1 .. 0.9 mm
    return $rrr + 0;
}

sub _synop_t {
    my ($sn, $ttt) = @_;
    return if $ttt !~ /^\d{3}$/ || $sn !~ /^[01]$/;
    return ($sn ? -1 : 1) * $ttt / 10;
}

=head2 parse_synop($message)

Decodes the parts of a land SYNOP (FM-12 AAXX) message used here: iR,
temperature, dew point, wind, pressure, present weather, rain groups of
sections 1 and 3 ({ mm, hours }), 24-hour rain (section 3 group 7),
maximum and minimum temperatures (section 3 groups 1 and 2).

=cut

sub parse_synop {
    my ($self, $msg) = @_;
    $msg =~ s/=.*$//s;
    my @g = split /\s+/, $msg;
    shift @g while @g && $g[0] ne 'AAXX';
    return { nil => 1 } if @g < 5 || $g[3] eq 'NIL';
    my %r = (rain => []);
    my $iw = substr($g[1], 4, 1);
    $r{ir} = substr($g[3], 0, 1);
    my ($ff) = $g[4] =~ /^.\d\d(\d\d)$/;
    my $dd = substr($g[4], 1, 2);
    my $i = 5;
    if (defined $ff && $ff eq '99' && ($g[$i] // '') =~ /^00(\d{3})$/) { $ff = $1; $i++; }
    if (defined $ff && $ff =~ /^\d+$/) {
        my $k = ($iw eq '3' || $iw eq '4') ? 1.852 : 3.6;    # knots or m/s
        $r{wind_kmh} = sprintf('%.0f', $ff * $k) + 0;
        $r{wind_dir} = $dd * 10 if $dd =~ /^\d\d$/ && $dd <= 36;
    }
    my $section = 1;
    my $seen5 = 0;
    for (; $i < @g; $i++) {
        my $x = $g[$i];
        if ($x eq '333') { $section = 3; next; }
        if ($x =~ /^(222|444|555)/) { $section = 0; next; }
        next if $section == 0 || length($x) != 5;
        my $d = substr($x, 0, 1);
        if ($section == 1) {
            if ($d eq '1') { $r{temp_c} = _synop_t(substr($x, 1, 1), substr($x, 2)); }
            elsif ($d eq '2' && substr($x, 1, 1) eq '9') { $r{rh} = _num(substr($x, 2)); }
            elsif ($d eq '2') { $r{dewpoint_c} = _synop_t(substr($x, 1, 1), substr($x, 2)); }
            elsif ($d eq '4' && substr($x, 1) =~ /^\d{4}$/) { my $p = substr($x, 1) / 10; $r{pressure_hpa} = $p < 500 ? $p + 1000 : $p; }
            elsif ($d eq '6' && ($r{ir} eq '0' || $r{ir} eq '1')) {
                my $mm = _synop_rrr(substr($x, 1, 3));
                push @{$r{rain}}, { mm => $mm, hours => $SYNOP_PERIOD{substr($x, 4, 1)} } if defined $mm;
            }
            elsif ($d eq '7') { $r{ww} = substr($x, 1, 2); }
        }
        else {
            if ($d eq '5') { $seen5 = 1; next; }
            next if $seen5 && $d =~ /^[0-4]$/;        # radiation groups after 55SSS
            if ($d eq '1' && !$seen5) { $r{tmax_c} = _synop_t(substr($x, 1, 1), substr($x, 2)); }
            elsif ($d eq '2' && !$seen5) { $r{tmin_c} = _synop_t(substr($x, 1, 1), substr($x, 2)); }
            elsif ($d eq '6' && ($r{ir} eq '0' || $r{ir} eq '2')) {
                my $mm = _synop_rrr(substr($x, 1, 3));
                push @{$r{rain}}, { mm => $mm, hours => $SYNOP_PERIOD{substr($x, 4, 1)} } if defined $mm;
            }
            elsif ($d eq '7' && substr($x, 1) =~ /^\d{4}$/) { $r{rain24} = substr($x, 1) eq '9999' ? 0 : substr($x, 1) / 10; }
        }
    }
    $r{raining} = (defined $r{ww} && $r{ww} =~ /^\d\d$/ && $r{ww} >= 50 && !($r{ww} >= 70 && $r{ww} <= 79)) ? 1 : 0;
    $r{rh} //= $self->relative_humidity($r{temp_c}, $r{dewpoint_c});
    return \%r;
}

# SYNOP messages of a station from OGIMET (UTC)
sub _synop_records {
    my ($self, $wmo, $start, $end) = @_;
    (my $bd = $start) =~ s/-//g;
    (my $e = $end) =~ s/-//g;
    my $recent = $end ge _iso_days_ago(2);
    my $txt = $self->get_raw("$OGIMET?block=$wmo&begin=${bd}0000&end=${e}2359", $recent ? 'archive_recent' : 'archive');
    die "OGIMET: " . substr($txt, 0, 120) . "\n" if $txt =~ /^\s*</ && $txt !~ /AAXX/;
    my @rows;
    foreach my $line (split /\r?\n/, $txt) {
        my ($st, $y, $m, $d, $hh, $mm, $msg) = split /,/, $line, 7;
        next if !$msg || ($st // '') ne $wmo || $msg !~ /AAXX/;
        my $p = $self->parse_synop($msg);
        next if $p->{nil};
        $p->{time} = timegm(0, $mm, $hh, $d, $m - 1, $y);
        $p->{hour} = $hh + 0;
        $p->{raw} = $msg;
        push @rows, $p;
    }
    return \@rows;
}

# daily summary of SYNOP messages, by local day
sub _synop_daily {
    my ($self, $wmo, $lat, $lon, $start, $end) = @_;
    my $off = _utc_offset_hours($lon);
    my $rows = $self->_synop_records($wmo, _shift_date($start, -1), _shift_date($end, 1));
    # how this station reports rain: the most common period, and the hours of the 24 h reports
    my (%period, %h24, %ir3);
    foreach my $r (@$rows) {
        $period{$_->{hours}}++ for grep { $_->{hours} && $r->{hour} % 6 == 0 } @{$r->{rain}};
        $h24{$r->{hour}}++ if defined $r->{rain24} || grep { ($_->{hours} // 0) == 24 } @{$r->{rain}};
        $ir3{$r->{hour}}++ if $r->{ir} eq '3';
    }
    my ($pattern) = sort { $period{$b} <=> $period{$a} } grep { $_ == 6 || $_ == 12 || $_ == 24 } keys %period;
    my @need = !$pattern ? (grep { $ir3{$_} } 0, 6, 12, 18)
        : $pattern == 24 ? ((sort { $h24{$b} <=> $h24{$a} } keys %h24)[0] // 6)
        : $pattern == 12 ? (6, 18) : (0, 6, 12, 18);

    my %day;
    foreach my $r (@$rows) {
        my @t = gmtime($r->{time} + $off * 3600);
        my $date = sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]);
        my $d = $day{$date} ||= { n => 0, t => [], rh => [], at => {}, rain_reports => 0 };
        $d->{n}++;
        push @{$d->{t}}, $r->{temp_c} if defined $r->{temp_c};
        push @{$d->{rh}}, $r->{rh} if defined $r->{rh};
        $d->{tmax} = $r->{tmax_c} if defined $r->{tmax_c} && (!defined $d->{tmax} || $r->{tmax_c} > $d->{tmax});
        $d->{tmin} = $r->{tmin_c} if defined $r->{tmin_c} && (!defined $d->{tmin} || $r->{tmin_c} < $d->{tmin});
        $d->{rain_reports}++ if $r->{raining};
        $d->{wind} = $r->{wind_kmh} if defined $r->{wind_kmh} && (!defined $d->{wind} || $r->{wind_kmh} > $d->{wind});
        next if $r->{hour} % 6 != 0;
        # rain of this main report for the station's period (0 when iR = 3: no rain)
        my $mm;
        if ($pattern && $pattern == 24) {
            $mm = $r->{rain24} // (map { $_->{mm} } grep { ($_->{hours} // 0) == 24 } @{$r->{rain}})[0];
        }
        elsif ($pattern) {
            $mm = (map { $_->{mm} } grep { ($_->{hours} // 0) == $pattern } @{$r->{rain}})[0];
        }
        $mm = 0 if !defined $mm && $r->{ir} eq '3';
        $d->{at}{$r->{hour}} = $mm if defined $mm;
        $d->{rain24} = $r->{rain24} if defined $r->{rain24};
    }
    my $mean = sub { my $l = shift; return if !@$l; my $s = 0; $s += $_ for @$l; return $s / @$l };
    my @days;
    foreach my $date (sort keys %day) {
        next if $date lt $start || $date gt $end;
        my $d = $day{$date};
        my $rain;
        if (@need && !grep { !defined $d->{at}{$_} } @need) { $rain = 0; $rain += $d->{at}{$_} for @need; }
        my @sorted = sort { $a <=> $b } @{$d->{t}};
        my $tmax = $d->{tmax} // ($d->{n} >= 6 ? $sorted[-1] : undef);
        my $tmin = $d->{tmin} // ($d->{n} >= 6 ? $sorted[0] : undef);
        my $rh = $mean->($d->{rh});
        push @days, {
            date => $date, hours => $d->{n}, complete => defined $rain ? 1 : 0,
            tmax => _r1($tmax), tmin => _r1($tmin), tmean => _r1($mean->($d->{t})),
            rh => defined $rh ? sprintf('%.0f', $rh) + 0 : undef,
            rain => _r1($rain), rain_hours => $d->{rain_reports}, gust_max => $d->{wind},
            et0 => (defined $tmax && defined $tmin) ? $self->hargreaves_et0($lat, _doy($date), $tmax, $tmin) : undef,
            et0_method => (defined $tmax && defined $tmin) ? 'HS' : undef,
        };
    }
    my $how = !$pattern ? 'reports without rain (iR = 3) at the main hours' : $pattern == 24 ? '24-hour rain groups' : "$pattern-hour rain groups";
    if (!grep { defined $_->{rain} } @days) {
        return {
            source => "National weather service station WMO $wmo (SYNOP messages via OGIMET)",
            note => 'This station sends no rain amounts in its messages (or not at the main hours): only temperatures are used. The rain column counts the reports with rain.',
            rain_reported => 0, days => \@days,
        };
    }
    return {
        source => "National weather service station WMO $wmo (SYNOP messages via OGIMET)",
        note => "Daily rain from the station's $how; days are local days of the reports, a 24-hour total is counted on the day it is read (in the morning, like a rain gauge). Max/min from the SYNOP max/min groups. ET0: Hargreaves-Samani.",
        rain_reported => 1, days => \@days,
    };
}

# ------------------------------------------------------------------ CoCoRaHS (USA)

sub _mdy { my ($y, $m, $d) = split /-/, shift; return "$m/$d/$y" }

sub _cocorahs_csv {
    my ($self, $query, $kind) = @_;
    my $csv = $self->get_raw("$COCORAHS?ReportType=Daily&dtf=1&Format=CSV&ReportDateType=reportdate&$query", $kind);
    my @lines = split /\r?\n/, $csv;
    my $head = shift @lines // '';
    die "CoCoRaHS did not return data.\n" if $head !~ /^ObservationDate/;
    my @cols = map { s/^\s+|\s+$//gr } split /,/, $head;
    my @rows;
    foreach my $l (@lines) {
        my @f = map { s/^\s+|\s+$//gr } split /,/, $l, -1;
        next if @f < @cols;
        push @rows, { map { $cols[$_] => $f[$_] } 0 .. $#cols };
    }
    return \@rows;
}

sub _cocorahs_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    my $nets = $self->_iem_networks_near($lat, $lon, $range_km, qr/^[A-Z]{2}_ASOS$/);
    my %us = map { $_ => 1 } qw(AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC PR VI);    # codespell:ignore nd
    my (@stations, %seen);
    foreach my $state (grep { $us{$_} } map { substr($_, 0, 2) } @$nets) {
        my $rows = eval { $self->_cocorahs_csv("State=$state&StartDate=" . _mdy(_iso_days_ago(4)) . '&EndDate=' . _mdy(_iso_days_ago(0)), 'station_list') } or next;
        foreach my $r (@$rows) {
            my $id = $r->{StationNumber} or next;
            next if $seen{$id}++;
            my %st = (
                network => 'cocorahs', id => $id, name => $r->{StationName}, lat => _num($r->{Latitude}), lon => _num($r->{Longitude}),
                country => 'US', state => $state, ready => 1, rain_only => 1, rain_amounts => 1,
            );
            next if !defined $st{lat} || !defined $st{lon};
            next if $self->_place(\%st, $lat, $lon) > $range_km;
            push @stations, \%st;
        }
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} } @stations;
    splice(@stations, $limit) if @stations > $limit;
    return \@stations;
}

sub _cocorahs_daily {
    my ($self, $id, $start, $end) = @_;
    my $recent = $end ge _iso_days_ago(2);
    my $rows = $self->_cocorahs_csv("Station=$id&StartDate=" . _mdy($start) . '&EndDate=' . _mdy($end), $recent ? 'archive_recent' : 'archive');
    my %by;
    foreach my $r (@$rows) {
        my $date = $r->{ObservationDate} // '';
        next if $date !~ /^\d{4}-\d\d-\d\d$/ || $date lt $start || $date gt $end;
        my $v = $r->{TotalPrecipAmt} // '';
        my $mm = $v =~ /^T/i ? 0 : defined _num($v) ? _r1($v * 25.4) : undef;
        next if !defined $mm;
        $by{$date} = { date => $date, rain => $mm, complete => 1, hours => 1, rain_hours => $mm > 0 ? 1 : 0, obs_time => $r->{ObservationTime} };
    }
    return {
        source => "CoCoRaHS volunteer rain gauge $id",
        note => 'One reading per morning (24 hours of rain until the reading time), counted on the day it is read. The station does not measure temperature.',
        rain_reported => 1, rain_only => 1, days => [ map { $by{$_} } sort keys %by ],
    };
}

# ------------------------------------------------------------------ IDEAM (Colombia)

sub _ideam_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    my ($min_lat, $min_lon, $max_lat, $max_lon) = $self->bbox($lat, $lon, $range_km);
    return [] if $max_lat < -4.3 || $min_lat > 13.5 || $max_lon < -79.1 || $min_lon > -66.8;
    my $where = sprintf("fechaobservacion >= '%sT00:00:00' AND latitud::number between %.3f and %.3f AND longitud::number between %.3f and %.3f",
        _iso_days_ago(5), $min_lat, $max_lat, $min_lon, $max_lon);
    my $url = "$IDEAM?\$select=" . _uri('codigoestacion,nombreestacion,latitud,longitud,municipio,departamento,max(fechaobservacion) as last')
        . '&$where=' . _uri($where) . '&$group=' . _uri('codigoestacion,nombreestacion,latitud,longitud,municipio,departamento') . '&$limit=2000';
    my $list = $self->get_json($url, 'station_list');
    my (@stations, %seen);
    foreach my $r (ref($list) eq 'ARRAY' ? @$list : ()) {
        my $id = $r->{codigoestacion} or next;
        next if $seen{$id}++;
        (my $name = $r->{nombreestacion} // $id) =~ s/\s*\[\d+\]\s*$//;
        my %st = (
            network => 'ideam', id => $id, name => _title($name) . ' (' . ($r->{municipio} // '') . ')', lat => _num($r->{latitud}), lon => _num($r->{longitud}),
            country => 'CO', state => $r->{departamento}, ready => 1, rain_only => 1, rain_amounts => 1, last => $r->{last},
        );
        next if !defined $st{lat} || !defined $st{lon};
        next if $self->_place(\%st, $lat, $lon) > $range_km;
        push @stations, \%st;
    }
    @stations = sort { $a->{distance_km} <=> $b->{distance_km} } @stations;
    splice(@stations, $limit) if @stations > $limit;
    return \@stations;
}

sub _uri {
    my $s = shift;
    $s =~ s/([^A-Za-z0-9_.~-])/sprintf('%%%02X', ord($1))/ge;
    return $s;
}

# 10-minute rain of an IDEAM station; IDEAM times are Colombian time (UTC-5)
sub _ideam_records {
    my ($self, $id, $start, $end) = @_;
    my $where = "codigoestacion='$id' AND fechaobservacion between '${start}T00:00:00' and '${end}T23:59:59'";
    my $recent = $end ge _iso_days_ago(2);
    my $list = $self->get_json("$IDEAM?\$select=" . _uri('fechaobservacion,valorobservado') . '&$where=' . _uri($where)
        . '&$order=fechaobservacion&$limit=200000', $recent ? 'archive_recent' : 'archive');
    my (@rows, %seen);
    foreach my $r (ref($list) eq 'ARRAY' ? @$list : ()) {
        my ($y, $m, $d, $hh, $mm) = ($r->{fechaobservacion} // '') =~ /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d)/ or next;
        next if $seen{$r->{fechaobservacion}}++;    # the same reading published twice
        my $v = _num($r->{valorobservado});
        next if !defined $v;
        push @rows, { time => timegm(0, $mm, $hh, $d, $m - 1, $y) + 5 * 3600, rain_mm => $v, raining => $v > 0 ? 1 : 0 };
    }
    return \@rows;
}

sub _iso_days_ago {
    my $n = shift;
    my @t = gmtime(time() - $n * 86400);
    return sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]);
}

# whole hours to add to UTC to get the (standard) local solar time, from the longitude
sub _utc_offset_hours { my $lon = shift; return floor($lon / 15 + 0.5) }

=head2 station_daily($network, $station_id, $lat, $lon, $elev, $start, $end)

Daily summary of the observations of one station between two dates
(YYYY-MM-DD), days in local time. Returns { source, note, rain_reported,
days } where each day has date, tmax, tmin, tmean, rh, rain (mm, undef when
not reported), rain_hours, wind_max (km/h), gust_max, radiation (MJ/m2),
et0 (mm), et0_method, hours (observations in the day).

=cut

sub station_daily {
    my ($self, $network, $id, $lat, $lon, $elev, $start, $end) = @_;
    my $today = _iso_days_ago(0);
    $end = $today if $end gt $today;
    my $off = _utc_offset_hours($lon);

    return $self->_synop_daily($id, $lat, $lon, $start, $end) if $network eq 'synop';
    return $self->_cocorahs_daily($id, $start, $end) if $network eq 'cocorahs';

    my ($hourly, $source, $note, $wind_height);
    if ($network eq 'ideam') {
        $hourly = $self->_ideam_records($id, _shift_date($start, -1), _shift_date($end, 1));
        $source = 'IDEAM automatic station ' . $id;
        $note = 'Rain every 10 minutes, summed per local day. The station does not measure temperature.';
    }
    elsif ($network eq 'inmet') {
        die "INMET data needs a token. Ask INMET for one (free) and set inmet_api_token in the configuration.\n" if !$self->inmet_token;
        # one extra day on each side so the local days are complete
        $hourly = $self->_inmet_hourly($id, _shift_date($start, -1), _shift_date($end, 1));
        $source = 'INMET automatic station ' . $id;
        $note = 'Hourly observations of the station summarized per local day. ET0: FAO-56 Penman-Monteith with the measured radiation, humidity and wind.';
        $wind_height = 10;
    }
    elsif ($network eq 'ana') {
        $hourly = $self->_ana_records($id, _shift_date($start, -1), _shift_date($end, 1));
        $source = 'ANA telemetric station ' . $id;
        $note = 'Rain gauge read every 15 minutes, summed per local day. The station does not measure temperature.';
    }
    elsif ($network eq 'cemaden') {
        my $hours = int((time() - _epoch_of($start) + 3 * 86400) / 3600);
        $hourly = $self->_cemaden_hourly($id, $hours);
        $source = 'CEMADEN rain gauge ' . $id;
        $note = 'Hourly rain summed per local day. CEMADEN gives only the last 96 hours: older days are empty. The station does not measure temperature.';
    }
    else {
        $hourly = $self->_iem_hourly($id, _shift_date($start, -1), _shift_date($end, 1));
        $source = 'Airport ' . $id . ' (METAR archive, Iowa Environmental Mesonet)';
        $note = 'Hourly METARs summarized per local day (max/min of the hourly readings). ET0: Hargreaves-Samani from the measured temperatures.';
        $wind_height = 10;
    }

    my %day;
    foreach my $h (@$hourly) {
        my @t = gmtime($h->{time} + $off * 3600);
        my $date = sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]);
        next if $date lt $start || $date gt $end;
        my $d = $day{$date} ||= { date => $date, n => 0, t => [], rh => [], wind => [], hourset => {}, hours_seen => {} };
        $d->{n}++;
        $d->{hours_seen}{ floor($h->{time} / 3600) } = 1;
        push @{$d->{t}}, $h->{temp_c} if defined $h->{temp_c};
        $d->{tmax} = $h->{tmax_c} if defined $h->{tmax_c} && (!defined $d->{tmax} || $h->{tmax_c} > $d->{tmax});
        $d->{tmin} = $h->{tmin_c} if defined $h->{tmin_c} && (!defined $d->{tmin} || $h->{tmin_c} < $d->{tmin});
        push @{$d->{rh}}, $h->{rh} if defined $h->{rh};
        push @{$d->{wind}}, $h->{wind_ms} if defined $h->{wind_ms};
        $d->{gust} = $h->{gust_kmh} if defined $h->{gust_kmh} && (!defined $d->{gust} || $h->{gust_kmh} > $d->{gust});
        if (defined $h->{rain_mm}) { $d->{rain} += $h->{rain_mm}; $d->{rain_n}++; }
        $d->{hourset}{ floor($h->{time} / 3600) } = 1 if $h->{raining};
        if (defined $h->{rad_kj}) { $d->{rad} += $h->{rad_kj} / 1000; $d->{rad_n}++; }
    }

    # do airports report rain amounts? (Brazilian METARs do not)
    my $rain_reported = 1;
    if ($network eq 'airport') {
        my ($rain_hours, $amounts) = (0, 0);
        foreach my $d (values %day) {
            $rain_hours += scalar keys %{$d->{hourset}};
            $amounts++ if ($d->{rain} // 0) > 0;
        }
        $rain_reported = ($rain_hours && !$amounts) ? 0 : (grep { $_->{rain_n} } values %day) ? 1 : 0;
    }

    my $mean = sub { my $l = shift; return if !@$l; my $s = 0; $s += $_ for @$l; return $s / @$l };
    my @days;
    foreach my $date (sort keys %day) {
        my $d = $day{$date};
        my @sorted = sort { $a <=> $b } @{$d->{t}};
        my $tmax = $d->{tmax} // $sorted[-1];
        my $tmin = $d->{tmin} // $sorted[0];
        $tmax = $sorted[-1] if @sorted && defined $tmax && $sorted[-1] > $tmax;
        $tmin = $sorted[0] if @sorted && defined $tmin && $sorted[0] < $tmin;
        my $rh = $mean->($d->{rh});
        my $wind = $mean->($d->{wind});
        my $rs = ($d->{rad_n} && $d->{rad_n} >= 10) ? $d->{rad} : undef;
        # enough of the day observed to trust max/min: 16 distinct hours, whatever the
        # interval (a 10-minute station sends 16 records in under 3 hours)
        my $complete = keys(%{$d->{hours_seen}}) >= 16;
        my $doy = _doy($date);
        my ($et0, $method);
        if ($complete && defined $rs && defined $rh && defined $wind) {
            $et0 = $self->penman_monteith_et0(lat => $lat, elev => $elev, doy => $doy, tmax => $tmax, tmin => $tmin,
                rh => $rh, rs => $rs, wind => $wind, wind_height => $wind_height);
            $method = 'PM';
        }
        elsif ($complete) {
            $et0 = $self->hargreaves_et0($lat, $doy, $tmax, $tmin);
            $method = 'HS';
        }
        push @days, {
            date => $date,
            hours => $d->{n},
            complete => $complete ? 1 : 0,
            tmax => $complete ? _r1($tmax) : undef,
            tmin => $complete ? _r1($tmin) : undef,
            tmean => _r1($mean->($d->{t})),
            rh => defined $rh ? sprintf('%.0f', $rh) + 0 : undef,
            rain => $rain_reported ? _r1($d->{rain} // ($d->{rain_n} ? 0 : undef)) : undef,
            rain_hours => scalar keys %{$d->{hourset}},
            wind_mean => defined $wind ? _r1($wind * 3.6) : undef,
            gust_max => $d->{gust},
            radiation => _r1($rs),
            et0 => $et0,
            et0_method => $method,
        };
    }
    my %out = (source => $source, note => $note, rain_reported => $rain_reported ? 1 : 0, days => \@days);
    $out{stale} = 1 if $self->{stale};
    if ($network eq 'ana' || $network eq 'cemaden' || $network eq 'ideam') {
        $out{rain_only} = 1;
        $out{history_hours} = 96 if $network eq 'cemaden';
    }
    return \%out;
}

sub _epoch_of {
    my ($y, $m, $d) = split /-/, shift;
    return timegm(0, 0, 0, $d, $m - 1, $y);
}

# 15-minute records of an ANA telemetric station; ANA times are Brasilia time (UTC-3)
sub _ana_records {
    my ($self, $id, $start, $end) = @_;
    my $fmt = sub { my ($y, $m, $d) = split /-/, shift; return "$d/$m/$y" };
    my $recent = $end ge _iso_days_ago(2);
    my $xml = $self->get_raw("$ANA/DadosHidrometeorologicos?codEstacao=$id&dataInicio=" . $fmt->($start) . '&dataFim=' . $fmt->($end),
        $recent ? 'archive_recent' : 'archive');
    if ($xml =~ m{<Error>\s*([^<]+)</Error>}i || $xml =~ m{<MensagemErro>\s*([^<]+)<}i) {
        # ANA answers in Portuguese (UTF-8): the page gets a standard English message, the log the original
        my $msg = _utf8($1);
        $msg =~ s/^\s+|\s+$//g;
        if ($msg ne '') {
            # "Sem dados para esta estação ... no período solicitado": no data is not an error, the
            # station simply sent nothing for these dates (the page says so and may try another one)
            return [] if $msg =~ /sem dados|nenhum dado|n\x{e3}o h\x{e1} dados/i;
            warn "ANA error for station $id ($start to $end): " . encode('UTF-8', $msg) . "\n";
            die "The ANA service could not give the data of station $id for these dates. Try again later or choose another station.\n";
        }
    }
    my @rows;
    while ($xml =~ m{<DadosHidrometereologicos\b[^>]*>(.*?)</DadosHidrometereologicos>}gs) {
        my $r = $1;
        my ($y, $m, $d, $hh, $mm) = $r =~ m{<DataHora>\s*(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d)} or next;
        my ($rain) = $r =~ m{<Chuva>\s*([\d.]+)\s*</Chuva>};
        my ($level) = $r =~ m{<Nivel>\s*([\d.-]+)\s*</Nivel>};
        next if !defined $rain;
        push @rows, {
            time => timegm(0, $mm, $hh, $d, $m - 1, $y) + 3 * 3600,
            rain_mm => $rain + 0,
            raining => $rain > 0 ? 1 : 0,
            level_m => defined $level ? $level / 100 : undef,
        };
    }
    return \@rows;
}

# hourly rain of a CEMADEN gauge (times in UTC); at most the last 96 hours
sub _cemaden_hourly {
    my ($self, $id, $hours) = @_;
    $hours = 96 if !$hours || $hours > 96;
    $hours = 1 if $hours < 1;
    my $list = $self->get_json("$CEMADEN_HOURLY?est=$id&pag=$hours", 'archive_recent');
    $list = [] if ref($list) ne 'ARRAY';
    my @rows;
    foreach my $r (@$list) {
        my ($y, $m, $d, $hh) = ($r->{datahora} // '') =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d)/ or next;
        my $v = _num($r->{valor});
        next if !defined $v;
        push @rows, { time => timegm(0, 0, $hh, $d, $m - 1, $y), rain_mm => $v, raining => $v > 0 ? 1 : 0 };
    }
    return \@rows;
}

sub _shift_date {
    my ($date, $n) = @_;
    my ($y, $m, $d) = split /-/, $date;
    my @t = gmtime(timegm(0, 0, 12, $d, $m - 1, $y) + $n * 86400);
    return sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]);
}

# hourly METARs of an airport from the IEM archive (routine + special reports)
sub _iem_hourly {
    my ($self, $id, $start, $end) = @_;
    my ($y1, $m1, $d1) = split /-/, $start;
    my ($y2, $m2, $d2) = split /-/, _shift_date($end, 1);    # end is exclusive
    my $url = "$IEM?station=$id&data=tmpc&data=dwpc&data=relh&data=sknt&data=gust&data=drct&data=alti&data=vsby&data=p01m&data=wxcodes&data=metar"
        . "&year1=$y1&month1=" . ($m1 + 0) . "&day1=" . ($d1 + 0)
        . "&year2=$y2&month2=" . ($m2 + 0) . "&day2=" . ($d2 + 0)
        . "&tz=Etc/UTC&format=onlycomma&latlon=no&elev=no&missing=empty&trace=empty&direct=no&report_type=3&report_type=4";
    my $recent = $end ge _iso_days_ago(2);
    my $csv = $self->get_raw($url, $recent ? 'archive_recent' : 'archive');
    my @lines = split /\r?\n/, $csv;
    my $head = shift @lines // '';
    die "The METAR archive did not return data for $id.\n" if $head !~ /^station,valid/;
    my @cols = split /,/, $head;
    my %ix = map { $cols[$_] => $_ } 0 .. $#cols;
    my (@rows, %hour_seen);
    foreach my $line (@lines) {
        my @f = split /,/, $line, -1;
        my ($date, $hh, $mm) = ($f[$ix{valid}] // '') =~ /^(\d{4}-\d\d-\d\d) (\d\d):(\d\d)/ or next;
        my ($y, $m, $d) = split /-/, $date;
        my $time = timegm(0, $mm, $hh, $d, $m - 1, $y);
        my $wx = $f[$ix{wxcodes}] // '';
        my $raining = (grep { !/^VC/ && /(RA|DZ|SH|TS|GR|GS|UP)/ && !/^(BC|MI)?FG$/ } split /\s+/, $wx) ? 1 : 0;
        # p01m is the rain since the last routine report; special reports in between carry the
        # amount so far: the largest value of each clock hour is the hourly total (set below)
        my $p = _num($f[$ix{p01m}]);
        my $hourkey = floor($time / 3600);
        my $rain;
        if (defined $p) {
            if (!defined $hour_seen{$hourkey}) { $hour_seen{$hourkey} = scalar(@rows); $rain = $p; }
            elsif ($p > ($rows[$hour_seen{$hourkey}]{rain_mm} // 0)) { $rows[$hour_seen{$hourkey}]{rain_mm} = $p; }
        }
        my $kt = _num($f[$ix{sknt}]);
        my $gust = _num($f[$ix{gust}]);
        my $alti = defined $ix{alti} ? _num($f[$ix{alti}]) : undef;
        my $vsby = defined $ix{vsby} ? _num($f[$ix{vsby}]) : undef;
        push @rows, {
            time => $time,
            temp_c => _num($f[$ix{tmpc}]),
            dewpoint_c => defined $ix{dwpc} ? _num($f[$ix{dwpc}]) : undef,
            rh => _num($f[$ix{relh}]),
            wind_ms => defined $kt ? $kt * 0.514444 : undef,
            wind_kmh => defined $kt ? sprintf('%.0f', $kt * 1.852) + 0 : undef,
            wind_dir => defined $ix{drct} ? _num($f[$ix{drct}]) : undef,
            gust_kmh => defined $gust ? sprintf('%.0f', $gust * 1.852) + 0 : undef,
            pressure_hpa => defined $alti ? sprintf('%.0f', $alti * 33.8639) + 0 : undef,
            visibility_km => defined $vsby ? _r1($vsby * KM_PER_MILE) : undef,
            rain_mm => $rain,
            raining => $raining,
            weather => $wx,
            raw => defined $ix{metar} ? $f[$ix{metar}] : undef,
        };
    }
    return \@rows;
}

# hourly records of an INMET automatic station (needs the token)
sub _inmet_hourly {
    my ($self, $id, $start, $end) = @_;
    die "INMET data needs a token. Ask INMET for one (free) and set inmet_api_token in the configuration.\n" if !$self->inmet_token;
    my $recent = $end ge _iso_days_ago(2);
    my $list = $self->get_json("$INMET/token/estacao/$start/$end/$id/" . $self->inmet_token, $recent ? 'archive_recent' : 'archive');
    if (ref($list) eq 'HASH') {
        die "INMET refused the request: " . ($list->{message} // $list->{error} // 'check inmet_api_token') . "\n";
    }
    my @rows;
    foreach my $r (@$list) {
        my ($y, $m, $d) = split /-/, ($r->{DT_MEDICAO} // '');
        my $hhmm = $r->{HR_MEDICAO} // '';
        next if !$d || $hhmm !~ /^(\d\d)(\d\d)/;
        my $time = timegm(0, $2, $1, $d, $m - 1, $y);    # INMET hours are UTC
        my $rad = _num($r->{RAD_GLO});
        my $rain = _num($r->{CHUVA});
        my $gust = _num($r->{VEN_RAJ});
        push @rows, {
            time => $time,
            temp_c => _num($r->{TEM_INS}),
            tmax_c => _num($r->{TEM_MAX}),
            tmin_c => _num($r->{TEM_MIN}),
            rh => _num($r->{UMD_INS}),
            dewpoint_c => _num($r->{PTO_INS}),
            pressure_hpa => _num($r->{PRE_INS}),
            wind_ms => _num($r->{VEN_VEL}),
            wind_dir => _num($r->{VEN_DIR}),
            wind_kmh => defined _num($r->{VEN_VEL}) ? sprintf('%.0f', $r->{VEN_VEL} * 3.6) + 0 : undef,
            gust_kmh => defined $gust ? sprintf('%.0f', $gust * 3.6) + 0 : undef,
            rain_mm => $rain,
            raining => ($rain // 0) > 0 ? 1 : 0,
            rad_kj => (defined $rad && $rad > 0) ? $rad : (defined $rad ? 0 : undef),
        };
    }
    return \@rows;
}


__PACKAGE__->meta->make_immutable;

1;

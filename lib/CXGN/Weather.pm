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

=item * dwd: stations of the Deutscher Wetterdienst (Germany), open data of
the Climate Data Center: daily values of the climate stations and of the
rain gauges (ids starting with R), recent and historical files (zip).

=item * jma: AMeDAS stations of the Japan Meteorological Agency: station
table of the AMeDAS site, daily values from the pages of the JMA climate
archive (one page per month).

=item * eccc: climate stations of Environment and Climate Change Canada
(MSC GeoMet OGC API, daily climate data).

=item * scan (USDA NRCS Soil Climate Analysis Network, AWDB web service),
isusm (Iowa State University stations, Iowa Environmental Mesonet), coagmet
(Colorado State University) and azmet (University of Arizona): agricultural
stations of the USA with daily data.

=item * conagua: climatological stations of the Servicio Meteorologico
Nacional of Mexico (daily files of the national database; often months late).

=item * inta: stations of INTA, Argentina (SIGA web service).

=item * silo: stations of the Bureau of Meteorology through SILO
(Queensland Government); only the values SILO marks as observed are used.
SILO asks for the e-mail address of the site admin (silo_username).

=item * ims: climate stations and rain gauges of the Israel Meteorological
Service (climate archive on data.gov.il, published after monthly QC).

=item * hilltop: rain gauges and climate stations of the New Zealand regional
councils (their Hilltop servers; list in weather_hilltop_servers).

=item * aemet (Spain), meteofrance (France) and dmc (Chile): national weather
services with a free key (aemet_api_key, meteofrance_api_key, dmc_api_key
written e-mail:token). Every key setting may list several keys: when a
service refuses one, the next is used (with_keys).

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
use IO::Uncompress::Unzip;

use constant KM_PER_MILE => 1.609344;
use constant EARTH_RADIUS_KM => 6371.0088;

my $IEM_SITE = 'https://mesonet.agron.iastate.edu';
my $IEM = "$IEM_SITE/cgi-bin/request/asos.py";
my $OGIMET = 'https://www.ogimet.com/cgi-bin/getsynop';
my $OSCAR = 'https://oscar.wmo.int/surface/rest/api/search/station';
my $COCORAHS = 'https://data.cocorahs.org/export/exportreports.aspx';
my $IDEAM = 'https://www.datos.gov.co/resource/s54a-sgyg.json';
my $IDEAM_DATA = 'https://www.datos.gov.co/resource';
my %IDEAM_SETS = (tmax => 'ccvq-rp9s', tmin => 'afdg-3zpb');
my $INMET = 'https://apitempo.inmet.gov.br';
my $ANA = 'https://telemetriaws1.ana.gov.br/ServiceANA.asmx';
my $CEMADEN_LIST = 'https://resources.cemaden.gov.br/graficos/interativo/getJson2.php';
my $CEMADEN_HOURLY = 'https://resources.cemaden.gov.br/graficos/cemaden/hidro/resources/json/AcumuladoResource.php';
my $DWD = 'https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/daily';
my $JMA_TABLE = 'https://www.jma.go.jp/bosai/amedas/const/amedastable.json';
my $JMA_ETRN = 'https://www.data.jma.go.jp/stats/etrn';
my $ECCC = 'https://api.weather.gc.ca/collections';
my $AWDB = 'https://wcc.sc.egov.usda.gov/awdbRestApi/services/v1';
my $COAGMET = 'https://coagmet.colostate.edu/data';
my $AZMET = 'https://api.azmet.arizona.edu/v1';
my $AZMET_STATIONS = 'https://raw.githubusercontent.com/uace-azmet/azmetr/main/data-raw/azmet-station-info.csv';
my $CONAGUA_STATIONS = 'https://smn.conagua.gob.mx/tools/GUI/estaciones-climatologicas/data/estaciones_climatologicas.geojson';
my $SIGA = 'https://siga.inta.gob.ar/E7HYRhmod5ERWTQH.php';
my $SILO = 'https://www.longpaddock.qld.gov.au/cgi-bin/silo/PatchedPointDataset.php';
my $BOM_STATIONS = 'ftp://ftp.bom.gov.au/anon2/home/ncc/metadata/sitelists/stations.zip';
my $DATAGOVIL = 'https://data.gov.il/api/3/action/datastore_search';
my %IMS_RES = (stations => '83841660-b9c4-4ecc-a403-d435b3e8c92f', daily => 'cee3ad4a-4e77-4015-8245-52505417d7ea', rain => 'e80b470f-fcbc-4987-a685-d4fbefbd75d1');
my @HILLTOP_DEFAULT = ('https://hilltop.gw.govt.nz/data.hts', 'https://hilltopserver.horizons.govt.nz/data.hts', 'https://envdata.tasman.govt.nz/data.hts',
    'https://hydro.marlborough.govt.nz/data.hts', 'https://extranet.trc.govt.nz/getdata/merged.hts');
my $AEMET = 'https://opendata.aemet.es/opendata/api';
my $GEO_GOUV = 'https://geo.api.gouv.fr';
my $METEOFRANCE = 'https://public-api.meteofrance.fr/public/DPClim/v1';
my $DMC = 'https://climatologia.meteochile.gob.cl/application';
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
    dwd_stations => 86400,
    scan_stations => 86400,
    conagua_stations => 7 * 86400,
    jma_stations => 30 * 86400,
    metar => 600,
    archive => 86400,
    archive_recent => 1800,
);

has 'cache_dir' => (isa => 'Maybe[Str]', is => 'ro', default => sub { File::Spec->catdir(File::Spec->tmpdir(), 'breedbase_weather_cache') });
has 'inmet_token' => (isa => 'Maybe[Str]', is => 'ro');
# free keys of the networks that need one: { network => key } (inmet may also come as inmet_token)
has 'api_keys' => (isa => 'HashRef', is => 'ro', default => sub { {} });
# Hilltop servers of the New Zealand regional councils (comma list; default: the councils known to publish)
has 'hilltop_servers' => (isa => 'Maybe[Str]', is => 'ro');

=head2 api_key($network)

The key of a network that needs one (undef when not configured).

=cut

sub api_key {
    my ($self, $network) = @_;
    my $key = $self->api_keys->{$network};
    $key = $self->inmet_token if $network eq 'inmet' && !$key;
    return (defined $key && $key ne '' && $key ne 'NULL') ? $key : undef;
}

# dies with the message for the page when the key of a network is missing
sub _need_key {
    my ($self, $network) = @_;
    my $key = $self->api_key($network);
    return $key if $key;
    my $n = $self->networks()->{$network} || {};
    die "Reading the data of $n->{label} stations needs a free key: get one at $n->{key_url} and set $n->{key_config} in sgn_local.conf.\n";
}
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

=head2 get_raw($url, $kind, \%headers)

GET a URL through the disk cache ($kind picks the time to live). Returns the
body ('' for "no content"). Dies with a short message when the service
cannot be reached. Optional request headers (keys of the services that take
them in a header: they are not part of the cache name).

=cut

sub get_raw {
    my ($self, $url, $kind, $headers) = @_;
    my $ttl = $TTL{$kind} // 3600;
    my $file;
    if ($self->cache_dir) {
        eval { make_path($self->cache_dir) unless -d $self->cache_dir; };
        $file = File::Spec->catfile($self->cache_dir, $kind . '_' . md5_hex(_no_secrets($url)));
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
    local $ENV{FTP_PASSIVE} = 1;    # FTP servers (Bureau of Meteorology) behind firewalls
    for my $try (1 .. $tries) {
        $r = $self->ua->get($url, %{$headers || {}});
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
        my ($host) = $url =~ m{^\w+://([^/]+)};
        die "The weather service $host did not answer (" . $r->status_line . "). Try again in a few minutes.\n";
    }
    my $raw = $r->decoded_content(charset => 'none') // '';
    $self->_cache_put($file, $raw);
    return $raw;
}

# the cache file of a URL (or of any other name of a request)
sub _cache_file {
    my ($self, $kind, $name) = @_;
    return if !$self->cache_dir;
    eval { make_path($self->cache_dir) unless -d $self->cache_dir; };
    return File::Spec->catfile($self->cache_dir, $kind . '_' . md5_hex(_no_secrets($name)));
}

# the cached copy when younger than the time to live of $kind
sub _cache_get {
    my ($self, $kind, $name) = @_;
    my $file = $self->_cache_file($kind, $name) or return;
    return if !-e $file || (time() - (stat($file))[9]) >= ($TTL{$kind} // 3600);
    open(my $fh, '<:raw', $file) or return;
    local $/;
    my $raw = <$fh>;
    close $fh;
    return $raw;
}

sub _cache_put {
    my ($self, $file, $raw) = @_;
    return if !$file;
    if (open(my $fh, '>:raw', "$file.$$")) {
        print $fh $raw;
        close $fh;
        rename("$file.$$", $file);
    }
    return;
}

# URLs without the keys some services take in the query string (cache names, messages)
sub _no_secrets {
    my $url = shift // '';
    $url =~ s/\b(token|apikey|api_key|appKey|authKey|Authorization|username|usuario)=[^&]*/$1=x/gi;
    return $url;
}

=head2 prefetch([$url, $kind, \%headers], ...)

Fetches several URLs at the same time (one child process each) into the disk
cache, so that the next get_raw of each is immediate. Slow open-data services
that need several queries per station stay within the page time limit.
Errors are ignored here: the next get_raw reports them.

=cut

sub prefetch {
    my ($self, @req) = @_;
    return if !$self->cache_dir || @req < 2;
    my @todo = grep { !defined $self->_cache_get($_->[1], $_->[0]) } @req;
    return if @todo < 2;
    my @pids;
    foreach my $q (@todo) {
        my $pid = fork();
        next if !defined $pid;
        if (!$pid) {
            eval { $self->get_raw(@$q) };
            POSIX::_exit(0);    # no destructors in the child (database handles of the parent)
        }
        push @pids, $pid;
    }
    waitpid($_, 0) for @pids;
    return;
}

=head2 with_keys($network, sub { my $key = shift; ... })

Runs the code with the first key of the network; when the service refuses
that key (401, 403, 429, quota) the next key is tried. Several keys can be
set in the configuration, separated by commas: partners of an international
program can each bring their own.

=cut

sub with_keys {
    my ($self, $network, $code) = @_;
    my @keys = $self->api_keys_of($network);
    if (!@keys) { $self->_need_key($network); }
    my $err;
    foreach my $key (@keys) {
        my @r = eval { $code->($key) };
        return wantarray ? @r : $r[0] if !$@;
        $err = $@;
        last if $err !~ /\b(401|403|429)\b|quota|denied|forbidden|credential|token|key/i;
    }
    die $err;
}

=head2 api_keys_of($network)

All the keys of a network (the configuration may list several, separated by commas or spaces).

=cut

sub api_keys_of {
    my ($self, $network) = @_;
    my $all = $self->api_key($network) // '';
    return grep { $_ ne '' && $_ ne 'NULL' } split /[\s,;]+/, $all;
}

=head2 get_json($url, $kind)

get_raw and decode JSON (an empty body gives an empty list).

=cut

sub get_json {
    my ($self, $url, $kind, $headers) = @_;
    my $raw = $self->get_raw($url, $kind, $headers);
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
            ready => $self->api_key('inmet') ? 1 : 0,
            key_config => 'inmet_api_token', key_url => 'https://portal.inmet.gov.br',
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
        dwd => {
            label => 'DWD station (Germany)',
            source => 'DWD - Deutscher Wetterdienst, Climate Data Center open data',
            note => 'Daily values of the climate stations (temperature, rain, humidity, wind, sunshine) and of the rain gauges (rain only), with history.',
        },
        jma => {
            label => 'JMA AMeDAS station (Japan)',
            source => 'JMA - Japan Meteorological Agency, AMeDAS and the climate archive',
            note => 'Daily values (rain about every 17 km; temperature, humidity, wind and sunshine at most stations), with history.',
        },
        eccc => {
            label => 'ECCC climate station (Canada)', short => 'ECCC',
            source => 'Environment and Climate Change Canada, MSC GeoMet OGC API (Data Source: Environment and Climate Change Canada)',
            note => 'Daily temperature, precipitation, humidity and gusts of the Canadian climate stations, with history.', temp => 1, rain => 1,
        },
        scan => {
            label => 'USDA SCAN station (USA)', short => 'SCAN',
            source => 'USDA NRCS Soil Climate Analysis Network (AWDB web service)',
            note => 'Daily temperature, rain and wind of the agricultural soil-climate stations, since about 2001.', temp => 1, rain => 1,
        },
        isusm => {
            label => 'ISU Soil Moisture station (Iowa)', short => 'ISU Soil Moisture',
            source => 'Iowa State University, Iowa Environmental Mesonet',
            note => 'Daily temperature, rain, humidity, wind and radiation of the ISU agricultural stations.', temp => 1, rain => 1,
        },
        coagmet => {
            label => 'CoAgMet station (Colorado)', short => 'CoAgMet',
            source => 'Colorado Agricultural Meteorological Network, Colorado State University',
            note => 'Daily temperature, rain, humidity, wind and radiation of the agricultural stations.', temp => 1, rain => 1,
        },
        azmet => {
            label => 'AZMet station (Arizona)', short => 'AZMet',
            source => 'Arizona Meteorological Network, University of Arizona',
            note => 'Daily temperature, rain, humidity, wind and radiation of the agricultural stations.', temp => 1, rain => 1,
        },
        conagua => {
            label => 'SMN climatological station (Mexico)', short => 'SMN Mexico',
            source => 'Servicio Meteorologico Nacional / CONAGUA, national climatological database',
            note => 'Daily rain and max/min temperature, long history; the latest months often arrive late.', temp => 1, rain => 1,
        },
        inta => {
            label => 'INTA station (Argentina)', short => 'INTA',
            source => 'INTA - Instituto Nacional de Tecnologia Agropecuaria, SIGA',
            note => 'Daily temperature, rain, humidity, wind and radiation of the INTA agricultural stations.', temp => 1, rain => 1,
        },
        silo => {
            label => 'Bureau of Meteorology station via SILO (Australia)', short => 'SILO',
            source => 'SILO Patched Point dataset (Queensland Government), observations of the Bureau of Meteorology',
            note => 'Daily rain and max/min temperature observed at the station (interpolated values are left out).', temp => 1, rain => 1,
            ready => $self->api_key('silo') ? 1 : 0, key_config => 'silo_username', key_url => 'https://www.longpaddock.qld.gov.au/silo/',
        },
        ims => {
            label => 'IMS station (Israel)', short => 'IMS',
            source => 'Israel Meteorological Service, climate archive on data.gov.il',
            note => 'Daily max/min temperature of the climate stations and daily rain of the rain gauges, after the monthly quality control.', temp => 1, rain => 1,
        },
        hilltop => {
            label => 'Regional council station (New Zealand)', short => 'NZ council',
            source => 'Hilltop servers of the New Zealand regional councils',
            note => 'Rain gauges and climate stations of the regional councils: daily totals and extremes.', temp => 1, rain => 1,
        },
        aemet => {
            label => 'AEMET station (Spain)', short => 'AEMET',
            source => 'AEMET - Agencia Estatal de Meteorologia, OpenData',
            note => 'Daily temperature, rain, humidity, wind and sunshine, with history.', temp => 1, rain => 1,
            ready => $self->api_key('aemet') ? 1 : 0, key_config => 'aemet_api_key', key_url => 'https://opendata.aemet.es/centrodedescargas/altaUsuario',
        },
        meteofrance => {
            label => 'Meteo-France station (France)', short => 'Meteo-France',
            source => 'Meteo-France, climatological data API (portail-api.meteofrance.fr)',
            note => 'Daily temperature, rain, humidity, wind, radiation and sunshine, with history.', temp => 1, rain => 1,
            ready => $self->api_key('meteofrance') ? 1 : 0, key_config => 'meteofrance_api_key', key_url => 'https://portail-api.meteofrance.fr',
        },
        dmc => {
            label => 'DMC automatic station (Chile)', short => 'DMC Chile',
            source => 'Direccion Meteorologica de Chile, climatologia.meteochile.gob.cl services',
            note => 'Temperature, rain, humidity, wind and radiation of the automatic stations (15-minute records summarized per day).', temp => 1, rain => 1,
            ready => $self->api_key('dmc') ? 1 : 0, key_config => 'dmc_api_key', key_url => 'https://climatologia.meteochile.gob.cl/application/usuario/registroUsuario',
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
                : $self->can("_${n}_stations") ? $self->can("_${n}_stations")->($self, $lat, $lon, $range_km, $limit)
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
            ready => $self->api_key('inmet') ? 1 : 0, has_taf => 0,
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
    my $query = '?$select=' . _uri('codigoestacion,nombreestacion,latitud,longitud,municipio,departamento,max(fechaobservacion) as last')
        . '&$where=' . _uri($where) . '&$group=' . _uri('codigoestacion,nombreestacion,latitud,longitud,municipio,departamento') . '&$limit=2000';
    $self->prefetch([ $IDEAM . $query, 'station_list' ], [ "$IDEAM_DATA/$IDEAM_SETS{tmax}.json" . $query, 'station_list' ]);
    my $list = $self->get_json($IDEAM . $query, 'station_list');
    # stations that also measure temperature (max temperature dataset of IDEAM)
    my $temp = eval { $self->get_json("$IDEAM_DATA/$IDEAM_SETS{tmax}.json" . $query, 'station_list') } || [];
    my %has_temp = map { ($_->{codigoestacion} // '') => 1 } @{ref($temp) eq 'ARRAY' ? $temp : []};
    my %has_rain = map { ($_->{codigoestacion} // '') => 1 } @{ref($list) eq 'ARRAY' ? $list : []};
    my (@stations, %seen);
    foreach my $r ((ref($list) eq 'ARRAY' ? @$list : ()), (ref($temp) eq 'ARRAY' ? @$temp : ())) {
        my $id = $r->{codigoestacion} or next;
        next if $seen{$id}++;
        (my $name = $r->{nombreestacion} // $id) =~ s/\s*\[\d+\]\s*$//;
        my %st = (
            network => 'ideam', id => $id, name => _title($name) . ' (' . ($r->{municipio} // '') . ')', lat => _num($r->{latitud}), lon => _num($r->{longitud}),
            country => 'CO', state => $r->{departamento}, ready => 1, rain_amounts => $has_rain{$id} ? 1 : 0, last => $r->{last},
            ($has_temp{$id} ? () : (rain_only => 1)),
            measures => [ ($has_temp{$id} ? 'temperature' : ()), ($has_rain{$id} ? 'rain' : ()) ],
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

# records of an IDEAM station: 10-minute rain, plus the hourly max / min temperature and
# humidity of the stations that measure them; IDEAM times are Colombian time (UTC-5)
sub _ideam_records {
    my ($self, $id, $start, $end) = @_;
    my $where = "codigoestacion='$id' AND fechaobservacion between '${start}T00:00:00' and '${end}T23:59:59'";
    my $recent = $end ge _iso_days_ago(2);
    my $query = '?$select=' . _uri('fechaobservacion,valorobservado') . '&$where=' . _uri($where) . '&$order=fechaobservacion&$limit=200000';
    my @rows;
    my %url = map { $_ => ($_ eq 'rain' ? $IDEAM . $query : "$IDEAM_DATA/$IDEAM_SETS{$_}.json" . $query) } 'rain', 'tmax', 'tmin';
    $self->prefetch(map { [ $url{$_}, $recent ? 'archive_recent' : 'archive' ] } sort keys %url);
    foreach my $set ('rain', 'tmax', 'tmin') {
        my $url = $url{$set};
        my $list = $set eq 'rain' ? $self->get_json($url, $recent ? 'archive_recent' : 'archive')
            : eval { $self->get_json($url, $recent ? 'archive_recent' : 'archive') } || [];
        my %seen;
        foreach my $r (ref($list) eq 'ARRAY' ? @$list : ()) {
            my ($y, $m, $d, $hh, $mm) = ($r->{fechaobservacion} // '') =~ /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d)/ or next;
            next if $seen{$r->{fechaobservacion}}++;    # the same reading published twice
            my $v = _num($r->{valorobservado});
            next if !defined $v;
            my $time = timegm(0, $mm, $hh, $d, $m - 1, $y) + 5 * 3600;
            push @rows, $set eq 'rain' ? { time => $time, rain_mm => $v, raining => $v > 0 ? 1 : 0 }
                : $set eq 'tmax' ? { time => $time, tmax_c => $v, temp_c => $v }
                : $set eq 'tmin' ? { time => $time, tmin_c => $v, temp_c => $v }
                : { time => $time, rh => $v };
        }
    }
    @rows = sort { $a->{time} <=> $b->{time} } @rows;
    return \@rows;
}

sub _iso_days_ago {
    my $n = shift;
    my @t = gmtime(time() - $n * 86400);
    return sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]);
}

# whole hours to add to UTC to get the (standard) local solar time, from the longitude
sub _utc_offset_hours { my $lon = shift; return floor($lon / 15 + 0.5) }

=head2 sunshine_radiation($lat, $day_of_year, $sunshine_hours)

Global radiation (MJ m-2 day-1) from the hours of bright sunshine, Angstrom
formula with the FAO-56 coefficients (eq. 35): for stations that measure
sunshine but not radiation.

=cut

sub sunshine_radiation {
    my ($self, $lat, $doy, $n) = @_;
    return if !defined $n || $n < 0;
    my $phi = deg2rad($lat);
    my $delta = 0.409 * sin(2 * pi * $doy / 365 - 1.39);
    my $x = -_tan($phi) * _tan($delta);
    $x = -1 if $x < -1;
    $x = 1 if $x > 1;
    my $daylight = 24 / pi * _acos($x);
    return if $daylight <= 0;
    my $ratio = $n / $daylight;
    $ratio = 1 if $ratio > 1;
    return (0.25 + 0.5 * $ratio) * $self->extraterrestrial_radiation($lat, $doy);
}

# one day of a network that publishes daily values: %v has tmax, tmin, tmean, rh (%), rain (mm),
# wind (mean, m/s at 10 m), gust (m/s), sunshine (h) or radiation (MJ/m2); ET0 Penman-Monteith
# when radiation (or sunshine), humidity and wind are there, otherwise Hargreaves-Samani
sub _daily_values {
    my ($self, $lat, $elev, $date, %v) = @_;
    my $doy = _doy($date);
    my $rs = $v{radiation} // (defined $v{sunshine} ? $self->sunshine_radiation($lat, $doy, $v{sunshine}) : undef);
    my $temps = defined $v{tmax} && defined $v{tmin} && $v{tmax} >= $v{tmin};
    my ($et0, $method);
    if ($temps && defined $rs && defined $v{rh} && defined $v{wind}) {
        $et0 = $self->penman_monteith_et0(lat => $lat, elev => $elev, doy => $doy, tmax => $v{tmax}, tmin => $v{tmin},
            rh => $v{rh}, rs => $rs, wind => $v{wind}, wind_height => $v{wind_height} || 10);
        $method = 'PM';
    }
    elsif ($temps) {
        $et0 = $self->hargreaves_et0($lat, $doy, $v{tmax}, $v{tmin});
        $method = 'HS';
    }
    return {
        date => $date, hours => 24, complete => (defined $v{rain} || $temps) ? 1 : 0,
        tmax => _r1($v{tmax}), tmin => _r1($v{tmin}),
        tmean => _r1($v{tmean} // ($temps ? ($v{tmax} + $v{tmin}) / 2 : undef)),
        rh => defined $v{rh} ? sprintf('%.0f', $v{rh}) + 0 : undef,
        rain => _r1($v{rain}), rain_hours => defined $v{rain} ? ($v{rain} > 0 ? 1 : 0) : 0,
        wind_mean => defined $v{wind} ? _r1($v{wind} * 3.6) : undef,
        gust_max => defined $v{gust} ? sprintf('%.0f', $v{gust} * 3.6) + 0 : undef,
        radiation => _r1($rs), sunshine => _r1($v{sunshine}),
        et0 => $et0, et0_method => $method,
    };
}

sub _in_box {
    my ($self, $lat, $lon, $range_km, $s, $w, $n, $e) = @_;
    my ($min_lat, $min_lon, $max_lat, $max_lon) = $self->bbox($lat, $lon, $range_km);
    return !($max_lat < $s || $min_lat > $n || $max_lon < $w || $min_lon > $e);
}

sub _nearest {
    my ($list, $limit) = @_;
    my @s = sort { $a->{distance_km} <=> $b->{distance_km} } @$list;
    splice(@s, $limit) if @s > $limit;
    return \@s;
}

# ------------------------------------------------------------------ DWD (Germany)

# DWD station description files (fixed width, Latin-1); $set = kl (climate stations) or more_precip (rain gauges)
sub _dwd_station_file {
    my ($self, $set) = @_;
    my $file = $set eq 'kl' ? 'KL_Tageswerte_Beschreibung_Stationen.txt' : 'RR_Tageswerte_Beschreibung_Stationen.txt';
    my $raw = decode('latin1', $self->get_raw("$DWD/$set/recent/$file", 'dwd_stations'));
    my $active = _iso_days_ago(30) =~ s/-//gr;
    my @list;
    foreach my $line (split /\r?\n/, $raw) {
        my ($id, $from, $to, $elev, $lat, $lon, $rest) = $line =~ /^\s*(\d{5})\s+(\d{8})\s+(\d{8})\s+(-?\d+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(.*)$/ or next;
        next if $to lt $active;    # closed stations
        my ($name, $state) = split /\s{2,}/, $rest;
        push @list, { id => $id, from => $from, lat => $lat + 0, lon => $lon + 0, elev => $elev + 0, name => $name, state => $state };
    }
    return \@list;
}

sub _dwd_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 47.2, 5.8, 55.1, 15.1);
    my (@stations, %climate);
    foreach my $s (@{$self->_dwd_station_file('kl')}) {
        $climate{$s->{id}} = 1;
        my %st = (network => 'dwd', id => $s->{id}, name => $s->{name}, lat => $s->{lat}, lon => $s->{lon}, elev => $s->{elev},
            country => 'DE', state => $s->{state}, ready => 1, rain_amounts => 1, since => $s->{from},
            measures => ['temperature', 'rain', 'humidity', 'wind', 'sunshine']);
        next if $self->_place(\%st, $lat, $lon) > $range_km;
        push @stations, \%st;
    }
    # the dense network of rain gauges (stations already listed as climate stations are skipped)
    my $gauges = eval { $self->_dwd_station_file('more_precip') } || [];
    foreach my $s (@$gauges) {
        next if $climate{$s->{id}};
        my %st = (network => 'dwd', id => 'R' . $s->{id}, name => $s->{name}, lat => $s->{lat}, lon => $s->{lon}, elev => $s->{elev},
            country => 'DE', state => $s->{state}, ready => 1, rain_only => 1, rain_amounts => 1, since => $s->{from}, measures => ['rain']);
        next if $self->_place(\%st, $lat, $lon) > $range_km;
        push @stations, \%st;
    }
    return _nearest(\@stations, $limit);
}

# the 'produkt' CSV inside a DWD zip file, as a list of hashes
sub _dwd_zip_rows {
    my ($self, $zip) = @_;
    my $u = IO::Uncompress::Unzip->new(\$zip) or die "A DWD file could not be opened.\n";
    my $csv;
    for (my $status = 1; $status > 0; $status = $u->nextStream) {
        next if ($u->getHeaderInfo->{Name} // '') !~ /^produkt/;    # codespell:ignore produkt
        local $/;
        $csv = <$u>;
        last;
    }
    $u->close;
    die "A DWD file had no data.\n" if !defined $csv;
    my @lines = split /\r?\n/, $csv;
    my @cols = map { s/^\s+|\s+$//gr } split /;/, (shift(@lines) // '');
    my @rows;
    foreach my $l (@lines) {
        my @f = map { s/^\s+|\s+$//gr } split /;/, $l;
        push @rows, { map { $cols[$_] => (($f[$_] // '-999') eq '-999' ? undef : $f[$_]) } 0 .. $#cols };
    }
    return \@rows;
}

sub _dwd_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my $gauge = $id =~ s/^R//;
    my ($set, $prefix) = $gauge ? ('more_precip', 'RR') : ('kl', 'KL');
    my $recent = $end ge _iso_days_ago(2);
    my @zips = ($self->get_raw("$DWD/$set/recent/tageswerte_${prefix}_${id}_akt.zip", $recent ? 'archive_recent' : 'archive'));
    my $first = (sort map { $_->{MESS_DATUM} // '99999999' } @{$self->_dwd_zip_rows($zips[0])})[0] // '99999999';
    if (($start =~ s/-//gr) lt $first) {
        # older days: the historical file (its name carries its dates)
        my ($hist) = $self->get_raw("$DWD/$set/historical/", 'dwd_stations') =~ /(tageswerte_${prefix}_${id}_\d{8}_\d{8}_hist\.zip)/;
        unshift @zips, $self->get_raw("$DWD/$set/historical/$hist", 'archive') if $hist;
    }
    my %by;
    foreach my $zip (@zips) {
        foreach my $r (@{$self->_dwd_zip_rows($zip)}) {
            my ($y, $m, $d) = ($r->{MESS_DATUM} // '') =~ /^(\d{4})(\d\d)(\d\d)$/ or next;
            my $date = "$y-$m-$d";
            next if $date lt $start || $date gt $end;
            $by{$date} = $gauge
                ? $self->_daily_values($lat, $elev, $date, rain => _num($r->{RS}))
                : $self->_daily_values($lat, $elev, $date, tmax => _num($r->{TXK}), tmin => _num($r->{TNK}), tmean => _num($r->{TMK}),
                    rh => _num($r->{UPM}), rain => _num($r->{RSK}), wind => _num($r->{FM}), gust => _num($r->{FX}), sunshine => _num($r->{SDK}));
        }
    }
    return {
        source => ($gauge ? 'DWD rain gauge ' : 'DWD climate station ') . $id . ' (Deutscher Wetterdienst, open data)',
        note => 'Daily values published by DWD (the rain day of DWD runs from the morning of the day to the morning of the next). '
            . ($gauge ? 'The station does not measure temperature.' : 'ET0: FAO-56 Penman-Monteith with the radiation estimated from the hours of sunshine.')
            . ' The latest day is usually yesterday.',
        rain_reported => 1, ($gauge ? (rain_only => 1) : ()), days => [ map { $by{$_} } sort keys %by ],
    };
}

# ------------------------------------------------------------------ JMA AMeDAS (Japan)

sub _jma_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 20, 122, 46, 154);
    my $table = $self->get_json($JMA_TABLE, 'jma_stations');
    my @stations;
    foreach my $id (keys %{ref($table) eq 'HASH' ? $table : {}}) {
        my $s = $table->{$id};
        my ($la, $lo) = ($s->{lat}, $s->{lon});
        next if ref($la) ne 'ARRAY' || ref($lo) ne 'ARRAY';
        my $temp = substr($s->{elems} // '', 0, 1) eq '1';
        my %st = (network => 'jma', id => $id, name => $s->{enName} . ' (' . $s->{kjName} . ')',
            lat => _r4($la->[0] + $la->[1] / 60), lon => _r4($lo->[0] + $lo->[1] / 60), elev => $s->{alt},
            country => 'JP', ready => 1, rain_amounts => 1, ($temp ? () : (rain_only => 1)),
            measures => $temp ? ['temperature', 'rain', 'humidity', 'wind', 'sunshine'] : ['rain']);
        next if $self->_place(\%st, $lat, $lon) > $range_km;
        push @stations, \%st;
    }
    return _nearest(\@stations, $limit);
}

sub _r4 { return sprintf('%.4f', shift) + 0 }

# the page of the JMA climate archive of an AMeDAS station: ('s' or 'a', prec_no, block_no)
sub _jma_block {
    my ($self, $id) = @_;
    my $s = $self->get_json($JMA_TABLE, 'jma_stations')->{$id} or die "Unknown AMeDAS station $id.\n";
    my $prec = substr($id, 0, 2);
    my $html = _utf8($self->get_raw("$JMA_ETRN/select/prefecture.php?prec_no=$prec", 'jma_stations'));
    my ($lat, $lon) = ($s->{lat}[0] + $s->{lat}[1] / 60, $s->{lon}[0] + $s->{lon}[1] / 60);
    my ($best, $best_d);
    while ($html =~ /viewPoint\('([as])','(\d+)','([^']*)','[^']*','(\d+)','([\d.]+)','(\d+)','([\d.]+)'(?:,'[^']*'){7},'(\d+)'/g) {
        my ($kind, $block, $name, $la, $lo, $ended) = ($1, $2, $3, $4 + $5 / 60, $6 + $7 / 60, $8);
        next if $ended ne '9999';    # closed station
        my $d = $self->distance_km($lat, $lon, $la, $lo) - ($name eq $s->{kjName} ? 5 : 0);
        ($best, $best_d) = ([$kind, $prec, $block], $d) if !defined $best_d || $d < $best_d;
    }
    die "The JMA archive page of station $id was not found.\n" if !$best || $best_d > 2;
    return @$best;
}

sub _jma_value {
    my $v = shift // '';
    $v =~ s/\s|&nbsp;//g;
    return 0 if $v eq '--';           # no phenomenon (no rain)
    return if $v =~ /[\]#×\/]/;        # incomplete, doubtful or missing
    $v =~ s/\)$//;                     # quasi-complete values are kept
    return _num($v);
}

sub _jma_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my ($kind, $prec, $block) = $self->_jma_block($id);
    # columns of the daily tables: main stations (s) and AMeDAS stations (a)
    my %col = $kind eq 's'
        ? (rain => 3, tmean => 6, tmax => 7, tmin => 8, rh => 9, wind => 11, gust => 14, sunshine => 16)
        : (rain => 1, tmean => 4, tmax => 5, tmin => 6, rh => 7, wind => 9, gust => 12, sunshine => 15);
    my %by;
    my ($y, $m) = split /-/, $start;
    my ($y2, $m2) = split /-/, $end;
    my $this_month = substr(_iso_days_ago(0), 0, 7);
    while ($y * 12 + $m <= $y2 * 12 + $m2) {
        my $month = sprintf('%04d-%02d', $y, $m);
        my $html = _utf8($self->get_raw("$JMA_ETRN/view/daily_${kind}1.php?prec_no=$prec&block_no=$block&year=$y&month=" . ($m + 0) . '&day=&view=',
            $month ge substr(_iso_days_ago(3), 0, 7) || $month eq $this_month ? 'archive_recent' : 'archive'));
        while ($html =~ m{<tr class="mtx"[^>]*>(.*?)</tr>}gs) {
            my @c = map { s/<[^>]+>//gr } ($1 =~ m{<td[^>]*>(.*?)</td>}gs);
            next if @c < 10 || $c[0] !~ /^\s*(\d+)\s*$/;
            my $date = sprintf('%s-%02d', $month, $1);
            next if $date lt $start || $date gt $end;
            my %v = map { $_ => scalar(_jma_value($c[$col{$_}])) } keys %col;
            next if !grep { defined } values %v;
            $by{$date} = $self->_daily_values($lat, $elev, $date, %v);
        }
        $m++;
        if ($m > 12) { $m = 1; $y++; }
    }
    my $days = [ map { $by{$_} } sort keys %by ];
    my $rain_only = !grep { defined $_->{tmax} } @$days;
    return {
        source => "JMA AMeDAS station $id (Japan Meteorological Agency, climate archive)",
        note => 'Daily values of the JMA climate archive (Japanese local days, midnight to midnight). '
            . ($rain_only ? 'The station does not measure temperature.' : 'ET0: FAO-56 Penman-Monteith with the radiation estimated from the hours of sunshine.')
            . ' The latest day is usually yesterday.',
        rain_reported => 1, ($rain_only ? (rain_only => 1) : ()), days => $days,
    };
}

# ------------------------------------------------------------------ helpers of the daily networks

# the stations of a list that are within range, nearest first
sub _in_range {
    my ($self, $list, $lat, $lon, $range_km, $limit) = @_;
    my @in;
    foreach my $st (@$list) {
        next if !defined $st->{lat} || !defined $st->{lon};
        my %copy = %$st;
        next if $self->_place(\%copy, $lat, $lon) > $range_km;
        push @in, \%copy;
    }
    return _nearest(\@in, $limit);
}

sub _f_to_c { my $f = shift; return defined $f ? ($f - 32) * 5 / 9 : undef }
sub _in_to_mm { my $v = shift; return defined $v ? $v * 25.4 : undef }
sub _mph_to_ms { my $v = shift; return defined $v ? $v * 0.44704 : undef }
sub _mean2 { my ($a, $b) = @_; return (defined $a && defined $b) ? ($a + $b) / 2 : undef }

# split one CSV line (double quotes, separator , or ;)
sub _csv_split {
    my ($line, $sep) = @_;
    $sep //= ',';
    my @f;
    while ($line =~ /\G(?:"((?:[^"]|"")*)"|([^\Q$sep\E"]*))(?:\Q$sep\E|$)/g) {
        push @f, defined $1 ? $1 =~ s/""/"/gr : $2;
        last if pos($line) >= length($line);
    }
    return @f;
}

sub _title_words { my $s = shift // ''; $s =~ s/\s+$//; return join ' ', map { ucfirst lc } split /\s+/, $s }

sub _daily_result {
    my ($self, %a) = @_;
    my @days = sort { $a->{date} cmp $b->{date} } @{$a{days}};
    my $has_temp = grep { defined $_->{tmax} } @days;
    my $has_rain = grep { defined $_->{rain} } @days;
    return {
        source => $a{source}, note => $a{note} . ($has_temp ? '' : ' No temperature was measured for these dates.'),
        rain_reported => $has_rain || !$has_temp ? 1 : 0, (!$has_temp && $has_rain ? (rain_only => 1) : ()), days => \@days,
    };
}

# ------------------------------------------------------------------ ECCC (Canada)

sub _eccc_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 41.6, -141.1, 83.2, -52.6);
    my ($s, $w, $n, $e) = $self->bbox($lat, $lon, $range_km);
    my $d = $self->get_json(sprintf("$ECCC/climate-stations/items?f=json&limit=5000&bbox=%.3f,%.3f,%.3f,%.3f", $w, $s, $e, $n), 'station_list');
    my $recent = _iso_days_ago(400);
    my @list;
    foreach my $f (@{ref($d) eq 'HASH' ? $d->{features} || [] : []}) {
        my $p = $f->{properties} || {};
        my $c = ($f->{geometry} || {})->{coordinates} || [];
        next if ($p->{DLY_LAST_DATE} // '') lt $recent || !defined $c->[1];
        push @list, { network => 'eccc', id => $p->{CLIMATE_IDENTIFIER}, name => _title_words($p->{STATION_NAME}),
            lat => $c->[1] + 0, lon => $c->[0] + 0, elev => _num($p->{ELEVATION}), country => 'CA', state => $p->{PROV_STATE_TERR_CODE},
            ready => 1, rain_amounts => 1, since => substr($p->{DLY_FIRST_DATE} // '', 0, 4),
            measures => ['temperature', 'rain', 'humidity'] };
    }
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _eccc_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my $recent = $end ge _iso_days_ago(3);
    my $d = $self->get_json("$ECCC/climate-daily/items?f=json&CLIMATE_IDENTIFIER=" . _uri($id) . "&datetime=$start/$end&sortby=LOCAL_DATE&limit=10000",
        $recent ? 'archive_recent' : 'archive');
    my @days;
    foreach my $f (@{ref($d) eq 'HASH' ? $d->{features} || [] : []}) {
        my $p = $f->{properties} || {};
        my $date = substr($p->{LOCAL_DATE} // '', 0, 10);
        next if $date !~ /^\d{4}-\d\d-\d\d$/;
        # M = missing, E = estimated: only measured values are kept (T = trace of rain, kept as 0)
        my $v = sub { my $k = shift; my $fl = $p->{"${k}_FLAG"} // ''; return $fl =~ /^[ME]$/ ? undef : _num($p->{$k}) };
        my %v = (tmax => $v->('MAX_TEMPERATURE'), tmin => $v->('MIN_TEMPERATURE'), tmean => $v->('MEAN_TEMPERATURE'),
            rain => $v->('TOTAL_PRECIPITATION'), rh => _mean2($v->('MIN_REL_HUMIDITY'), $v->('MAX_REL_HUMIDITY')));
        my $gust = $v->('SPEED_MAX_GUST');
        $v{gust} = $gust / 3.6 if defined $gust;
        next if !grep { defined } values %v;
        push @days, $self->_daily_values($lat, $elev, $date, %v);
    }
    return $self->_daily_result(days => \@days,
        source => "Environment and Climate Change Canada climate station $id (Data Source: Environment and Climate Change Canada)",
        note => 'Daily values of the ECCC climate archive (the climatological day; precipitation includes snow as water). Estimated and missing values are left out. ET0: Hargreaves-Samani.');
}

# ------------------------------------------------------------------ USDA NRCS SCAN (USA)

sub _scan_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 17, -180, 72, -64);
    my $d = $self->get_json("$AWDB/stations?stationTriplets=*:*:SCAN&activeOnly=true", 'scan_stations');
    my @list = map { {
        network => 'scan', id => "$_->{stationId}_$_->{stateCode}", name => $_->{name} . ($_->{countyName} ? " ($_->{countyName})" : ''),
        lat => $_->{latitude}, lon => $_->{longitude}, elev => defined $_->{elevation} ? _r1($_->{elevation} * 0.3048) : undef,
        country => 'US', state => $_->{stateCode}, ready => 1, rain_amounts => 1, since => substr($_->{beginDate} // '', 0, 4),
        measures => ['temperature', 'rain', 'wind'],
    } } grep { ($_->{networkCode} // '') eq 'SCAN' } @{ref($d) eq 'ARRAY' ? $d : []};
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _scan_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my ($num, $state) = $id =~ /^(\d+)_([A-Z]{2})$/ or die "Unknown SCAN station $id.\n";
    my $recent = $end ge _iso_days_ago(3);
    my $d = $self->get_json("$AWDB/data?stationTriplets=$num:$state:SCAN&elements=TMAX,TMIN,TAVG,PRCP,WSPDV&duration=DAILY&beginDate=$start&endDate=$end",
        $recent ? 'archive_recent' : 'archive');
    my %by;
    foreach my $el (@{ref($d) eq 'ARRAY' && $d->[0] ? $d->[0]{data} || [] : []}) {
        my $code = ($el->{stationElement} || {})->{elementCode} // '';
        foreach my $v (@{$el->{values} || []}) {
            next if !defined $v->{value} || ($v->{qcFlag} // '') =~ /^[SR]$/;    # suspect / rejected
            $by{$v->{date}}{$code} = $v->{value};
        }
    }
    my @days = map {
        my $x = $by{$_};
        $self->_daily_values($lat, $elev, $_, tmax => _f_to_c($x->{TMAX}), tmin => _f_to_c($x->{TMIN}), tmean => _f_to_c($x->{TAVG}),
            rain => _in_to_mm($x->{PRCP}), wind => _mph_to_ms($x->{WSPDV}), wind_height => 3)
    } grep { $_ ge $start && $_ le $end } keys %by;
    return $self->_daily_result(days => \@days, source => "USDA NRCS SCAN station $num ($state), Soil Climate Analysis Network",
        note => 'Daily values of the SCAN soil-climate station (midnight to midnight, local standard time). ET0: Hargreaves-Samani.');
}

# ------------------------------------------------------------------ ISU Soil Moisture network (Iowa, through IEM)

sub _isusm_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 40.3, -96.7, 43.6, -90.1);
    my $d = $self->get_json("$IEM_SITE/api/1/network/ISUSM.geojson", 'iem_stations');
    my @list;
    foreach my $f (@{ref($d) eq 'HASH' ? $d->{features} || [] : []}) {
        my $p = $f->{properties} || {};
        my $c = ($f->{geometry} || {})->{coordinates} || [];
        next if !$p->{online} || !$p->{id};
        push @list, { network => 'isusm', id => $p->{id}, name => $p->{name}, lat => $c->[1], lon => $c->[0], elev => _r1($p->{elevation}),
            country => 'US', state => 'IA', ready => 1, rain_amounts => 1, since => substr($p->{archive_begin} // '', 0, 4),
            measures => ['temperature', 'rain', 'humidity', 'wind', 'radiation'] };
    }
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _isusm_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my $recent = $end ge _iso_days_ago(3);
    my $csv = $self->get_raw("$IEM_SITE/cgi-bin/request/isusm.py?station=" . _uri($id) . "&mode=daily&sts=${start}T00:00Z&ets=" . _shift_date($end, 1)
        . 'T00:00Z&format=comma&vars=high&vars=low&vars=rh&vars=precip&vars=speed&vars=solar_mj&missing=M', $recent ? 'archive_recent' : 'archive');
    my @lines = split /\r?\n/, $csv;
    my @cols = split /,/, (shift(@lines) // '');
    die "The ISU Soil Moisture network did not return data for $id.\n" if ($cols[0] // '') ne 'station';
    my @days;
    foreach my $l (@lines) {
        my %r;
        @r{@cols} = split /,/, $l;
        next if ($r{valid} // '') !~ /^\d{4}-\d\d-\d\d$/ || $r{valid} lt $start || $r{valid} gt $end;
        push @days, $self->_daily_values($lat, $elev, $r{valid}, tmax => _f_to_c(_num($r{high})), tmin => _f_to_c(_num($r{low})),
            rh => _num($r{rh}), rain => _in_to_mm(_num($r{precip})), wind => _mph_to_ms(_num($r{speed})), radiation => _num($r{solar_mj}), wind_height => 3);
    }
    return $self->_daily_result(days => \@days, source => "ISU Soil Moisture network station $id (Iowa State University, Iowa Environmental Mesonet)",
        note => 'Daily values of the ISU agricultural station (local day). ET0: FAO-56 Penman-Monteith with the measured radiation, humidity and wind.');
}

# ------------------------------------------------------------------ CoAgMet (Colorado)

sub _coagmet_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 36.9, -109.1, 41.1, -102.0);
    my @lines = split /\r?\n/, $self->get_raw("$COAGMET/metadata.csv?header=yes", 'iem_stations');
    my @cols = _csv_split(shift(@lines) // '');
    my @list;
    foreach my $l (@lines) {
        my %r;
        @r{@cols} = _csv_split($l);
        next if ($r{Active} // '') ne 'active';
        push @list, { network => 'coagmet', id => uc($r{Station} // ''), name => $r{Name} . ($r{Location} ? " ($r{Location})" : ''),
            lat => _num($r{'Latitude (degN)'}), lon => _num($r{'Longitude (degE)'}), elev => defined _num($r{'Elevation (ft)'}) ? _r1($r{'Elevation (ft)'} * 0.3048) : undef,
            country => 'US', state => 'CO', ready => 1, rain_amounts => 1, since => substr($r{'First Observation'} // '', -4),
            anemometer => _num($r{'Anemometer Height (m)'}), measures => ['temperature', 'rain', 'humidity', 'wind', 'radiation'] };
    }
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _coagmet_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my $recent = $end ge _iso_days_ago(3);
    my @lines = split /\r?\n/, $self->get_raw("$COAGMET/daily/" . lc(_uri($id)) . ".csv?from=$start&to=$end&units=m&header=yes&dateFmt=iso",
        $recent ? 'archive_recent' : 'archive');
    my @cols = _csv_split(shift(@lines) // '');
    shift @lines;    # units
    die "CoAgMet did not return data for $id.\n" if ($cols[0] // '') ne 'Station';
    my @days;
    foreach my $l (@lines) {
        my %r;
        @r{@cols} = map { (defined $_ && $_ eq '-999') ? undef : $_ } _csv_split($l);
        next if ($r{Date} // '') !~ /^\d{4}-\d\d-\d\d$/;
        my ($rhx, $rhn) = (_num($r{'RH Max'}), _num($r{'RH Min'}));
        my $run = _num($r{'Wind Run'});
        my $rad = _num($r{'Solar Rad'});
        my %v = (tmax => _num($r{'Max Temp'}), tmin => _num($r{'Min Temp'}), tmean => _num($r{'Avg Temp'}),
            rh => (defined $rhx && defined $rhn) ? 50 * ($rhx + $rhn) : undef, rain => _num($r{'Liquid Precip'}),
            wind => defined $run ? $run * 1000 / 86400 : undef, gust => _num($r{'Gust Speed'}), radiation => defined $rad ? $rad * 0.0864 : undef);
        next if !grep { defined } values %v;
        push @days, $self->_daily_values($lat, $elev, $r{Date}, %v, wind_height => 2);
    }
    return $self->_daily_result(days => \@days, source => 'CoAgMet station ' . uc($id) . ' (Colorado Agricultural Meteorological Network, Colorado State University)',
        note => 'Daily values of the agricultural station (local standard time). ET0: FAO-56 Penman-Monteith with the measured radiation, humidity and wind.');
}

# ------------------------------------------------------------------ AZMet (Arizona)

sub _azmet_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 31.3, -114.9, 37.0, -109.0);
    my @lines = split /\r?\n/, $self->get_raw($AZMET_STATIONS, 'jma_stations');
    my @cols = _csv_split(shift(@lines) // '');
    my @list;
    foreach my $l (@lines) {
        my %r;
        @r{@cols} = _csv_split($l);
        next if ($r{status} // '') ne 'active' || !$r{id} || ($r{name} // '') =~ /^test$/i;
        push @list, { network => 'azmet', id => uc($r{id}), name => "$r{name} ($r{county} County)", lat => _num($r{latitude}), lon => _num($r{longitude}),
            elev => _num($r{elev_m}), country => 'US', state => 'AZ', ready => 1, rain_amounts => 1, since => substr($r{start_date} // '', 0, 4),
            measures => ['temperature', 'rain', 'humidity', 'wind', 'radiation'] };
    }
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _azmet_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my $n = int((_epoch_of($end) - _epoch_of($start)) / 86400) + 1;
    my $recent = $end ge _iso_days_ago(3);
    my $d = $self->get_json("$AZMET/observations/daily/" . lc(_uri($id)) . "/${start}T00:00/P${n}D", $recent ? 'archive_recent' : 'archive');
    my @days;
    foreach my $r (@{ref($d) eq 'HASH' ? $d->{data} || [] : []}) {
        my $date = $r->{datetime} // '';
        next if $date !~ /^\d{4}-\d\d-\d\d$/ || $date lt $start || $date gt $end;
        push @days, $self->_daily_values($lat, $elev, $date, tmax => _num($r->{temp_air_maxC}), tmin => _num($r->{temp_air_minC}),
            tmean => _num($r->{temp_air_meanC}), rh => _num($r->{relative_humidity_mean}), rain => _num($r->{precip_total_mm}),
            wind => _num($r->{wind_spd_mean_mps}), gust => _num($r->{wind_spd_max_mps}), radiation => _num($r->{sol_rad_total}), wind_height => 3);
    }
    return $self->_daily_result(days => \@days, source => 'AZMet station ' . uc($id) . ' (Arizona Meteorological Network, University of Arizona)',
        note => 'Daily values of the agricultural station (local day). ET0: FAO-56 Penman-Monteith with the measured radiation, humidity and wind.');
}

# ------------------------------------------------------------------ SMN / CONAGUA (Mexico)

sub _conagua_list {
    my $self = shift;
    my $d = $self->get_json($CONAGUA_STATIONS, 'conagua_stations');
    my $recent = _iso_days_ago(3 * 365);
    my %list;
    foreach my $f (@{ref($d) eq 'HASH' ? $d->{features} || [] : []}) {
        my $p = $f->{properties} || {};
        my $c = ($f->{geometry} || {})->{coordinates} || [];
        next if !$p->{clave} || ($p->{mas_reciente} // '') lt $recent || !$p->{diarios};
        $list{$p->{clave}} = { network => 'conagua', id => $p->{clave}, name => _title_words($p->{nombre}) . ' (' . _title_words($p->{municipio}) . ')',
            lat => $c->[1], lon => $c->[0], elev => _num($p->{altitud}), country => 'MX', state => _title_words($p->{estado}),
            ready => 1, rain_amounts => 1, since => substr($p->{inicio} // '', 0, 4), last => $p->{mas_reciente}, file => $p->{diarios},
            measures => ['temperature', 'rain'] };
    }
    return \%list;
}

sub _conagua_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 14.5, -118.5, 32.8, -86.7);
    my $list = $self->_in_range([ values %{$self->_conagua_list} ], $lat, $lon, $range_km, $limit);
    delete $_->{file} for @$list;
    return $list;
}

sub _conagua_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my $st = $self->_conagua_list->{$id} or die "Unknown SMN station $id.\n";
    die "Unexpected address of the SMN file of $id.\n" if $st->{file} !~ m{^https://smn\.conagua\.gob\.mx/};
    my $txt = $self->get_raw($st->{file}, 'archive');
    my @days;
    my $in = 0;
    foreach my $l (split /\r?\n/, $txt) {
        if (!$in) { $in = 1 if $l =~ /^FECHA\s/; next; }
        my ($date, $rain, $evap, $tmax, $tmin) = split /\t+/, $l;
        next if ($date // '') !~ /^\d{4}-\d\d-\d\d$/ || $date lt $start || $date gt $end;
        my %v = (rain => _num($rain), tmax => _num($tmax), tmin => _num($tmin));    # NULO = missing
        next if !grep { defined } values %v;
        push @days, $self->_daily_values($lat, $elev, $date, %v);
    }
    return $self->_daily_result(days => \@days, source => "SMN climatological station $id (Servicio Meteorologico Nacional / CONAGUA, Mexico)",
        note => 'Daily values of the national climatological database (morning reading). The latest values often arrive months late: the station file says up to '
            . ($st->{last} // '?') . '. ET0: Hargreaves-Samani.');
}

# ------------------------------------------------------------------ INTA SIGA (Argentina)

sub _inta_list {
    my $self = shift;
    my $d = $self->get_json("$SIGA?param_type=estacion&param_value=", 'conagua_stations');
    my $recent = _iso_days_ago(3 * 365);
    my @list;
    foreach my $s (@{ref($d) eq 'ARRAY' ? $d : []}) {
        next if !$s->{visible} || substr($s->{maximoDiario} // '', 0, 10) lt $recent;
        push @list, { network => 'inta', id => $s->{id}, name => $s->{nombre}, lat => $s->{latitud}, lon => $s->{longitud}, elev => $s->{altura},
            country => 'AR', state => $s->{provincia}, ready => 1, rain_amounts => 1, since => substr($s->{minimoDiario} // '', 0, 4),
            measures => ($s->{idTipo} // 0) == 1 ? ['temperature', 'rain', 'humidity', 'wind', 'radiation'] : ['temperature', 'rain', 'humidity'] };
    }
    return \@list;
}

sub _inta_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, -55.1, -73.6, -21.7, -53.6);
    return $self->_in_range($self->_inta_list, $lat, $lon, $range_km, $limit);
}

sub _inta_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    die "Unknown INTA station $id.\n" if $id !~ /^\d+$/;
    my $dmy = sub { my ($y, $m, $d) = split /-/, shift; return ($d + 0) . '-' . ($m + 0) . "-$y" };
    my $recent = $end ge _iso_days_ago(3);
    my $d = $self->get_json("$SIGA?param_type=diario&param_value=$id/" . $dmy->($start) . '/' . $dmy->($end), $recent ? 'archive_recent' : 'archive');
    my @days;
    foreach my $r (@{ref($d) eq 'ARRAY' ? $d : []}) {
        my $date = substr($r->{fechaHora} // '', 0, 10);
        next if $date !~ /^\d{4}-\d\d-\d\d$/ || $date lt $start || $date gt $end;
        push @days, $self->_daily_values($lat, $elev, $date, tmax => _num($r->{tempAbrigo150Max}), tmin => _num($r->{tempAbrigo150Min}),
            tmean => _num($r->{tempAbrigo150}), rh => _num($r->{HMedia}) // _num($r->{HMedia81420}), rain => _num($r->{precDiaPlub}) // _num($r->{precDiaCrono}),
            wind => _num($r->{velViento200Media}), radiation => _num($r->{radiacionGlobal}), sunshine => _num($r->{heliofaniaEfectiva}), wind_height => 2);
    }
    return $self->_daily_result(days => \@days, source => "INTA station $id (SIGA, Instituto Nacional de Tecnologia Agropecuaria, Argentina)",
        note => 'Daily values of the INTA agrometeorological station. ET0: FAO-56 Penman-Monteith with the radiation, humidity and wind at 2 m published by INTA.');
}

# ------------------------------------------------------------------ SILO (Australia, Queensland Government)

sub _silo_list {
    my $self = shift;
    # every station of SILO (station search around Alice Springs, 10 000 km) and the station list of the BoM
    $self->prefetch([ "$SILO?format=near&station=15540&radius=10000", 'jma_stations' ], [ $BOM_STATIONS, 'jma_stations' ]);
    my @list;
    foreach my $l (split /\r?\n/, $self->get_raw("$SILO?format=near&station=15540&radius=10000", 'jma_stations')) {
        my @f = map { s/^\s+|\s+$//gr } split /\|/, $l;
        next if @f < 6 || $f[0] !~ /^\d+$/;
        push @list, { network => 'silo', id => $f[0] + 0, name => _title_words($f[1]), lat => _num($f[2]), lon => _num($f[3]),
            state => $f[4], elev => _num($f[5]), country => 'AU', ready => $self->api_key('silo') ? 1 : 0, rain_amounts => 1,
            measures => ['temperature', 'rain'] };
    }
    # SILO fills the days of closed stations with interpolated values: keep the stations open in the BoM list
    my $open = eval {
        my $zip = $self->get_raw($BOM_STATIONS, 'jma_stations');
        my $u = IO::Uncompress::Unzip->new(\$zip) or die;
        local $/;
        my $txt = <$u>;
        my %o;
        while ($txt =~ /^\s*(\d{6})\s+\S+\s+.*?\s+\d{4}\s+(\.\.|\d{4})\s+-?\d/mg) { $o{$1 + 0} = 1 if $2 eq '..'; }
        \%o;
    };
    @list = grep { $open->{$_->{id}} } @list if $open && %$open;
    return \@list;
}

sub _silo_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, -44, 112, -9, 154);
    return $self->_in_range($self->_silo_list, $lat, $lon, $range_km, $limit);
}

sub _silo_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    die "Unknown SILO station $id.\n" if $id !~ /^\d+$/;
    my $recent = $end ge _iso_days_ago(3);
    my ($s, $e) = map { s/-//gr } $start, $end;
    my $d = $self->with_keys('silo', sub {
        my $user = shift;
        my $raw = $self->get_raw("$SILO?station=$id&start=$s&finish=$e&format=json&comment=RXN&username=" . _uri($user), $recent ? 'archive_recent' : 'archive');
        die "SILO refused the request: " . substr($raw, 0, 200) . "\n" if $raw !~ /^\s*\{/;
        return decode_json($raw);
    });
    my @days;
    foreach my $day (@{$d->{data} || []}) {
        # source code 0 = observed at the station; interpolated, deaccumulated or derived values are dropped
        my %v = map { $_->{variable_code} => ($_->{source} // -1) == 0 ? _num($_->{value}) : undef } @{$day->{variables} || []};
        my %x = (rain => $v{daily_rain}, tmax => $v{max_temp}, tmin => $v{min_temp});
        next if !grep { defined } values %x;
        push @days, $self->_daily_values($lat, $elev, $day->{date}, %x);
    }
    return $self->_daily_result(days => \@days, source => "Bureau of Meteorology station $id (SILO Patched Point dataset, Queensland Government)",
        note => 'Only the values SILO marks as observed at the station (source code 0) are used: interpolated, deaccumulated and derived values are left out. Rain: 24 hours to 9 am. ET0: Hargreaves-Samani.');
}

# ------------------------------------------------------------------ IMS climate archive (Israel, data.gov.il)

sub _ims_query {
    my ($self, $resource, $filters, $kind, $limit) = @_;
    my $url = "$DATAGOVIL?resource_id=$resource&limit=" . ($limit || 32000) . ($filters ? '&filters=' . _uri(encode_json($filters)) : '');
    my $d = $self->get_json($url, $kind);
    die "The Israeli open data portal did not answer the query.\n" if ref($d) ne 'HASH' || !$d->{success};
    return $d->{result}{records} || [];
}

sub _ims_list {
    my $self = shift;
    my @list;
    foreach my $s (@{$self->_ims_query($IMS_RES{stations}, undef, 'jma_stations', 5000)}) {
        next if ($s->{date_close} // '') ne '' || !($s->{stn_type} == 1 || $s->{stn_type} == 2);
        next if ($s->{date_web_last} // '') lt substr(_iso_days_ago(730), 0, 7);
        my $rain = $s->{stn_type} == 2;
        push @list, { network => 'ims', id => $s->{stn_num}, name => _title_words($s->{stn_name}) . ($rain ? ' (rain gauge)' : ''),
            lat => _num($s->{stn_lat}), lon => _num($s->{stn_long}), elev => _num($s->{stn_hgt}), country => 'IL', ready => 1,
            rain_amounts => $rain ? 1 : 0, ($rain ? (rain_only => 1) : ()), since => substr($s->{date_web_frst} // '', 0, 4),
            first => $s->{date_web_frst}, last => $s->{date_web_last}, kind => $s->{stn_type},
            measures => $rain ? ['rain'] : ['temperature'] };
    }
    return \@list;
}

sub _ims_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 29.4, 34.2, 33.4, 35.9);
    my $list = $self->_in_range($self->_ims_list, $lat, $lon, $range_km, $limit);
    delete @$_{qw(first kind)} for @$list;
    return $list;
}

sub _ims_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my ($st) = grep { $_->{id} eq $id } @{$self->_ims_list} or die "Unknown IMS station $id.\n";
    my @months;
    my ($y, $m) = split /-/, $start;
    my ($y2, $m2) = split /-/, $end;
    while ($y * 12 + $m <= $y2 * 12 + $m2) { push @months, sprintf('%02d/%04d', $m, $y); $m++; if ($m > 12) { $m = 1; $y++; } }
    my $kind = $end ge _iso_days_ago(70) ? 'archive_recent' : 'archive';
    my @days;
    if ($st->{kind} == 2) {
        my %rain;
        foreach my $r (@{$self->_ims_query($IMS_RES{rain}, { stn_num => $id + 0, monthyear => \@months }, $kind)}) {
            my $code = $r->{rain_code} // 0;
            $rain{ substr($r->{time_obs}, 0, 10) } = ($code == 0 || $code == 9) ? _num($r->{rain_06_next}) // 0 : undef;
        }
        # the archive keeps only the days with rain: the other days of the published months are dry
        my ($fy, $fm) = split /-/, ($st->{first} // '1900-01');
        my ($ly, $lm) = split /-/, ($st->{last} // '1900-01');
        my $last_day = _shift_date(sprintf('%04d-%02d-01', $lm == 12 ? $ly + 1 : $ly, $lm == 12 ? 1 : $lm + 1), -1);
        for (my $date = $start; $date le $end; $date = _shift_date($date, 1)) {
            next if $date lt sprintf('%04d-%02d-01', $fy, $fm) || $date gt $last_day;
            next if exists $rain{$date} && !defined $rain{$date};
            push @days, $self->_daily_values($lat, $elev, $date, rain => $rain{$date} // 0);
        }
    }
    else {
        foreach my $r (@{$self->_ims_query($IMS_RES{daily}, { stn_num => $id + 0, monthyear => \@months }, $kind)}) {
            my $date = substr($r->{time_obs} // '', 0, 10);
            next if $date lt $start || $date gt $end;
            my %v = (tmax => _num($r->{tmp_air_max}), tmin => _num($r->{tmp_air_min}));
            next if !grep { defined } values %v;
            push @days, $self->_daily_values($lat, $elev, $date, %v);
        }
    }
    my $res = $self->_daily_result(days => \@days, source => "Israel Meteorological Service station $id (climate archive, data.gov.il)",
        note => ($st->{kind} == 2 ? 'Daily rain of the gauge (06 to 06 UTC). The archive lists only rainy days: the other days of the published months count as dry.'
            : 'Daily max/min temperature of the climate station (the rain of IMS is measured by separate rain gauges: choose one for rain).')
            . ' The archive is published after the monthly quality control: the latest month is ' . ($st->{last} // '?') . '. ET0: Hargreaves-Samani.');
    $res->{rain_reported} = 0 if $st->{kind} == 1;
    return $res;
}

# ------------------------------------------------------------------ Hilltop servers of the regional councils (New Zealand)

sub _hilltop_servers {
    my $self = shift;
    my $list = $self->hilltop_servers // join(',', @HILLTOP_DEFAULT);
    return grep { m{^https?://[\w.-]+(:\d+)?/[\w./-]+\.hts$} } split /[\s,;]+/, $list;
}

# sites of one server that measure rain or air temperature (with their position)
sub _hilltop_sites {
    my ($self, $server) = @_;
    my %site;
    foreach my $m ('Rainfall', 'Air Temperature') {
        my $xml = eval { _utf8($self->get_raw(_hilltop_list_url($server, $m), 'iem_stations')) } // '';
        my ($agency) = $xml =~ m{<Agency>([^<]*)</Agency>};
        while ($xml =~ m{<Site Name="([^"]+)">\s*<Latitude>(-?[\d.]+)</Latitude>\s*<Longitude>(-?[\d.]+)</Longitude>}g) {
            my ($name, $la, $lo) = ($1, $2, $3);
            $name =~ s/&amp;/&/g; $name =~ s/&apos;/'/g; $name =~ s/&quot;/"/g;
            my $s = $site{$name} ||= { name => $name, lat => $la + 0, lon => $lo + 0, agency => $agency };
            $s->{$m eq 'Rainfall' ? 'rain' : 'temp'} = 1;
        }
    }
    return \%site;
}

sub _hilltop_list_url { my ($server, $m) = @_; return "$server?Service=Hilltop&Request=SiteList&Location=LatLong&Measurement=" . _uri($m) }

sub _hilltop_id { my ($server, $name) = @_; return 'H' . substr(md5_hex("$server|$name"), 0, 12) }

sub _hilltop_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, -47.5, 166, -34, 179);
    my @list;
    $self->prefetch(map { my $sv = $_; map { [ _hilltop_list_url($sv, $_), 'iem_stations' ] } 'Rainfall', 'Air Temperature' } $self->_hilltop_servers);
    foreach my $server ($self->_hilltop_servers) {
        foreach my $s (values %{$self->_hilltop_sites($server)}) {
            push @list, { network => 'hilltop', id => _hilltop_id($server, $s->{name}), name => $s->{name} . ($s->{agency} ? " ($s->{agency})" : ''),
                lat => $s->{lat}, lon => $s->{lon}, country => 'NZ', ready => 1, rain_amounts => $s->{rain} ? 1 : 0,
                ($s->{temp} ? () : (rain_only => 1)), measures => [ ($s->{temp} ? 'temperature' : ()), ($s->{rain} ? 'rain' : ()) ] };
        }
    }
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _hilltop_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    my ($server, $site);
    foreach my $sv ($self->_hilltop_servers) {
        foreach my $s (values %{$self->_hilltop_sites($sv)}) {
            ($server, $site) = ($sv, $s) if uc(_hilltop_id($sv, $s->{name})) eq uc($id);
        }
    }
    die "Unknown council station $id.\n" if !$site;
    my $recent = $end ge _iso_days_ago(3);
    # daily values are stamped at the END of the day: ask one more day and move the stamps back
    my $url = sub {
        my ($measurement, $method) = @_;
        return "$server?Service=Hilltop&Request=GetData&Site=" . _uri($site->{name}) . '&Measurement=' . _uri($measurement)
            . "&From=$start&To=" . _shift_date($end, 1) . "&Interval=1%20day&Method=$method";
    };
    my @want = (($site->{rain} ? ['Rainfall', 'Total'] : ()),
        ($site->{temp} ? (['Air Temperature', 'Extrema'], ['Relative Humidity', 'Extrema'], ['Wind Speed', 'Extrema'], ['Solar Radiation', 'Average']) : ()));
    $self->prefetch(map { [ $url->(@$_), $recent ? 'archive_recent' : 'archive' ] } @want);
    my $get = sub {
        my ($measurement, $method) = @_;
        my $xml = eval { _utf8($self->get_raw($url->($measurement, $method), $recent ? 'archive_recent' : 'archive')) } // '';
        my %v;
        while ($xml =~ m{<E><T>(\d{4}-\d\d-\d\d)T00:00:00</T>(.*?)</E>}g) {
            my ($t, $items) = ($1, $2);
            my %i = $items =~ m{<I(\d)>([^<]*)</I\1>}g;
            $v{ _shift_date($t, -1) } = \%i;
        }
        return \%v;
    };
    my $rain = $site->{rain} ? $get->('Rainfall', 'Total') : {};
    my ($temp, $rh, $wind, $rad) = ({}, {}, {}, {});
    if ($site->{temp}) {
        $temp = $get->('Air Temperature', 'Extrema');
        $rh = $get->('Relative Humidity', 'Extrema');
        $wind = $get->('Wind Speed', 'Extrema');
        $rad = $get->('Solar Radiation', 'Average');
    }
    my @days;
    for (my $date = $start; $date le $end; $date = _shift_date($date, 1)) {
        my ($t, $h, $w, $r) = map { $_->{$date} || {} } $temp, $rh, $wind, $rad;
        my %v = (rain => _num(($rain->{$date} || {})->{1}), tmin => _num($t->{1}), tmean => _num($t->{2}), tmax => _num($t->{3}),
            rh => _num($h->{2}), wind => _num($w->{2}), radiation => defined _num($r->{1}) ? $r->{1} * 0.0864 : undef);
        next if !grep { defined } values %v;
        push @days, $self->_daily_values($lat, $elev, $date, %v);
    }
    return $self->_daily_result(days => \@days, source => "Council station $site->{name} ($site->{agency}, Hilltop server $server)",
        note => 'Daily totals and extremes computed by the regional council server from the station records (New Zealand local days).'
            . ' ET0: Penman-Monteith where the station measures radiation, humidity and wind, otherwise Hargreaves-Samani.');
}

# ------------------------------------------------------------------ AEMET OpenData (Spain, free key)

# AEMET answers in two steps: the request gives the address of the data
sub _aemet_get {
    my ($self, $path, $kind) = @_;
    my $name = "aemet:$path";
    my $cached = $self->_cache_get($kind, $name);
    return decode_json($cached) if defined $cached && $cached ne '';
    my $data = $self->with_keys('aemet', sub {
        my $key = shift;
        my $r = $self->ua->get("$AEMET$path", ":api_key" => $key, Accept => 'application/json');
        my $head = eval { decode_json($r->decoded_content(charset => 'none') // '') } || {};
        my $estado = $head->{estado} // $r->code;
        return [] if $estado == 404;    # no data for these dates
        die "AEMET refused the request ($estado " . ($head->{descripcion} // $r->status_line) . ")\n" if $estado != 200 || !$head->{datos};
        my $d = $self->ua->get($head->{datos}, ":api_key" => $key);
        die "AEMET did not send the data (" . $d->status_line . ")\n" if !$d->is_success;
        my $bytes = $d->content;
        my $txt = eval { decode('UTF-8', $bytes, Encode::FB_CROAK) } // decode('iso-8859-15', $bytes);
        return decode_json(encode('UTF-8', $txt));
    });
    $self->_cache_put($self->_cache_file($kind, $name), encode_json($data));
    return $data;
}

sub _aemet_dms {
    my $v = shift // '';
    my ($d, $m, $s, $h) = $v =~ /^(\d\d)(\d\d)(\d\d)([NSEW])$/ or return;
    my $x = $d + $m / 60 + $s / 3600;
    return ($h eq 'S' || $h eq 'W') ? -$x : $x;
}

sub _aemet_num { my $v = shift // ''; $v =~ s/,/./; return _num($v) }

sub _aemet_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 27.5, -18.3, 43.9, 4.4);
    my $ready = $self->api_key('aemet') ? 1 : 0;
    return [] if !$ready;    # the station list needs the key too
    my $d = $self->_aemet_get('/valores/climatologicos/inventarioestaciones/todasestaciones', 'jma_stations');
    my @list = map { {
        network => 'aemet', id => $_->{indicativo}, name => _title_words($_->{nombre}), lat => _aemet_dms($_->{latitud}), lon => _aemet_dms($_->{longitud}),
        elev => _num($_->{altitud}), country => 'ES', state => _title_words($_->{provincia}), ready => 1, rain_amounts => 1,
        measures => ['temperature', 'rain', 'humidity', 'wind', 'sunshine'],
    } } @{ref($d) eq 'ARRAY' ? $d : []};
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _aemet_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    die "Unknown AEMET station $id.\n" if $id !~ /^[0-9A-Z]+$/;
    my @days;
    # at most about 5 months per request
    for (my $from = $start; $from le $end; $from = _shift_date($from, 150)) {
        my $to = _shift_date($from, 149);
        $to = $end if $to gt $end;
        my $d = $self->_aemet_get("/valores/climatologicos/diarios/datos/fechaini/${from}T00:00:00UTC/fechafin/${to}T23:59:59UTC/estacion/$id",
            $to ge _iso_days_ago(5) ? 'archive_recent' : 'archive');
        foreach my $r (@{ref($d) eq 'ARRAY' ? $d : []}) {
            my $date = $r->{fecha} // '';
            next if $date !~ /^\d{4}-\d\d-\d\d$/;
            my $p = $r->{prec} // '';
            my %v = (tmax => _aemet_num($r->{tmax}), tmin => _aemet_num($r->{tmin}), tmean => _aemet_num($r->{tmed}),
                rain => $p eq 'Ip' ? 0 : _aemet_num($p), rh => _aemet_num($r->{hrMedia}), wind => _aemet_num($r->{velmedia}),
                gust => _aemet_num($r->{racha}), sunshine => _aemet_num($r->{sol}));
            next if !grep { defined } values %v;
            push @days, $self->_daily_values($lat, $elev, $date, %v);
        }
    }
    return $self->_daily_result(days => \@days, source => "AEMET station $id (Agencia Estatal de Meteorologia, OpenData)",
        note => 'Daily climatological values of AEMET ("Ip" = rain too small to measure, counted as 0). ET0: Penman-Monteith with the radiation estimated from the hours of sunshine where they are measured, otherwise Hargreaves-Samani.');
}

# ------------------------------------------------------------------ Meteo-France climatological data (France, free key)

# the French departments that meet the search circle (official geography API of the French state)
sub _mf_departments {
    my ($self, $lat, $lon, $range_km) = @_;
    my %dep;
    my $r = $range_km > 300 ? 300 : $range_km;
    foreach my $dx (-1, -0.5, 0, 0.5, 1) {
        foreach my $dy (-1, -0.5, 0, 0.5, 1) {
            next if $dx * $dx + $dy * $dy > 1;
            my $la = $lat + $dy * $r / 111.32;
            my $lo = $lon + $dx * $r / (111.32 * cos(deg2rad($lat)));
            my $d = eval { $self->get_json(sprintf("$GEO_GOUV/communes?lat=%.3f&lon=%.3f&fields=codeDepartement&format=json", $la, $lo), 'jma_stations') } || [];
            $dep{$_->{codeDepartement}} = 1 for grep { $_->{codeDepartement} } @$d;
        }
    }
    my @deps = sort keys %dep;
    return @deps;
}

sub _mf_get {
    my ($self, $url, $kind) = @_;
    my $data = $self->with_keys('meteofrance', sub {
        my $key = shift;
        return $self->get_raw($url, $kind, { apikey => $key, Accept => 'application/json' });
    });
    return $data;
}

sub _meteofrance_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, 41.3, -5.2, 51.1, 9.6);
    return [] if !$self->api_key('meteofrance');
    my @list;
    foreach my $dep ($self->_mf_departments($lat, $lon, $range_km)) {
        next if $dep !~ /^\w{1,3}$/;
        my $d = eval { decode_json($self->_mf_get("$METEOFRANCE/liste-stations/quotidienne?id-departement=$dep", 'jma_stations')) } || [];
        foreach my $s (@{ref($d) eq 'ARRAY' ? $d : []}) {
            next if !$s->{posteOuvert};
            push @list, { network => 'meteofrance', id => $s->{id}, name => _title_words($s->{nom}), lat => _num($s->{lat}), lon => _num($s->{lon}),
                elev => _num($s->{alt}), country => 'FR', state => $dep, ready => 1, rain_amounts => 1, measures => ['temperature', 'rain'] };
        }
    }
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

# one order of daily data (at most one year): order, then collect the file when it is ready
sub _mf_order {
    my ($self, $id, $from, $to) = @_;
    my $kind = $to ge _iso_days_ago(5) ? 'archive_recent' : 'archive';
    my $name = "meteofrance:$id:$from:$to";
    my $cached = $self->_cache_get($kind, $name);
    return $cached if defined $cached;
    my $csv = $self->with_keys('meteofrance', sub {
        my $key = shift;
        my %h = (apikey => $key, Accept => 'application/json');
        my $o = $self->ua->get("$METEOFRANCE/commande-station/quotidienne?id-station=$id&date-deb-periode=${from}T00:00:00Z&date-fin-periode=${to}T23:00:00Z", %h);
        die "Meteo-France refused the order (" . $o->status_line . ")\n" if $o->code != 202 && !$o->is_success;
        my $cmd = eval { decode_json($o->decoded_content)->{elaboreProduitAvecDemandeResponse}{return} };
        die "Meteo-France did not give an order number.\n" if !$cmd;
        for my $try (1 .. 8) {
            my $f = $self->ua->get("$METEOFRANCE/commande/fichier?id-cmde=$cmd", apikey => $key);
            return $f->decoded_content(charset => 'none') if $f->code == 201;
            die "Meteo-France could not produce the file (" . $f->status_line . ")\n" if $f->code != 204;
            sleep(1);
        }
        die "Meteo-France is still preparing the file: try again in a minute.\n";
    });
    $self->_cache_put($self->_cache_file($kind, $name), $csv);
    return $csv;
}

sub _meteofrance_daily {
    my ($self, $id, $lat, $lon, $elev, $start, $end) = @_;
    die "Unknown Meteo-France station $id.\n" if $id !~ /^\d{8}$/;
    my @days;
    for (my $from = $start; $from le $end; $from = _shift_date($from, 365)) {
        my $to = _shift_date($from, 364);
        $to = $end if $to gt $end;
        my @lines = split /\r?\n/, $self->_mf_order($id, $from, $to);
        my @cols = split /;/, (shift(@lines) // '');
        foreach my $l (@lines) {
            my %r;
            @r{@cols} = map { s/,/./r } split /;/, $l, -1;
            my ($y, $m, $d) = ($r{DATE} // '') =~ /^(\d{4})(\d\d)(\d\d)$/ or next;
            my $glot = _num($r{GLOT});
            my $inst = _num($r{INST});
            my %v = (rain => _num($r{RR}), tmin => _num($r{TN}), tmax => _num($r{TX}), tmean => _num($r{TM}), rh => _num($r{UM}),
                wind => _num($r{FFM}), gust => _num($r{FXI}), radiation => defined $glot ? $glot / 100 : undef,
                sunshine => defined $inst ? $inst / 60 : undef);
            next if !grep { defined } values %v;
            push @days, $self->_daily_values($lat, $elev, "$y-$m-$d", %v);
        }
    }
    return $self->_daily_result(days => \@days, source => "Meteo-France station $id (climatological data API)",
        note => 'Daily values of Meteo-France (rain of the day: 06 UTC to 06 UTC the next day). ET0: Penman-Monteith where radiation (or sunshine), humidity and wind are measured, otherwise Hargreaves-Samani.');
}

# ------------------------------------------------------------------ DMC (Chile, free key: usuario e-mail and token)

sub _dmc_auth {
    my $key = shift;
    my ($user, $token) = $key =~ /^([^:]+):(.+)$/ or die "The DMC key must be written as e-mail:token (dmc_api_key).\n";
    return 'usuario=' . _uri($user) . '&token=' . _uri($token);
}

sub _dmc_stations {
    my ($self, $lat, $lon, $range_km, $limit) = @_;
    return [] if !$self->_in_box($lat, $lon, $range_km, -56, -76, -17.4, -66);
    return [] if !$self->api_key('dmc');
    my $d = $self->with_keys('dmc', sub { $self->get_json("$DMC/geoservicios/getEmaResumenDiarioGeo?" . _dmc_auth(shift), 'scan_stations') });
    my @list;
    foreach my $f (@{ref($d) eq 'HASH' ? $d->{features} || [] : []}) {
        my $p = $f->{properties} || {};
        push @list, { network => 'dmc', id => $p->{codigoNacional}, name => $p->{nombreEstacion} . ($p->{comuna} ? " ($p->{comuna})" : ''),
            lat => _num($p->{latitud}), lon => _num($p->{longitud}), elev => _num($p->{altitud}), country => 'CL', state => $p->{nombreRegion},
            ready => 1, rain_amounts => 1, measures => ['temperature', 'rain', 'humidity', 'wind', 'radiation'] };
    }
    return $self->_in_range(\@list, $lat, $lon, $range_km, $limit);
}

sub _dmc_value { my $v = shift // ''; $v =~ s/,//g; return $v =~ /^\s*(-?\d+(?:\.\d+)?)/ ? $1 + 0 : undef }

# 15-minute records of a DMC automatic station, month by month, for the hourly summary of station_daily
sub _dmc_records {
    my ($self, $id, $start, $end) = @_;
    die "Unknown DMC station $id.\n" if $id !~ /^\d+$/;
    my @rows;
    my ($y, $m) = split /-/, $start;
    my ($y2, $m2) = split /-/, $end;
    my $this = substr(_iso_days_ago(0), 0, 7);
    while ($y * 12 + $m <= $y2 * 12 + $m2) {
        my $month = sprintf('%04d/%02d', $y, $m);
        my $d = $self->with_keys('dmc', sub {
            $self->get_json("$DMC/servicios/getDatosRecientesEma/$id/$month?" . _dmc_auth(shift), sprintf('%04d-%02d', $y, $m) ge substr(_iso_days_ago(35), 0, 7) ? 'archive_recent' : 'archive');
        });
        my $prev;
        foreach my $r (@{ref($d) eq 'HASH' ? ($d->{datosEstaciones} || {})->{datos} || [] : []}) {
            my ($yy, $mo, $dd, $hh, $mi) = ($r->{momento} // '') =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d)/ or next;    # codespell:ignore momento
            my $time = timegm(0, $mi, $hh, $dd, $mo - 1, $yy);    # UTC
            my $dt = defined $prev ? $time - $prev : 900;
            $dt = 900 if $dt <= 0 || $dt > 3600;
            $prev = $time;
            my $w = _dmc_value($r->{fuerzaDelVientoPromedio10Minutos});
            my $rad = _dmc_value($r->{radiacionGlobalInst});
            push @rows, {
                time => $time, temp_c => _dmc_value($r->{temperatura}), rh => _dmc_value($r->{humedadRelativa}),
                wind_ms => defined $w ? $w * 0.514444 : undef, rad_kj => defined $rad ? $rad * $dt / 1000 : undef,
                # the 24-hour rain (12:01 to 12:00 UTC) is read at 12 UTC, in the morning: counted on that day
                rain_mm => ($hh == 12 && $mi == 0) ? _dmc_value($r->{aguaCaida24Horas}) : undef,
            };
        }
        $m++;
        if ($m > 12) { $m = 1; $y++; }
    }
    return \@rows;
}

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
    # networks that publish daily values: _<network>_daily($id, $lat, $lon, $elev, $start, $end)
    if ($network =~ /^\w+$/ && (my $daily = $self->can("_${network}_daily"))) {
        my $out = $daily->($self, $id, $lat, $lon, $elev, $start, $end);
        $out->{stale} = 1 if $self->{stale};
        return $out;
    }

    my ($hourly, $source, $note, $wind_height);
    if ($network eq 'ideam') {
        $hourly = $self->_ideam_records($id, _shift_date($start, -1), _shift_date($end, 1));
        $source = 'IDEAM automatic station ' . $id;
        $note = 'Rain every 10 minutes summed per local day; max/min of the hourly maximum and minimum temperatures. ET0: Hargreaves-Samani.';
    }
    elsif ($network eq 'inmet') {
        die "INMET data needs a token. Ask INMET for one (free) and set inmet_api_token in the configuration.\n" if !$self->api_key('inmet');
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
    elsif ($network eq 'dmc') {
        $hourly = $self->_dmc_records($id, _shift_date($start, -1), _shift_date($end, 1));
        $source = 'DMC automatic station ' . $id . ' (Direccion Meteorologica de Chile)';    # codespell:ignore direccion
        $note = 'Records of the automatic station summarized per local day; rain: the 24-hour total read at 12 UTC (morning). ET0: FAO-56 Penman-Monteith with the measured radiation, humidity and wind.';
        $wind_height = 10;
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
    if ($network eq 'ana' || $network eq 'cemaden' || ($network eq 'ideam' && !grep { defined $_->{tmax} } @days)) {
        $out{rain_only} = 1;
        $out{note} = 'Rain every 10 minutes, summed per local day. The station does not measure temperature.' if $network eq 'ideam';
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
    die "INMET data needs a token. Ask INMET for one (free) and set inmet_api_token in the configuration.\n" if !$self->api_key('inmet');
    my $recent = $end ge _iso_days_ago(2);
    my $list = $self->get_json("$INMET/token/estacao/$start/$end/$id/" . $self->api_key('inmet'), $recent ? 'archive_recent' : 'archive');
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

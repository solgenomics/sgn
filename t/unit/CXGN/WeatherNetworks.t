# Tests of the station networks added to CXGN::Weather after the first ones
# (DWD, JMA AMeDAS ...), without network: get_raw is replaced by canned answers.

use strict;
use warnings;
use utf8;

use Test::More;
use JSON;
use File::Temp qw(tempdir);
use IO::Compress::Zip qw(zip $ZipError);
use Encode qw(encode decode);
use LWP::UserAgent;
use HTTP::Response;
use CXGN::Weather;

my $wx = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1) });

my %canned;
my @asked;
{
    no warnings 'redefine';
    *CXGN::Weather::get_raw = sub {
        my ($self, $url) = @_;
        push @asked, $url;
        foreach my $k (sort { length($b) <=> length($a) } keys %canned) { return $canned{$k} if index($url, $k) >= 0; }
        die "unexpected url $url\n";
    };
}

sub iso_days_ago { my @t = gmtime(time() - shift() * 86400); return sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]) }

# ------------------------------------------------------------ sunshine -> radiation
# FAO-56 example 10 (Rio de Janeiro, 22 34' S, May 25 = day 135, 7.1 h of sunshine): Rs = 14.5 MJ m-2 day-1
my $rs = $wx->sunshine_radiation(-22.57, 135, 7.1);
ok(abs($rs - 14.5) < 0.3, "radiation from the hours of sunshine ($rs)");
ok(!defined $wx->sunshine_radiation(-22.57, 135, undef), 'no sunshine, no radiation');

# ------------------------------------------------------------ DWD (Germany)
my $active = iso_days_ago(1) =~ s/-//gr;
my $kl_list = encode('latin1', join("\n",
    'Stations_id von_datum bis_datum Stationshoehe geoBreite geoLaenge Stationsname Bundesland Abgabe',
    '----------- --------- --------- ------------- --------- --------- ----------------------------------------- ---------- ------',
    "01691 19570101 $active            167     51.5000    9.9500 Göttingen                                Niedersachsen                            Frei",
    '00001 19370101 19860630            478     47.8413    8.8493 Aach                                     Baden-Württemberg                        Frei',
    "04271 19470101 $active              4     54.1803   12.0808 Rostock-Warnemünde                       Mecklenburg-Vorpommern                   Frei",
));
my $rr_list = encode('latin1', join("\n",
    'Stations_id von_datum bis_datum Stationshoehe geoBreite geoLaenge Stationsname Bundesland Abgabe',
    "01691 19570101 $active            167     51.5000    9.9500 Göttingen                                Niedersachsen                            Frei",
    "01039 19310101 $active            280     51.4500    9.8000 Dransfeld-Ossenfeld                      Niedersachsen                            Frei",
));
$canned{'kl/recent/KL_Tageswerte'} = $kl_list;
$canned{'more_precip/recent/RR_Tageswerte'} = $rr_list;

my $near = $wx->nearby_stations(51.53, 9.93, 30, ['dwd']);
is_deeply([ map { $_->{id} } @{$near->{stations}} ], ['01691', 'R01039'], 'DWD: active stations in range, climate station first, gauge with R');
is($near->{stations}[0]{name}, 'Göttingen', 'DWD: Latin-1 name decoded');
is($near->{stations}[0]{state}, 'Niedersachsen', 'DWD: state');
ok(!$near->{stations}[0]{rain_only} && $near->{stations}[1]{rain_only}, 'DWD: the rain gauge is rain only');
is(scalar @{$wx->nearby_stations(-22.7, -47.6, 200, ['dwd'])->{stations}}, 0, 'DWD: nothing far from Germany');

sub dwd_zip {
    my ($name, $csv) = @_;
    my $out;
    zip(\$csv => \$out, Name => $name) or die $ZipError;
    return $out;
}
my $d1 = iso_days_ago(5);
my $d2 = iso_days_ago(4);
my ($k1, $k2) = map { s/-//gr } $d1, $d2;
$canned{'tageswerte_KL_01691_akt.zip'} = dwd_zip("produkt_klima_tag_${k1}_${k2}_01691.txt", join("\n",
    'STATIONS_ID;MESS_DATUM;QN_3;  FX;  FM;QN_4; RSK;RSKF; SDK;SHK_TAG;  NM; VPM;  PM; TMK; UPM; TXK; TNK; TGK;eor',
    "       1691;$k1;   10;  12.0;   3.0;    3;   4.5;   6;    5.000;   0;   7.0;  12.1; 1000.0;   14.0;   80.00;   19.0;    9.0;    7.0;eor",
    "       1691;$k2;-999;-999;-999;    3;   0.0;   0;-999;   0;  -999;  12.1;    -999;   15.0;   75.00;   20.0;   10.0;    8.0;eor",
));
my $daily = $wx->station_daily('dwd', '01691', 51.5, 9.95, 167, $d1, $d2);
is(scalar @{$daily->{days}}, 2, 'DWD: two days');
my ($a, $b) = @{$daily->{days}};
is_deeply([ @$a{qw(date tmax tmin tmean rh rain)} ], [ $d1, 19, 9, 14, 80, 4.5 ], 'DWD: daily values');
is($a->{wind_mean}, 10.8, 'DWD: mean wind m/s -> km/h');
is($a->{gust_max}, 43, 'DWD: gust m/s -> km/h');
is($a->{et0_method}, 'PM', 'DWD: Penman-Monteith with sunshine, humidity and wind');
is($b->{et0_method}, 'HS', 'DWD: Hargreaves when wind and sunshine are missing (-999)');
ok(!grep({ /historical/ } @asked), 'DWD: recent dates do not read the historical file');

$canned{'tageswerte_RR_01039_akt.zip'} = dwd_zip("produkt_nieder_tag_${k1}_${k2}_01039.txt", join("\n",
    'STATIONS_ID;MESS_DATUM;QN_6;  RS; RSF;SH_TAG;NSH_TAG;eor',
    "       1039;$k1;    9;   2.3;   6;   0;   0;eor",
    "       1039;$k2;    9;   0.0;   0;   0;   0;eor",
));
my $gauge = $wx->station_daily('dwd', 'R01039', 51.45, 9.8, 280, $d1, $d2);
is_deeply([ map { $_->{rain} } @{$gauge->{days}} ], [ 2.3, 0 ], 'DWD gauge: rain');
ok($gauge->{rain_only} && !defined $gauge->{days}[0]{tmax}, 'DWD gauge: rain only');
ok(grep({ /more_precip\/recent\/tageswerte_RR_01039_akt\.zip/ } @asked), 'DWD gauge: reads the rain gauge file');

# old dates: the historical file, found in the directory listing
@asked = ();
$canned{'kl/historical/'} = '<a href="tageswerte_KL_01691_19570101_20251231_hist.zip">x</a>';
$canned{'tageswerte_KL_01691_19570101_20251231_hist.zip'} = dwd_zip('produkt_klima_tag_19570101_20251231_01691.txt', join("\n",
    'STATIONS_ID;MESS_DATUM;QN_3;  FX;  FM;QN_4; RSK;RSKF; SDK;SHK_TAG;  NM; VPM;  PM; TMK; UPM; TXK; TNK; TGK;eor',
    '       1691;20200601;   10;  12.0;   3.0;    3;   1.5;   6;    9.000;   0;   7.0;  12.1; 1000.0;   16.0;   70.00;   22.0;   10.0;    7.0;eor',
));
my $old = $wx->station_daily('dwd', '01691', 51.5, 9.95, 167, '2020-06-01', '2020-06-01');
is_deeply([ map { [ $_->{date}, $_->{rain} ] } @{$old->{days}} ], [ [ '2020-06-01', 1.5 ] ], 'DWD: historical file for old dates');

# ------------------------------------------------------------ JMA AMeDAS (Japan)
$canned{'amedastable.json'} = encode_json({
    40336 => { type => 'C', elems => '11112010', lat => [ 36, 3.4 ], lon => [ 140, 7.5 ], alt => 25, kjName => 'つくば', enName => 'Tsukuba' },
    40326 => { type => 'C', elems => '01000000', lat => [ 36, 3.0 ], lon => [ 139, 53.5 ], alt => 20, kjName => '坂東', enName => 'Bando' },
    44132 => { type => 'A', elems => '11111111', lat => [ 35, 41.5 ], lon => [ 139, 45.0 ], alt => 25, kjName => '東京', enName => 'Tokyo' },
});
$near = $wx->nearby_stations(36.05, 140.12, 30, ['jma']);
is_deeply([ map { $_->{id} } @{$near->{stations}} ], [ '40336', '40326' ], 'JMA: stations in range, nearest first');
is($near->{stations}[0]{name}, 'Tsukuba (つくば)', 'JMA: English and Japanese name');
ok(abs($near->{stations}[0]{lat} - 36.0567) < 0.001, 'JMA: degrees and minutes');
ok(!$near->{stations}[0]{rain_only} && $near->{stations}[1]{rain_only}, 'JMA: rain-only gauge from the elements');
is(scalar @{$wx->nearby_stations(51.5, 9.9, 200, ['jma'])->{stations}}, 0, 'JMA: nothing far from Japan');

my $vp = "viewPoint('%s','%s','%s','X','%s','%s','%s','%s','25','1','1','1','1','0','1','%s','99','99','','','','','')";
$canned{'prefecture.php?prec_no=40'} = encode('UTF-8', join("\n",
    sprintf($vp, 'a', '0999', 'つくば', '36', '03.4', '140', '07.5', '1990'),    # closed: ignored
    sprintf($vp, 'a', '1014', 'つくば', '36', '03.4', '140', '07.5', '9999'),
    sprintf($vp, 'a', '0326', '坂東', '36', '03.0', '139', '53.5', '9999'),
));
my $cell = sub { join '', map { "<td class=data_0_0>$_</td>" } @_ };
$canned{'daily_a1.php?prec_no=40&block_no=1014&year=2025&month=1&'} = encode('UTF-8',
    '<table><tr class="mtx"><th>日</th></tr>'
    . '<tr class="mtx" style="text-align:right;"><td><div class="a_print"><a href="x">1</a></div></td>' . $cell->('--', '0.0', '0.0', '5.0', '11.5', '-2.1', '45', '20', '2.7', '6.0', '北', '9.7', '北', '北', '9.5', '///', '///') . '</tr>'
    . '<tr class="mtx"><td>2</td>' . $cell->('3.5)', '1.0', '0.5', '6.0', '13.6]', '-2.8', '58', '30', '1.3', '4.0', '北', '4.7', '北', '北', '9.0', '///', '///') . '</tr>'
    . '<tr class="mtx"><td>3</td>' . $cell->(('///') x 17) . '</tr></table>');
$daily = $wx->station_daily('jma', '40336', 36.0567, 140.125, 25, '2025-01-01', '2025-01-03');
is(scalar @{$daily->{days}}, 2, 'JMA: days without any value are left out');
($a, $b) = @{$daily->{days}};
is_deeply([ @$a{qw(date rain tmax tmin rh)} ], [ '2025-01-01', 0, 11.5, -2.1, 45 ], 'JMA: -- is no rain');
is($a->{wind_mean}, 9.7, 'JMA: mean wind km/h');
is($a->{et0_method}, 'PM', 'JMA: Penman-Monteith with sunshine');
is($b->{rain}, 3.5, 'JMA: quasi-complete value ")" kept');
ok(!defined $b->{tmax}, 'JMA: incomplete value "]" dropped');
ok(grep({ /block_no=1014/ } @asked), 'JMA: archive page of the open station with the same name and position');

# ------------------------------------------------------------ helpers: CSV, keys
is_deeply([ CXGN::Weather::_csv_split('a,"b, c",,"d ""e"""') ], [ 'a', 'b, c', '', 'd "e"' ], 'CSV line with quotes');
my $wk = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1), api_keys => { aemet => 'K1, K2' } });
is_deeply([ $wk->api_keys_of('aemet') ], [ 'K1', 'K2' ], 'several keys of a network');
my @tried;
is($wk->with_keys('aemet', sub { push @tried, $_[0]; die "AEMET refused the request (401 unauthorized)\n" if $_[0] eq 'K1'; return "ok $_[0]" }), 'ok K2',
    'a refused key passes to the next one');
is_deeply(\@tried, [ 'K1', 'K2' ], 'keys tried in order');
eval { $wk->with_keys('aemet', sub { die "AEMET did not send the data (500)\n" }) };
like($@, qr/500/, 'other errors are not hidden by the next key');
eval { $wx->with_keys('dmc', sub { 1 }) };
like($@, qr/dmc_api_key/, 'a network without key says which configuration to set');

my $D1 = iso_days_ago(5);
my $D2 = iso_days_ago(4);

# ------------------------------------------------------------ ECCC (Canada)
$canned{'collections/climate-stations/items'} = encode_json({ features => [
    { geometry => { coordinates => [ -106.6667, 52.1667 ] }, properties => { CLIMATE_IDENTIFIER => '4057165', STATION_NAME => 'SASKATOON RCS', PROV_STATE_TERR_CODE => 'SK',
        ELEVATION => '504.10', DLY_FIRST_DATE => '1999-01-01 00:00:00', DLY_LAST_DATE => "$D2 00:00:00" } },
    { geometry => { coordinates => [ -106.7, 52.1 ] }, properties => { CLIMATE_IDENTIFIER => '4057120', STATION_NAME => 'OLD', DLY_LAST_DATE => '1990-01-01 00:00:00' } },
] });
$near = $wx->nearby_stations(52.13, -106.67, 50, ['eccc']);
is_deeply([ map { $_->{id} } @{$near->{stations}} ], ['4057165'], 'ECCC: stations with recent daily data only');
is($near->{stations}[0]{name}, 'Saskatoon Rcs', 'ECCC: name');
$canned{'collections/climate-daily/items'} = encode_json({ features => [
    { properties => { LOCAL_DATE => "$D1 00:00:00", MAX_TEMPERATURE => 19.5, MIN_TEMPERATURE => 14.1, MEAN_TEMPERATURE => 16.8, TOTAL_PRECIPITATION => 1.7,
        MIN_REL_HUMIDITY => 60, MAX_REL_HUMIDITY => 90, SPEED_MAX_GUST => 43 } },
    { properties => { LOCAL_DATE => "$D2 00:00:00", MAX_TEMPERATURE => 22.3, MIN_TEMPERATURE => 9.8, TOTAL_PRECIPITATION => 0, TOTAL_PRECIPITATION_FLAG => 'T',
        MIN_TEMPERATURE_FLAG => 'E' } },
] });
$daily = $wx->station_daily('eccc', '4057165', 52.1667, -106.6667, 504, $D1, $D2);
($a, $b) = @{$daily->{days}};
is_deeply([ @$a{qw(tmax tmin rain rh gust_max)} ], [ 19.5, 14.1, 1.7, 75, 43 ], 'ECCC: daily values, RH from min and max, gust km/h');
ok(!defined $b->{tmin} && $b->{rain} == 0, 'ECCC: estimated values dropped, trace of rain = 0');

# ------------------------------------------------------------ USDA SCAN
$canned{'awdbRestApi/services/v1/stations'} = encode_json([
    { stationTriplet => '2031:IA:SCAN', stationId => '2031', stateCode => 'IA', networkCode => 'SCAN', name => 'Ames', countyName => 'Boone',
        elevation => 1000, latitude => 42.02, longitude => -93.73, beginDate => '2001-09-19 00:00' } ]);
$near = $wx->nearby_stations(42.02, -93.77, 50, ['scan']);
is($near->{stations}[0]{id}, '2031_IA', 'SCAN: id = station and state');
is($near->{stations}[0]{elev}, 304.8, 'SCAN: elevation feet -> m');
$canned{'awdbRestApi/services/v1/data'} = encode_json([ { stationTriplet => '2031:IA:SCAN', data => [
    { stationElement => { elementCode => 'TMAX' }, values => [ { date => $D1, value => 77 } ] },
    { stationElement => { elementCode => 'TMIN' }, values => [ { date => $D1, value => 59 } ] },
    { stationElement => { elementCode => 'PRCP' }, values => [ { date => $D1, value => 0.5 } ] },
    { stationElement => { elementCode => 'WSPDV' }, values => [ { date => $D1, value => 10 } ] },
] } ]);
$daily = $wx->station_daily('scan', '2031_IA', 42.02, -93.73, 305, $D1, $D1);
is_deeply([ @{$daily->{days}[0]}{qw(tmax tmin rain wind_mean)} ], [ 25, 15, 12.7, 16.1 ], 'SCAN: F -> C, in -> mm, mph -> km/h');
like($asked[-1], qr/stationTriplets=2031:IA:SCAN/, 'SCAN: triplet of the station');

# ------------------------------------------------------------ ISU Soil Moisture (Iowa)
$canned{'network/ISUSM.geojson'} = encode_json({ features => [
    { geometry => { coordinates => [ -93.79, 42.02 ] }, properties => { id => 'BOOI4', name => 'Ames - AEA', elevation => 335, online => JSON::true, archive_begin => '2013-01-01' } },
    { geometry => { coordinates => [ -93.7, 42.0 ] }, properties => { id => 'OLDI4', name => 'Closed', online => JSON::false } } ] });
is_deeply([ map { $_->{id} } @{$wx->nearby_stations(42.02, -93.77, 50, ['isusm'])->{stations}} ], ['BOOI4'], 'ISUSM: online stations only');
$canned{'isusm.py'} = "station,valid,high,low,rh,precip,speed,solar_mj\nBOOI4,$D1,86.0,50.0,60.0,0.1000,8.9477,20.5\n";
$daily = $wx->station_daily('isusm', 'BOOI4', 42.02, -93.79, 335, $D1, $D1);
is_deeply([ @{$daily->{days}[0]}{qw(tmax tmin rh rain radiation et0_method)} ], [ 30, 10, 60, 2.5, 20.5, 'PM' ], 'ISUSM: units and Penman-Monteith');

# ------------------------------------------------------------ CoAgMet (Colorado)
$canned{'coagmet.colostate.edu/data/metadata.csv'} = qq{Station,Name,Location,"Latitude (degN)","Longitude (degE)","Elevation (ft)","Anemometer Height (m)",Active,"First Observation"\n}
    . qq{fcl01,"Fort Collins","CSU Campus",40.5715,-105.0855,5000,2,active,"01/01/1992"\nold01,"Old","",40.57,-105.08,5000,2,inactive,"01/01/1992"\n};
$near = $wx->nearby_stations(40.58, -105.08, 30, ['coagmet']);
is_deeply([ map { $_->{id} } @{$near->{stations}} ], ['FCL01'], 'CoAgMet: active stations');
$canned{'coagmet.colostate.edu/data/daily/fcl01.csv'} = qq{Station,Date,"Avg Temp","Max Temp","Min Temp","RH Max","RH Min","Solar Rad","Liquid Precip","Wind Run","Gust Speed"\n}
    . qq{id,date,"deg C","deg C","deg C","%","%","W m-2",mm,km,m/s\nfcl01,"$D1",20,27,13,0.9,0.3,250,1.5,172.8,11\nfcl01,"$D2",-999,-999,-999,-999,-999,-999,-999,-999,-999\n};
$daily = $wx->station_daily('coagmet', 'FCL01', 40.57, -105.09, 1524, $D1, $D2);
is(scalar @{$daily->{days}}, 1, 'CoAgMet: -999 days left out');
is_deeply([ @{$daily->{days}[0]}{qw(tmax rh rain wind_mean radiation)} ], [ 27, 60, 1.5, 7.2, 21.6 ], 'CoAgMet: RH fraction, wind run, W/m2 -> MJ');

# ------------------------------------------------------------ AZMet (Arizona)
$canned{'azmet-station-info.csv'} = "name,symbol,id,county,latitude,longitude,elev_ft,elev_m,status,start_date,end_date\n"
    . "Tucson,TUC,az01,Pima,32.2806,-110.9459,2343,714,active,2020-01-01,NA\nTest,TST,az99,Pima,32.2806,-110.9459,2343,714,active,2020-01-01,NA\n";
is_deeply([ map { $_->{id} } @{$wx->nearby_stations(32.28, -110.95, 30, ['azmet'])->{stations}} ], ['AZ01'], 'AZMet: active stations, not the test one');
$canned{'api.azmet.arizona.edu/v1/observations/daily/az01'} = encode_json({ data => [ { datetime => $D1, temp_air_maxC => '30.0', temp_air_minC => '20.3',
    relative_humidity_mean => '53', precip_total_mm => '3.0', wind_spd_mean_mps => '3.1', sol_rad_total => '15.3' } ] });
$daily = $wx->station_daily('azmet', 'AZ01', 32.28, -110.95, 714, $D1, $D1);
is_deeply([ @{$daily->{days}[0]}{qw(tmax tmin rain radiation et0_method)} ], [ 30, 20.3, 3, 15.3, 'PM' ], 'AZMet: daily values');

# ------------------------------------------------------------ SMN / CONAGUA (Mexico)
$canned{'estaciones_climatologicas.geojson'} = encode_json({ features => [
    { geometry => { coordinates => [ -107.44, 24.635 ] }, properties => { clave => '25014', nombre => 'CULIACAN (OBS)', estado => 'SINALOA', municipio => 'CULIACÁN',
        altitud => '22', inicio => '1922-01-01', mas_reciente => $D2, diarios => 'https://smn.conagua.gob.mx/tools/RESOURCES/Normales_Climatologicas/Diarios/sin/dia25014.txt' } },
    { geometry => { coordinates => [ -107.4, 24.6 ] }, properties => { clave => '25999', nombre => 'OLD', mas_reciente => '1990-01-01', diarios => 'x' } } ] });
$near = $wx->nearby_stations(24.8, -107.4, 50, ['conagua']);
is_deeply([ map { $_->{id} } @{$near->{stations}} ], ['25014'], 'SMN Mexico: stations with recent data');
ok(!exists $near->{stations}[0]{file}, 'SMN Mexico: file address not sent to the page');
$canned{'Diarios/sin/dia25014.txt'} = encode('UTF-8', "COMISIÓN NACIONAL DEL AGUA\n ESTACIÓN   : 25014 \n\nFECHA\t\tPRECIP\tEVAP\tTMAX\tTMIN\n$D1\t1.6\tNULO\t32.9\t25.7\n$D2\tNULO\tNULO\tNULO\tNULO\n");
$daily = $wx->station_daily('conagua', '25014', 24.635, -107.44, 22, $D1, $D2);
is_deeply([ map { [ @$_{qw(date rain tmax tmin)} ] } @{$daily->{days}} ], [ [ $D1, 1.6, 32.9, 25.7 ] ], 'SMN Mexico: daily file, NULO = missing');

# ------------------------------------------------------------ INTA (Argentina)
$canned{'siga.inta.gob.ar/E7HYRhmod5ERWTQH.php?param_type=estacion'} = encode_json([
    { id => 236, nombre => 'Alfonso - EEA Pergamino', provincia => 'Buenos Aires', latitud => -33.95, longitud => -60.8, altura => 70, idTipo => 2,
        visible => JSON::true, minimoDiario => '2010-01-01T00:00:00Z[UTC]', maximoDiario => "${D2}T00:00:00Z[UTC]" },
    { id => 1, nombre => 'Old', latitud => -33.9, longitud => -60.6, visible => JSON::true, maximoDiario => '2001-01-01T00:00:00Z[UTC]' } ]);
$near = $wx->nearby_stations(-33.9, -60.57, 50, ['inta']);
is_deeply([ map { $_->{id} } @{$near->{stations}} ], [236], 'INTA: stations with recent data');
$canned{'param_type=diario&param_value=236/'} = encode_json([ { fechaHora => "${D1}T00:00:00Z[UTC]", tempAbrigo150Max => 32.9, tempAbrigo150Min => 14.9,
    HMedia => 64, precDiaPlub => 4.5 } ]);
$daily = $wx->station_daily('inta', '236', -33.95, -60.8, 70, $D1, $D1);
is_deeply([ @{$daily->{days}[0]}{qw(tmax tmin rh rain)} ], [ 32.9, 14.9, 64, 4.5 ], 'INTA: daily values');

# ------------------------------------------------------------ SILO (Australia)
my $ws = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1), api_keys => { silo => 'admin@example.org' } });
$canned{'PatchedPointDataset.php?format=near'} = "Number|Station name|Latitude|Longitud|Stat|Elevat.|Distance (km)\n"
    . " 40082|UNIVERSITY OF QUEENSLAND GATTON         |-27.5436|152.3375|QLD |   89.0|  0.0\n 40436|GATTON DAFF RESEARCH STN                 |-27.5456|152.3289|QLD |   98.0|  0.0\n";
my $bom = " 040082 40    UNIVERSITY OF QUEENSLAND GATTON             1897      .. -27.5436  152.3375 GPS            QLD       89.0       ..  94562\n"
    . " 040436 40    GATTON DAFF RESEARCH STN                    1968    2014 -27.5456  152.3289 GPS            QLD       98.0       ..     ..\n";
my $bomzip;
zip(\$bom => \$bomzip, Name => 'stations.txt') or die $ZipError;
$canned{'ftp.bom.gov.au'} = $bomzip;
$near = $ws->nearby_stations(-27.55, 152.34, 30, ['silo']);
is_deeply([ map { $_->{id} } @{$near->{stations}} ], [40082], 'SILO: stations closed in the BoM list are left out');
$canned{'PatchedPointDataset.php?station=40082'} = encode_json({ data => [
    { date => $D1, variables => [ { source => 0, value => 2.2, variable_code => 'daily_rain' }, { source => 0, value => 19.3, variable_code => 'max_temp' },
        { source => 0, value => 14.7, variable_code => 'min_temp' } ] },
    { date => $D2, variables => [ { source => 25, value => 5, variable_code => 'daily_rain' }, { source => 0, value => 20, variable_code => 'max_temp' },
        { source => 25, value => 10, variable_code => 'min_temp' } ] } ] });
$daily = $ws->station_daily('silo', '40082', -27.54, 152.34, 89, $D1, $D2);
is_deeply([ map { [ @$_{qw(rain tmax tmin)} ] } @{$daily->{days}} ], [ [ 2.2, 19.3, 14.7 ], [ undef, 20, undef ] ], 'SILO: only values observed at the station (source 0)');
like($asked[-1], qr/username=admin%40example\.org/, 'SILO: the admin e-mail as username');
eval { $wx->station_daily('silo', '40082', -27.54, 152.34, 89, $D1, $D2) };
like($@, qr/silo_username/, 'SILO: without username a clear message');

# ------------------------------------------------------------ IMS archive (Israel)
my $lm = substr(iso_days_ago(40), 0, 7);
$canned{'resource_id=83841660'} = encode_json({ success => JSON::true, result => { records => [
    { stn_num => 2522, stn_type => 1, stn_name => 'BET DAGAN', stn_lat => 32.0073, stn_long => 34.8138, stn_hgt => 31, date_close => '', date_web_frst => '2021-08', date_web_last => $lm },
    { stn_num => 136741, stn_type => 2, stn_name => 'BET DAGAN', stn_lat => 32.0073, stn_long => 34.8138, stn_hgt => 31, date_close => '', date_web_frst => '2000-01', date_web_last => $lm },
    { stn_num => 120, stn_type => 1, stn_name => 'CLOSED', stn_lat => 32.0, stn_long => 34.8, date_close => '1984-01-31', date_web_last => '1983-12' } ] } });
$near = $wx->nearby_stations(32.0, 34.8, 20, ['ims']);
is_deeply([ sort map { $_->{id} } @{$near->{stations}} ], [ 136741, 2522 ], 'IMS: open climate stations and rain gauges');
my ($ry, $rm) = split /-/, $lm;
my ($rd1, $rd2) = ("$lm-01", "$lm-03");
$canned{'resource_id=e80b470f'} = encode_json({ success => JSON::true, result => { records => [
    { time_obs => "$lm-02", rain_06_next => 12.5, rain_code => 0 }, { time_obs => "$lm-03", rain_06_next => 7, rain_code => 3 } ] } });
$daily = $wx->station_daily('ims', '136741', 32.0, 34.8, 31, $rd1, $rd2);
is_deeply([ map { [ @$_{qw(date rain)} ] } @{$daily->{days}} ], [ [ $rd1, 0 ], [ "$lm-02", 12.5 ] ], 'IMS: dry days filled with 0, no-data code left out');
$canned{'resource_id=cee3ad4a'} = encode_json({ success => JSON::true, result => { records => [ { time_obs => $rd1, tmp_air_max => 29.8, tmp_air_min => 21.8 } ] } });
$daily = $wx->station_daily('ims', '2522', 32.0, 34.8, 31, $rd1, $rd1);
is_deeply([ @{$daily->{days}[0]}{qw(tmax tmin)} ], [ 29.8, 21.8 ], 'IMS: climate station temperatures');
is($daily->{rain_reported}, 0, 'IMS: climate stations do not give rain');

# ------------------------------------------------------------ Hilltop servers (New Zealand)
my $wh = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1), hilltop_servers => 'https://hydro.example.govt.nz/data.hts, not a url' });
$canned{'Request=SiteList&Location=LatLong&Measurement=Rainfall'} = '<HilltopServer><Agency>Marlborough DC</Agency><Site Name="Blenheim &amp; Co"><Latitude>-41.52</Latitude><Longitude>173.95</Longitude></Site></HilltopServer>';
$canned{'Request=SiteList&Location=LatLong&Measurement=Air%20Temperature'} = '<HilltopServer><Agency>Marlborough DC</Agency><Site Name="Blenheim &amp; Co"><Latitude>-41.52</Latitude><Longitude>173.95</Longitude></Site></HilltopServer>';
$near = $wh->nearby_stations(-41.52, 173.95, 10, ['hilltop']);
is($near->{stations}[0]{name}, 'Blenheim & Co (Marlborough DC)', 'Hilltop: site name and council');
like($near->{stations}[0]{id}, qr/^H[0-9a-f]{12}$/, 'Hilltop: short id for the page');
my $next = CXGN::Weather::_shift_date($D1, 1);
$canned{'Measurement=Rainfall&From'} = "<Hilltop><Data><E><T>${next}T00:00:00</T><I1>4.5</I1></E></Data></Hilltop>";
$canned{'Measurement=Air%20Temperature&From'} = "<Hilltop><Data><E><T>${next}T00:00:00</T><I1>4.5</I1><I2>10.3</I2><I3>15</I3></E></Data></Hilltop>";
$canned{'Request=GetData'} = '<HilltopServer><Error>No data</Error></HilltopServer>';
$daily = $wh->station_daily('hilltop', uc $near->{stations}[0]{id}, -41.52, 173.95, 10, $D1, $D1);
is_deeply([ @{$daily->{days}[0]}{qw(date rain tmin tmean tmax)} ], [ $D1, 4.5, 4.5, 10.3, 15 ], 'Hilltop: values stamped at the end of the day go to that day');

# ------------------------------------------------------------ keyed services through a fake user agent
# a real user agent whose requests are answered here (routes: part of the URL => [code, body] or sub)
sub fake_ua {
    my %routes = @_;
    my $ua = LWP::UserAgent->new();
    $ua->{asked} = [];
    $ua->add_handler(request_send => sub {
        my ($req) = @_;
        my $url = $req->uri->as_string;
        push @{$ua->{asked}}, [ $url, $req->as_string ];
        foreach my $k (sort { length($b) <=> length($a) } keys %routes) {
            next if index($url, $k) < 0;
            my ($code, $body) = ref($routes{$k}) eq 'CODE' ? $routes{$k}->($url) : @{$routes{$k}};
            my $res = HTTP::Response->new($code, 'x', [], $body);
            $res->request($req);
            return $res;
        }
        return HTTP::Response->new(404, 'not found', [], '');
    });
    return $ua;
}

# AEMET: two steps, coordinates DDMMSSX, decimal comma, "Ip"
my $fa = fake_ua(
    'inventarioestaciones' => [ 200, encode_json({ estado => 200, datos => 'https://opendata.aemet.es/opendata/sh/inv' }) ],
    'opendata/sh/inv' => [ 200, encode('iso-8859-15', decode('UTF-8', encode_json([ { indicativo => '5612B', nombre => 'LA RODA DE ANDALUCÍA', provincia => 'SEVILLA',
        latitud => '371202N', longitud => '044500W', altitud => '410' } ]))) ],
    'diarios/datos' => [ 200, encode_json({ estado => 200, datos => 'https://opendata.aemet.es/opendata/sh/day' }) ],
    'opendata/sh/day' => [ 200, encode_json([ { fecha => $D1, tmax => '17,1', tmin => '5,1', tmed => '11,1', prec => 'Ip', hrMedia => '80', velmedia => '1,4', racha => '5,0', sol => '8,2' } ]) ],
);
my $wa = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1), api_keys => { aemet => 'KEY' }, ua => $fa });
$near = $wa->nearby_stations(37.2, -4.75, 20, ['aemet']);
is($near->{stations}[0]{id}, '5612B', 'AEMET: station list');
ok(abs($near->{stations}[0]{lat} - 37.2006) < 0.001 && abs($near->{stations}[0]{lon} + 4.75) < 0.001, 'AEMET: DDMMSS coordinates, W negative');
is($near->{stations}[0]{name}, "La Roda De Andaluc\x{ed}a", 'AEMET: Latin-9 answer decoded');
like($fa->{asked}[0][1], qr/^api_key: KEY$/m, 'AEMET: key in the api_key header (name kept as written)');
$daily = $wa->station_daily('aemet', '5612B', 37.2, -4.75, 410, $D1, $D1);
is_deeply([ @{$daily->{days}[0]}{qw(tmax tmin rain rh sunshine et0_method)} ], [ 17.1, 5.1, 0, 80, 8.2, 'PM' ], 'AEMET: decimal comma, Ip = 0, PM with sunshine');
is(scalar @{$wx->nearby_stations(37.2, -4.75, 20, ['aemet'])->{stations}}, 0, 'AEMET: nothing listed without a key');

# Meteo-France: order (202), file not ready (204), file (201)
my $polls = 0;
my $fm = fake_ua(
    'commande-station/quotidienne' => [ 202, encode_json({ elaboreProduitAvecDemandeResponse => { return => '777' } }) ],
    'commande/fichier?id-cmde=777' => sub { $polls++; return $polls < 2 ? (204, '') : (201, "POSTE;DATE;RR;TN;TX;TM;UM;FFM;FXI;INST;GLOT\r\n13001009;" . ($D1 =~ s/-//gr) . ";10,4;8,8;15,2;12,3;80;3,0;15,0;300;1500\r\n") },
);
my $wm = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1), api_keys => { meteofrance => 'MFKEY' }, ua => $fm });
$daily = $wm->station_daily('meteofrance', '13001009', 43.5, 5.4, 100, $D1, $D1);
is_deeply([ @{$daily->{days}[0]}{qw(rain tmin tmax rh radiation sunshine et0_method)} ], [ 10.4, 8.8, 15.2, 80, 15, 5, 'PM' ],
    'Meteo-France: order, wait, file; J/cm2 and minutes converted');
like($fm->{asked}[0][1], qr/^apikey: MFKEY$/mi, 'Meteo-France: key in the apikey header');
is($polls, 2, 'Meteo-France: the file is asked again while it is being prepared');
$canned{'geo.api.gouv.fr/communes'} = encode_json([ { codeDepartement => '13' } ]);
$canned{'liste-stations/quotidienne?id-departement=13'} = encode_json([ { id => '13001009', nom => 'AIX EN PROVENCE', posteOuvert => JSON::true, lat => 43.53, lon => 5.42, alt => 173 },
    { id => '13999999', nom => 'FERME', posteOuvert => JSON::false, lat => 43.5, lon => 5.4 } ]);
is_deeply([ map { $_->{id} } @{$wm->nearby_stations(43.5, 5.4, 20, ['meteofrance'])->{stations}} ], ['13001009'], 'Meteo-France: open stations of the departments around');

# DMC Chile: e-mail:token, 15-minute records summarized per day
my $wd = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1), api_keys => { dmc => 'me@example.cl:TOK' } });
$canned{'getEmaResumenDiarioGeo'} = encode_json({ features => [ { properties => { codigoNacional => 330020, nombreEstacion => 'Quinta Normal', comuna => 'Santiago',
    latitud => -33.445, longitud => -70.683, altitud => 527, nombreRegion => 'Metropolitana' } } ] });
$near = $wd->nearby_stations(-33.45, -70.68, 20, ['dmc']);
is($near->{stations}[0]{id}, 330020, 'DMC: station list');
like($asked[-1], qr/usuario=me%40example\.cl&token=TOK/, 'DMC: e-mail and token in the query');
my @recs;
foreach my $h (0 .. 23) {
    my ($y, $m, $d) = split /-/, $D1;
    my $utc = sprintf('%s %02d:00:00', CXGN::Weather::_shift_date($D1, $h + 4 >= 24 ? 1 : 0), ($h + 4) % 24);    # local = UTC - 4 (longitude -70.7)
    push @recs, { momento => $utc, temperatura => (10 + $h % 12) . ' °C', humedadRelativa => '60 %', fuerzaDelVientoPromedio10Minutos => '4.0 kt',    # codespell:ignore momento
        radiacionGlobalInst => '300.0 Watt/m2', aguaCaida24Horas => '2.5 mm' };
}
$canned{'getDatosRecientesEma/330020/'} = encode_json({ datosEstaciones => { datos => \@recs } });
$daily = $wd->station_daily('dmc', '330020', -33.445, -70.683, 527, $D1, $D1);
my ($dd) = grep { $_->{date} eq $D1 } @{$daily->{days}};
is_deeply([ @$dd{qw(tmax tmin rh rain)} ], [ 21, 10, 60, 2.5 ], 'DMC: temperatures, humidity, rain read at 12 UTC');

done_testing();

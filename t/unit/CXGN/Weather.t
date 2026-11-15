
# Tests of CXGN::Weather without network: geometry, agronomic formulas and the
# parsing of the services, with get_raw replaced by canned answers.

use strict;
use warnings;

use Test::More;
use JSON;
use File::Temp qw(tempdir);
use CXGN::Weather;

my $wx = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1) });

# ------------------------------------------------------------ geometry and units
my $d = $wx->distance_km(-22.7, -47.6, -23.007, -47.135);    # Piracicaba -> Viracopos
ok(abs($d - 58.6) < 0.5, "haversine distance ($d km)");
is(sprintf('%.0f', $wx->distance_km(0, 0, 0, 1)), 111, 'one degree of longitude at the equator');
is($wx->compass($wx->bearing(0, 0, 1, 0)), 'N', 'bearing north');
is($wx->compass($wx->bearing(0, 0, 0, 1)), 'E', 'bearing east');
is($wx->compass($wx->bearing(0, 0, -1, -1)), 'SW', 'bearing south-west');
is($wx->compass(359), 'N', 'compass wraps at 360');
ok(abs($wx->to_km(200, 'mi') - 321.87) < 0.01, '200 miles in km');
is($wx->to_km(200, 'km'), 200, 'km unchanged');
my @box = $wx->bbox(-22.7, -47.6, 200);
ok($box[0] < -22.7 && $box[2] > -22.7 && $box[1] < -47.6 && $box[3] > -47.6, 'bbox contains the point');
ok(abs(($box[2] - $box[0]) - 2 * 200 / 111.32) < 1e-6, 'bbox latitude span');

is($wx->relative_humidity(20, 20), 100, 'RH 100% when dew point = temperature');
my $rh = $wx->relative_humidity(30, 20);
ok($rh > 53 && $rh < 57, "RH from temperature and dew point ($rh%)");

# FAO-56 example 8 (Ra at 20 S, 3 September = day 246): 32.2 MJ m-2 day-1
my $ra = $wx->extraterrestrial_radiation(-20, 246);
ok(abs($ra - 32.2) < 0.2, "extraterrestrial radiation ($ra)");

# FAO-56 example 18 (Brussels, 6 July): ET0 = 3.9 mm/day (RH mean of RHmax 84 / RHmin 63)
my $pm = $wx->penman_monteith_et0(lat => 50.8, elev => 100, doy => 187, tmax => 21.5, tmin => 12.3,
    rh => 73.5, rs => 22.07, wind => 2.078, wind_height => 2);
ok(abs($pm - 3.9) < 0.2, "Penman-Monteith ET0 ($pm)");
ok(!defined $wx->penman_monteith_et0(lat => 0, doy => 1, tmax => 30, tmin => 20), 'PM needs all the inputs');

my $hs = $wx->hargreaves_et0(-22.7, 320, 31, 19);
ok($hs > 4 && $hs < 7, "Hargreaves ET0 ($hs)");
ok(!defined $wx->hargreaves_et0(-22.7, 320, 10, 19), 'Hargreaves refuses tmax < tmin');

# ------------------------------------------------------------ canned answers
my %canned;
my @asked;
{
    no warnings 'redefine';
    *CXGN::Weather::get_raw = sub {
        my ($self, $url) = @_;
        push @asked, $url;
        foreach my $k (keys %canned) { return $canned{$k} if index($url, $k) >= 0; }
        die "unexpected url $url\n";
    };
}

my $recent_iso = sub { my @t = gmtime(time() - shift); sprintf('%04d-%02d-%02dT%02d:%02d:00Z', $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1]) };
$canned{'networks.geojson'} = encode_json({ features => [
    { id => 'BR__ASOS', geometry => { type => 'Polygon', coordinates => [[[-73, -33], [-35, -33], [-35, 5], [-73, 5], [-73, -33]]] } },
    { id => 'GH__ASOS', geometry => { type => 'Polygon', coordinates => [[[-3, 4.5], [1, 4.5], [1, 11], [-3, 11], [-3, 4.5]]] } },
    { id => 'BR_COOP', geometry => { type => 'Polygon', coordinates => [[[-73, -33], [-35, -33], [-35, 5], [-73, 5], [-73, -33]]] } },
] });
$canned{'network/BR__ASOS.geojson'} = encode_json({ features => [
    { id => 'SBKP', properties => { sname => 'Campinas', elevation => 659, country => 'BR', archive_end => undef }, geometry => { coordinates => [-47.135, -23.007] } },
    { id => 'SBSP', properties => { sname => 'Congonhas', elevation => 802, country => 'BR' }, geometry => { coordinates => [-46.656, -23.626] } },
    { id => 'XXXX', properties => { sname => 'Too far', country => 'BR' }, geometry => { coordinates => [-47.6, -30] } },
    { id => 'OLDA', properties => { sname => 'Closed', country => 'BR', archive_end => '2010-01-01' }, geometry => { coordinates => [-47.6, -22.8] } },
] });
$canned{'currents.json?network=BR__ASOS'} = encode_json({ data => [
    { station => 'SBKP', utc_valid => $recent_iso->(600), tmpf => 68, dwpf => 64.4, relh => 88, sknt => 10, drct => 110, vsby => 6.2137, alti => 29.97, raw => 'SBKP 150200Z 11010KT CAVOK 20/18 Q1015' },
    { station => 'SBSP', utc_valid => '2020-01-01T00:00:00Z', tmpf => 50 },
] });
$canned{'/estacoes/T'} = encode_json([
    { CD_ESTACAO => 'A726', DC_NOME => 'PIRACICABA', VL_LATITUDE => '-22.70', VL_LONGITUDE => '-47.62', VL_ALTITUDE => '580', SG_ESTADO => 'SP', CD_SITUACAO => 'Operante' },
    { CD_ESTACAO => 'A001', DC_NOME => 'BRASILIA', VL_LATITUDE => '-15.78', VL_LONGITUDE => '-47.92', VL_ALTITUDE => '1160', SG_ESTADO => 'DF', CD_SITUACAO => 'Operante' },
]);

my $near = $wx->nearby_stations(-22.7, -47.6, 200, ['airport', 'inmet']);
is_deeply($near->{errors}, [], 'no error');
is_deeply([ map { $_->{id} } @{$near->{stations}} ], ['A726', 'SBKP', 'SBSP'], 'stations within range, nearest first, closed airports left out');
my ($kp) = grep { $_->{id} eq 'SBKP' } @{$near->{stations}};
is($kp->{latest}{temp_c}, 20, 'latest observation attached (F -> C)');
is($kp->{latest}{wind_kmh}, 19, 'knots converted to km/h');
is($kp->{latest}{visibility_km}, 10, 'visibility in km');
is($kp->{latest}{pressure_hpa}, 1015, 'altimeter in hPa');
is($kp->{has_taf}, 0, 'TAF only for US airports');
my ($sp) = grep { $_->{id} eq 'SBSP' } @{$near->{stations}};
ok(!$sp->{latest}, 'an old observation is not shown as the latest');
ok(!grep({ /aviationweather|noaa\.gov/ } @asked), 'no NOAA service asked');
my ($inmet) = grep { $_->{network} eq 'inmet' } @{$near->{stations}};
is($inmet->{ready}, 0, 'INMET station not readable without a token');

@asked = ();
my $far = $wx->nearby_stations(45, 10, 200, ['inmet']);
is(scalar(@{$far->{stations}}), 0, 'no INMET station far from Brazil');
is(scalar(@asked), 0, 'INMET is not asked outside Brazil');

# METAR archive (IEM): two local days of hourly data at UTC-3, no rain amounts
my @csv = ('station,valid,tmpc,dwpc,relh,sknt,gust,p01m,wxcodes');
for my $day (14, 15) {
    for my $h (0 .. 23) {
        my $t = 15 + 10 * sin(3.14159 * (($h - 9) % 24) / 24);    # peaks in the afternoon (local)
        my $wx_code = ($day == 14 && $h >= 18 && $h <= 20) ? 'TSRA' : ($h == 5 ? 'VCSH' : '');
        push @csv, sprintf('SBKP,2026-10-%02d %02d:00,%.1f,12.0,70.0,8.0,,0.00,%s', $day, $h, $t, $wx_code);
    }
}
$canned{'asos.py'} = join("\n", @csv) . "\n";
my $daily = $wx->station_daily('airport', 'SBKP', -23.0, -47.1, 659, '2026-10-14', '2026-10-15');
is($daily->{rain_reported}, 0, 'rain amounts of zero with rain codes = rain not reported');
my ($d14) = grep { $_->{date} eq '2026-10-14' } @{$daily->{days}};
ok($d14, 'local day 2026-10-14');
is($d14->{rain}, undef, 'no rain amount when not reported');
is($d14->{rain_hours}, 3, 'rain hours from TSRA codes (VCSH ignored)');
is($d14->{et0_method}, 'HS', 'airport ET0 = Hargreaves');
ok(defined $d14->{tmax} && $d14->{tmax} > $d14->{tmin}, 'daily max and min');
like($asked[-1], qr/station=SBKP.*report_type=3/, 'IEM request');

# INMET with a token: hourly records summarized per local day, Penman-Monteith ET0
my $wt = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1), inmet_token => 'TOKEN' });
my @rows;
for my $day (14, 15, 16) {
    for my $h (0 .. 23) {
        my $local = ($h - 3) % 24;
        my $sun = ($local >= 6 && $local <= 18) ? 2500 * sin(3.14159 * ($local - 6) / 12) : 0;
        push @rows, { DT_MEDICAO => "2026-10-$day", HR_MEDICAO => sprintf('%02d00', $h), TEM_INS => 20 + $sun / 500,
            TEM_MAX => 20.5 + $sun / 500, TEM_MIN => 19.5 + $sun / 500, UMD_INS => 70, VEN_VEL => 2, VEN_RAJ => 6,
            CHUVA => ($day == 15 && $h == 20) ? 12.4 : 0, RAD_GLO => $sun > 0 ? $sun : -9999, PRE_INS => 950 };
    }
}
$canned{'/token/estacao/'} = encode_json(\@rows);
my $id = $wt->station_daily('inmet', 'A726', -22.7, -47.62, 580, '2026-10-15', '2026-10-15');
is($id->{rain_reported}, 1, 'INMET reports rain');
is(scalar(@{$id->{days}}), 1, 'one local day');
is($id->{days}[0]{rain}, 12.4, 'INMET rain summed');
is($id->{days}[0]{et0_method}, 'PM', 'INMET ET0 = Penman-Monteith');
ok($id->{days}[0]{radiation} > 15, 'daily radiation in MJ/m2');
like($asked[-1], qr{/token/estacao/2026-10-14/2026-10-16/A726/TOKEN}, 'INMET request asks one extra day on each side');

eval { $wx->station_daily('inmet', 'A726', -22.7, -47.62, 580, '2026-10-15', '2026-10-15') };
like($@, qr/token/, 'INMET without token gives a clear message');

# ------------------------------------------------------------ ANA and CEMADEN rain gauges (Sete Lagoas, MG)
my $wb = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1) });
%canned = ();
$canned{'municipios.csv'} = "codigo_ibge,name,latitude,longitude,capital,codigo_uf,siafi_id,ddd,fuso_horario\n"
    . "3167202,Sete Lagoas,-19.4569,-44.2413,0,31,5313,31,America/Sao_Paulo\n"
    . "3141108,Matozinhos,-19.5543,-44.0868,0,31,4945,31,America/Sao_Paulo\n"
    . "3550308,S\xc3\xa3o Paulo,-23.5329,-46.6395,1,35,7107,11,America/Sao_Paulo\n";
$canned{'getJson2.php?uf=MG'} = encode_json([
    { idestacao => 19563, uf => 'MG', codibge => 3167202, cidade => 'SETE LAGOAS', nomeestacao => 'G2-316720201A', datahoraUltimovalor => '15/11/26 03:10', acc24hr => 5.8, acc72hr => 21.8, acc96hr => 28.6, tipoestacao => 1 },
    { idestacao => 19444, uf => 'MG', codibge => 3141108, cidade => 'MATOZINHOS', nomeestacao => 'G2-314110801A', datahoraUltimovalor => '15/11/26 03:10', acc24hr => '-', acc96hr => 20.8, tipoestacao => 1 },
    { idestacao => 99999, uf => 'MG', codibge => 3141108, cidade => 'MATOZINHOS', nomeestacao => 'hydro', tipoestacao => 2 },
]);
$canned{'ListaEstacoesTelemetricas'} = '<DataSet><Estacoes>'
    . '<Table><NomeEstacao>JEQUITIB' . "\xc3\x81" . '</NomeEstacao><CodEstacao>41410000</CodEstacao><Latitude>-19.2342</Latitude><Longitude>-44.0286</Longitude><Altitude>628</Altitude><StatusEstacao>Ativo</StatusEstacao><Operadora>00082 - SGB-CPRM</Operadora></Table>'
    . '<Table><NomeEstacao>OLD ONE</NomeEstacao><CodEstacao>1</CodEstacao><Latitude>-19.4</Latitude><Longitude>-44.2</Longitude><StatusEstacao>Inativo</StatusEstacao></Table>'
    . '</Estacoes></DataSet>';

my $sl = $wb->nearby_stations(-19.466, -44.247, 60, ['ana', 'cemaden']);
is_deeply($sl->{errors}, [], 'no error for rain gauges');
is_deeply([ map { $_->{network} . ':' . $_->{id} } @{$sl->{stations}} ], ['cemaden:19563', 'cemaden:19444', 'ana:41410000'],
    'CEMADEN gauges (rain gauges only) and active ANA stations, nearest first');
my ($cg) = @{$sl->{stations}};
is($cg->{approx_position}, 1, 'CEMADEN position is the municipality seat');
is($cg->{latest}{rain_96h}, 28.6, 'CEMADEN latest accumulations');
is($cg->{history_hours}, 96, 'CEMADEN history limit');
my ($ana) = grep { $_->{network} eq 'ana' } @{$sl->{stations}};
is($ana->{name}, "Jequitib\x{e1}", 'ANA names decoded as UTF-8 and title-cased');
is($wb->municipalities()->{3550308}{name}, "S\x{e3}o Paulo", 'municipality names decoded');
is($wb->municipalities()->{3167202}{uf}, 'MG', 'state of the municipality');

# ANA times are Brasilia time (UTC-3): 23:45 of the 14th is still the 14th
my $ana_xml = '<DataSet>';
for my $r (['2026-11-14 10:00:00', '2.40'], ['2026-11-14 23:45:00', '1.00'], ['2026-11-15 00:15:00', '0.60'], ['2026-11-14 11:00:00', '']) {
    $ana_xml .= "<DadosHidrometereologicos><CodEstacao>41410000</CodEstacao><DataHora>$r->[0] </DataHora><Nivel>200</Nivel><Chuva>$r->[1]</Chuva></DadosHidrometereologicos>";
}
$canned{'DadosHidrometeorologicos'} = $ana_xml . '</DataSet>';
my $ad = $wb->station_daily('ana', '41410000', -19.23, -44.03, 628, '2026-11-14', '2026-11-15');
is($ad->{rain_only}, 1, 'ANA is rain only');
my %ar = map { $_->{date} => $_->{rain} } @{$ad->{days}};
is($ar{'2026-11-14'}, 3.4, 'ANA rain summed in Brasilia days (empty readings ignored)');
is($ar{'2026-11-15'}, 0.6, 'ANA next day');
like($asked[-1], qr{codEstacao=41410000&dataInicio=13/11/2026&dataFim=16/11/2026}, 'ANA dates as dd/mm/yyyy, one extra day each side');

# CEMADEN hourly values are UTC: 02:00 UTC of the 15th = 23:00 of the 14th in Sete Lagoas
$canned{'AcumuladoResource'} = encode_json([
    { datahora => '2026-11-14 18:00:00', valor => '4.2' }, { datahora => '2026-11-15 02:00:00', valor => '1.0' },
    { datahora => '2026-11-15 04:00:00', valor => '0.4' },
]);
my $cd = $wb->station_daily('cemaden', '19563', -19.4569, -44.2413, undef, '2026-11-14', '2026-11-15');
my %cr = map { $_->{date} => $_->{rain} } @{$cd->{days}};
is($cr{'2026-11-14'}, 5.2, 'CEMADEN hours summed in local days');
is($cr{'2026-11-15'}, 0.4, 'CEMADEN next local day');
is($cd->{history_hours}, 96, 'CEMADEN daily says its history limit');
like($asked[-1], qr/est=19563&pag=\d+/, 'CEMADEN hourly request');



# ------------------------------------------------------------ SYNOP (national weather services)
my $ws = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1) });
my $m = $ws->parse_synop('AAXX 12063 63705 11560 73606 10203 20183 38900 48/// 60074 76162 8293/ 333 20183 58008 82620 81922 87360 555 10190=');
is($m->{ir}, '1', 'iR');
is_deeply($m->{rain}, [ { mm => 7, hours => 24 } ], 'section 1 rain group: 7 mm in 24 h');
is($m->{temp_c}, 20.3, 'temperature');
is($m->{dewpoint_c}, 18.3, 'dew point');
is($m->{tmin_c}, 18.3, 'section 3 minimum temperature');
is($m->{wind_kmh}, 11, 'wind 6 knots (iw = 3) to km/h');
is($m->{raining}, 1, 'present weather 61 = rain');
$m = $ws->parse_synop('AAXX 08184 65418 32460 31402 10330 20233 40090 83902 333 10385 58010 83612 81930 94582=');
is($m->{ir}, '3', 'iR = 3 (no rain)');
is($m->{tmax_c}, 38.5, 'section 3 maximum temperature');
is_deeply($m->{rain}, [], 'no rain group');
$m = $ws->parse_synop('AAXX 13004 84628 31460 61710 10253 20225 30089 40104 70221 875// 333 10289 56400 59002 81710 86650=');
is($m->{pressure_hpa}, 1010.4, 'sea level pressure');
$m = $ws->parse_synop('AAXX 01061 99999 02560 00000 11050 21070 40150 60001 333 21070 55300 20810 30200 69922 70125=');
is($m->{temp_c}, -5, 'negative temperature');
is_deeply($m->{rain}, [ { mm => 0, hours => 6 }, { mm => 0.2, hours => 12 } ], 'rain groups of sections 1 and 3 (990s = tenths)');
is($m->{rain24}, 12.5, '24-hour rain (section 3 group 7)');
ok(!defined $m->{tmin_c} || $m->{tmin_c} == -7, 'radiation groups after 55SSS are not read as temperatures');
ok($ws->parse_synop('AAXX 08034 65418 NIL=')->{nil}, 'NIL message');

# a station with 12-hour rain groups at 06 and 18 UTC (Uganda-like), in a UTC+3 area
my @syn;
for my $day (11, 12) {
    push @syn, "63680,2026,11,$day,06,00,AAXX ${day}061 63680 12560 00000 10200 20180 40130 6" . ($day == 11 ? '0052' : '0002') . " 333 20175=";
    push @syn, "63680,2026,11,$day,18,00,AAXX ${day}181 63680 12560 00000 10260 20180 40130 6" . ($day == 11 ? '0082' : '0002') . " 333 10295=";
    push @syn, "63680,2026,11,$day,12,00,AAXX ${day}121 63680 42560 00000 10280 20180 40130 333=";
}
%canned = ('getsynop' => join("\n", @syn) . "\n");
@asked = ();
my $sd = $ws->_synop_daily('63680', 0.33, 32.6, '2026-11-11', '2026-11-12');
my %sr = map { $_->{date} => $_ } @{$sd->{days}};
is($sr{'2026-11-11'}{rain}, 13, 'daily rain = 12 h groups at 06 and 18 UTC');
is($sr{'2026-11-12'}{rain}, 0, 'zero rain groups');
is($sr{'2026-11-11'}{tmax}, 29.5, 'SYNOP maximum');
is($sr{'2026-11-11'}{tmin}, 17.5, 'SYNOP minimum');
like($asked[0], qr/block=63680&begin=202611100000&end=202611132359/, 'OGIMET request with one day around');

# a station that never sends rain amounts (iR = 4)
%canned = ('getsynop' => "63791,2026,11,11,06,00,AAXX 11061 63791 42/89 /1202 10249 20180 39173 40164 333 20183 59018=\n"
    . "63791,2026,11,11,18,00,AAXX 11181 63791 42580 20707 10276 20169 39141 48532 82500 333 10339 59010 82626=\n");
$sd = $ws->_synop_daily('63791', -3.4, 37.07, '2026-11-11', '2026-11-11');
is($sd->{rain_reported}, 0, 'station without rain amounts flagged');
is($sd->{days}[0]{tmax}, 33.9, 'its temperatures are kept');

# WMO OSCAR positions, countries from the IEM network extents
%canned = (
    'networks.geojson' => encode_json({ features => [ { id => 'GH__ASOS', geometry => { coordinates => [[[-3, 4.5], [1, 4.5], [1, 11], [-3, 11]]] } } ] }),
    'territoryName=GHA' => encode_json({ stationSearchResults => [
        { name => 'TAMALE', wigosId => '0-20000-0-65418', latitude => 9.55, longitude => -0.85, elevation => 168.8, declaredStatus => 'Closed' },
        { name => 'ACCRA', wigosId => '0-20000-0-65472', latitude => 5.6, longitude => -0.17 },
        { name => 'ODD ID', wigosId => '0-288-0-1', latitude => 9.4, longitude => -0.85 },
    ] }),
);
my $gs = $ws->nearby_stations(9.40, -0.85, 200, ['synop']);
is_deeply([ map { $_->{id} } @{$gs->{stations}} ], ['65418'], 'SYNOP stations from OSCAR within range (WMO ids only, status ignored)');
is($gs->{stations}[0]{name}, 'Tamale', 'station name');

# ------------------------------------------------------------ CoCoRaHS (USA)
%canned = ('Station=NY-TM-51' => "ObservationDate,ObservationTime,EntryDateTime,StationNumber,StationName,Latitude,Longitude,TotalPrecipAmt,NewSnowDepth\n"
    . "2026-11-13, 07:00 AM, x, NY-TM-51, Ithaca 0.5 N, 42.45, -76.49, 0.94, 0\n"
    . "2026-11-12, 07:00 AM, x, NY-TM-51, Ithaca 0.5 N, 42.45, -76.49, T, 0\n"
    . "2026-11-11, 07:00 AM, x, NY-TM-51, Ithaca 0.5 N, 42.45, -76.49, NA, 0\n");
my $cc = $ws->station_daily('cocorahs', 'NY-TM-51', 42.45, -76.49, 250, '2026-11-11', '2026-11-13');
my %ccr = map { $_->{date} => $_->{rain} } @{$cc->{days}};
is($ccr{'2026-11-13'}, 23.9, 'CoCoRaHS inches to mm');
is($ccr{'2026-11-12'}, 0, 'trace = 0');
ok(!exists $ccr{'2026-11-11'}, 'missing reading left out');
like($asked[-1], qr{Station=NY-TM-51&StartDate=11/11/2026&EndDate=11/13/2026}, 'CoCoRaHS request');

# ------------------------------------------------------------ IDEAM (Colombia): 10-minute values, Colombian time, duplicates
%canned = ('s54a-sgyg.json' => encode_json([
    { fechaobservacion => '2026-11-08T18:10:00.000', valorobservado => '3.1' },
    { fechaobservacion => '2026-11-08T18:10:00.000', valorobservado => '3.1' },
    { fechaobservacion => '2026-11-08T23:50:00.000', valorobservado => '4.0' },
    { fechaobservacion => '2026-11-09T00:10:00.000', valorobservado => '0.5' },
]));
my $idd = $ws->station_daily('ideam', '0026075150', 3.54, -76.38, 960, '2026-11-08', '2026-11-09');
my %idr = map { $_->{date} => $_->{rain} } @{$idd->{days}};
is($idr{'2026-11-08'}, 7.1, 'IDEAM rain summed in Colombian days, duplicate reading counted once');
is($idr{'2026-11-09'}, 0.5, 'IDEAM next day');
like($asked[-1], qr/codigoestacion%3D%270026075150%27/, 'IDEAM query by station');

done_testing();

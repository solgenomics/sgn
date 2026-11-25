# Tests of the INMET historical files (portal.inmet.gov.br/dadoshistoricos) in
# CXGN::Weather, without network: a fake portal serves yearly zips built here,
# answering HEAD and HTTP Range requests like the real one.

use strict;
use warnings;
use utf8;

use Test::More;
use File::Temp qw(tempdir);
use Encode qw(encode);
use IO::Compress::Zip qw(zip $ZipError);
use HTTP::Response;
use LWP::UserAgent;
use CXGN::Weather;

# ------------------------------------------------------------ fake portal
# a real LWP::UserAgent whose requests never leave: a request_send handler answers them
my $fake = { zips => {}, mod => {}, log => [], down => 0 };
sub portal_answer {
    my $req = shift;
    my ($y) = $req->uri =~ m{/(\d{4})\.zip$};
    my $zip = $y ? $fake->{zips}{$y} : undef;
    if ($req->method eq 'HEAD') {
        push @{$fake->{log}}, 'HEAD ' . $req->uri;
        return HTTP::Response->new(500, 'down') if $fake->{down};
        return HTTP::Response->new(404, 'Not Found') if !defined $zip;
        return HTTP::Response->new(200, 'OK', ['Content-Length' => length($zip), 'Last-Modified' => $fake->{mod}{$y} // 'Thu, 05 Nov 2026 12:58:43 GMT']);
    }
    return HTTP::Response->new(500, 'down') if $fake->{down};
    return HTTP::Response->new(404, 'Not Found') if !defined $zip;
    my ($from, $to) = ($req->header('Range') // '') =~ /^bytes=(\d+)-(\d+)$/ or die 'full download asked: ' . $req->uri . "\n";
    push @{$fake->{log}}, 'GET ' . $req->uri . " $from-$to";
    return HTTP::Response->new(206, 'Partial Content', [], substr($zip, $from, $to - $from + 1));
}
my $ua = LWP::UserAgent->new();
$ua->add_handler(request_send => sub { my $r = portal_answer(shift); return $r });

my @t = gmtime();
my $this_year = $t[5] + 1900;
my $y = $this_year - 1;

# an hourly CSV like the INMET files (2019 on: YYYY/MM/DD, "0000 UTC"; before: YYYY-MM-DD, "00:00", -9999)
sub station_csv {
    my (%a) = @_;
    my $old = $a{old};
    my @lines = ("REGIAO:;SE", "UF:;MG", "ESTACAO:;$a{name}", "CODIGO (WMO):;$a{id}", "LATITUDE:;-19,45527777",
        "LONGITUDE:;-44,17333332", "ALTITUDE:;719", "DATA DE FUNDACAO:;10/06/16",
        ($old ? 'DATA (YYYY-MM-DD);HORA (UTC);' : 'Data;Hora UTC;')
        . 'PRECIPITAÇÃO TOTAL, HORÁRIO (mm);PRESSAO ATMOSFERICA AO NIVEL DA ESTACAO, HORARIA (mB);PRESSÃO ATMOSFERICA MAX.NA HORA ANT. (AUT) (mB);'
        . 'PRESSÃO ATMOSFERICA MIN. NA HORA ANT. (AUT) (mB);RADIACAO GLOBAL (' . ($old ? 'KJ' : 'Kj') . '/m²);TEMPERATURA DO AR - BULBO SECO, HORARIA (°C);'
        . 'TEMPERATURA DO PONTO DE ORVALHO (°C);TEMPERATURA MÁXIMA NA HORA ANT. (AUT) (°C);TEMPERATURA MÍNIMA NA HORA ANT. (AUT) (°C);'
        . 'TEMPERATURA ORVALHO MAX. NA HORA ANT. (AUT) (°C);TEMPERATURA ORVALHO MIN. NA HORA ANT. (AUT) (°C);UMIDADE REL. MAX. NA HORA ANT. (AUT) (%);'
        . 'UMIDADE REL. MIN. NA HORA ANT. (AUT) (%);UMIDADE RELATIVA DO AR, HORARIA (%);VENTO, DIREÇÃO HORARIA (gr) (° (gr));VENTO, RAJADA MAXIMA (m/s);'
        . 'VENTO, VELOCIDADE HORARIA (m/s);');
    foreach my $day (@{$a{days}}) {
        for my $h (0 .. 23) {
            my $local = ($h - 3) % 24;
            my $sun = ($local >= 6 && $local <= 18) ? 2500 * sin(3.14159 * ($local - 6) / 12) : 0;
            my $temp = 20 + $sun / 500;
            my $rain = ($day eq $a{rain_day} && $h == 20) ? '12,4' : ($day eq $a{rain_day} && $h == 21) ? ',6' : '0';
            my @v = ($rain, '931,8', '931,8', '931,2', ($sun > 0 ? sprintf('%.1f', $sun) : ($old ? '-9999' : '')), $temp, 15, $temp + 0.5, $temp - 0.5,
                16, 14, 80, 70, 75, 170, '5,5', 2);
            s/(\d)\.(\d)/$1,$2/ for @v;
            my $date = $old ? $day : join('/', split /-/, $day);
            push @lines, join(';', $date, $old ? sprintf('%02d:00', $h) : sprintf('%02d00 UTC', $h), @v) . ';';
        }
    }
    return encode('latin1', join("\r\n", @lines) . "\r\n");
}

sub year_zip {
    my (%files) = @_;
    my $zip;
    my $z = IO::Compress::Zip->new(\$zip, Name => 'x', Minimal => 1) or die $ZipError;
    foreach my $name (sort keys %files) {
        $z->newStream(Name => $name, Minimal => 1, Method => 8);
        $z->print($files{$name});
    }
    $z->close();
    # the first empty member 'x' is left in: the real zips also have other entries
    return $zip;
}

srand(42);
my $filler = join('', map { chr(int(rand(256))) } 1 .. 200_000);    # other stations (not compressible): the index is at the end of a large file
my $zip_y = year_zip(
    "INMET_SE_MG_A001_BRASILIA_01-01-${y}_A_31-12-${y}.CSV" => $filler,
    "INMET_SE_MG_A569_SETE LAGOAS_01-01-${y}_A_31-12-${y}.CSV" => station_csv(id => 'A569', name => 'SETE LAGOAS', days => ["$y-03-14", "$y-03-15", "$y-03-16"], rain_day => "$y-03-15"),
    "INMET_SE_MG_A570_OTHER_01-01-${y}_A_31-12-${y}.CSV" => station_csv(id => 'A570', name => 'OTHER', days => ["$y-03-15"], rain_day => ''),
);
$fake->{zips}{$y} = $zip_y;
my $dir = tempdir(CLEANUP => 1);
my $wx = CXGN::Weather->new({ cache_dir => $dir, inmet_files => 1, ua => $ua });

# ------------------------------------------------------------ switch
my $off = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1) });
is($off->networks->{inmet}{ready}, 0, 'inmet 0: INMET not readable');
like($off->networks->{inmet}{off_text}, qr/inmet 1/, 'inmet 0: the page says how to switch it on');
is($wx->networks->{inmet}{ready}, 1, 'inmet 1: INMET readable without a token');
ok(!exists $wx->networks->{inmet}{off_text}, 'inmet 1: no switch-on message');
eval { $off->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$y-03-15", "$y-03-15") };
like($@, qr/inmet 1/, 'switched off: clear message');

# ------------------------------------------------------------ one station from the yearly zip
my $d = $wx->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$y-03-15", "$y-03-15");
is(scalar(@{$d->{days}}), 1, 'one local day');
is($d->{days}[0]{date}, "$y-03-15", 'the asked day');
is($d->{days}[0]{rain}, 13, 'hourly rain summed (decimal commas, ",6" = 0.6)');
is($d->{days}[0]{et0_method}, 'PM', 'ET0 = Penman-Monteith');
ok($d->{days}[0]{radiation} > 15, 'daily radiation in MJ/m2');
ok(abs($d->{days}[0]{tmax} - 25.5) < 0.01 && abs($d->{days}[0]{tmin} - 19.5) < 0.01, 'max/min of the hourly max/min');
like($d->{note}, qr/historical files.*goes to $y-03-16/, 'note gives the last date of the file');

my @gets = grep { /^GET/ } @{$fake->{log}};
is(scalar(@gets), 2, 'two Range requests: zip index, then the station file');
my $bytes = 0;
foreach (@gets) { my ($a, $b) = /(\d+)-(\d+)$/; $bytes += $b - $a + 1; }
ok($bytes < length($zip_y) / 2, "only part of the zip downloaded ($bytes of " . length($zip_y) . ' bytes)');

# cached: nothing asked again (the version of the zip is cached for a day)
@{$fake->{log}} = ();
$wx->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$y-03-14", "$y-03-16");
is(scalar(@{$fake->{log}}), 0, 'second read from the cache');

# another station of the same year: the zip index is reused
$wx->station_daily('inmet', 'A570', -19.455, -44.173, 719, "$y-03-15", "$y-03-15");
is(scalar(grep { /^GET/ } @{$fake->{log}}), 1, 'other station: only its file is downloaded');

# a new month posted (new Last-Modified, new size): downloaded again
@{$fake->{log}} = ();
$fake->{zips}{$y} = $zip_y . '';
$fake->{mod}{$y} = 'Fri, 04 Dec 2026 12:00:00 GMT';
unlink glob("$dir/inmet_head_*");
my $again = $wx->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$y-03-15", "$y-03-15");
is(scalar(grep { /^GET/ } @{$fake->{log}}), 2, 'new version of the zip: index and file downloaded again');
is($again->{days}[0]{rain}, 13, 'same values');

# portal down: the copy we have, flagged stale
unlink glob("$dir/inmet_head_*");
$fake->{down} = 1;
my $stale = CXGN::Weather->new({ cache_dir => $dir, inmet_files => 1, ua => $ua })->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$y-03-15", "$y-03-15");
is($stale->{days}[0]{rain}, 13, 'portal down: cached copy used');
ok($stale->{stale}, 'portal down: flagged stale');
$fake->{down} = 0;

# station without a file that year, and a year without zip (404): no error, no days
my $none = $wx->station_daily('inmet', 'A999', -19.455, -44.173, 719, "$y-03-15", "$y-03-15");
is(scalar(@{$none->{days}}), 0, 'station not in the zip: no days');
my $no_zip = $wx->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$this_year-01-02", "$this_year-01-03");
is(scalar(@{$no_zip->{days}}), 0, 'year without zip: no days');

# older than 5 years: not read at all
@{$fake->{log}} = ();
my $old_y = $this_year - 6;
my $too_old = $wx->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$old_y-03-15", "$old_y-03-15");
is(scalar(@{$too_old->{days}}), 0, 'older than 5 years: no days');
is(scalar(@{$fake->{log}}), 0, 'older than 5 years: nothing asked');

# several years in one request: read at the same time, all days there
my $y2 = $this_year - 2;
$fake->{zips}{$y2} = year_zip("INMET_SE_MG_A569_SETE LAGOAS_01-01-${y2}_A_31-12-${y2}.CSV" => station_csv(id => 'A569', name => 'SETE LAGOAS', days => ["$y2-12-30", "$y2-12-31"], rain_day => "$y2-12-31"));
$fake->{zips}{$y} = year_zip("INMET_SE_MG_A569_SETE LAGOAS_01-01-${y}_A_31-12-${y}.CSV" => station_csv(id => 'A569', name => 'SETE LAGOAS', days => ["$y-01-01", "$y-01-02"], rain_day => ''));
$fake->{mod}{$y} = 'Sat, 05 Dec 2026 12:00:00 GMT';
unlink glob("$dir/inmet_head_*");
my $two = $wx->station_daily('inmet', 'A569', -19.455, -44.173, 719, "$y2-12-31", "$y-01-01");
is_deeply([ map { $_->{date} } @{$two->{days}} ], [ "$y2-12-31", "$y-01-01" ], 'days across two yearly files');
is($two->{days}[0]{rain}, 13, 'rain of the first year');

# files before 2019: other header, dates YYYY-MM-DD, hours HH:MM, -9999 = missing
my $old_rows = CXGN::Weather::_inmet_parse_csv(station_csv(id => 'A569', name => 'SETE LAGOAS', days => ['2018-03-15'], rain_day => '2018-03-15', old => 1));
is(scalar(@$old_rows), 24, 'old format: 24 hours');
ok(!defined $old_rows->[0]{rad_kj}, 'old format: -9999 is missing');
is($old_rows->[20]{rain_mm}, 12.4, 'old format: rain read');
is(scalar(gmtime($old_rows->[20]{time})), 'Thu Mar 15 20:00:00 2018', 'old format: hour in UTC');
is($old_rows->[20]{gust_kmh}, 20, 'gust m/s to km/h');

done_testing();

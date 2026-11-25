
# CXGN::Weather::Local: parse, check, store and read the data of uploaded
# (local) weather stations. No request to the weather services.

use strict;
use warnings;

use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use SGN::Test::Fixture;
use CXGN::Weather;
use CXGN::Weather::Local;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dir = tempdir(CLEANUP => 1);
my $wx = CXGN::Weather->new({ cache_dir => $dir });
my $local = CXGN::Weather::Local->new({ schema => $schema });

my $loc = $schema->resultset('NaturalDiversity::NdGeolocation')->find({ description => 'test_location' });
ok($loc, 'fixture location');
my $loc_id = $loc->nd_geolocation_id;
my ($old_lat, $old_lon, $old_alt) = ($loc->latitude, $loc->longitude, $loc->altitude);
$loc->update({ latitude => -22.70, longitude => -47.62, altitude => 580 });

my @created;
END {
    local $?;
    eval { $local->delete_station($_) for @created; 1 } or diag("could not delete the test stations: $@");
    eval { $loc->update({ latitude => $old_lat, longitude => $old_lon, altitude => $old_alt }) if $loc; 1 }
        or diag("could not restore test_location: $@");
    eval { $f->clean_up_db(); 1 } or diag("clean_up_db failed: $@");
}

my $n = 0;
sub csv {
    my $file = "$dir/upload_" . ++$n . '.csv';
    open(my $fh, '>', $file) or die $!;
    print $fh @_;
    close($fh);
    return $file;
}

# ------------------------------------------------------------------ daily file
my $file = csv(<<'CSV');
location_name,station_name,date,tmax,tmin,tmean,rain_mm,rh,wind_ms,radiation_mj
test_location,Farm station,2026-03-01,31.2,19.8,24.9,12.4,78,1.9,21.3
test_location,Farm station,2026-03-02,30.5,20.1,,0,74,2.3,23.8
test_location,Farm station,2026-03-03,29.0,18.5,23.0,"3,5",,,
CSV
my $p = $local->parse_file($file);
is_deeply($p->{errors}, [], 'daily file without errors');
is($p->{resolution}, 'daily', 'daily');
is(scalar @{$p->{stations}}, 1, 'one station');
my $st = $p->{stations}[0];
is($st->{location}{id}, $loc_id, 'location found by name');
is(scalar keys %{$st->{days}}, 3, 'three days');
is($st->{days}{'2026-03-03'}{rain}, 3.5, 'decimal comma read');
ok(!defined $st->{days}{'2026-03-03'}{rh}, 'empty cell = not measured');

my $res = $local->store($p, { sp_person_id => 41, archived_file => $file });
my ($s) = @{$res->{stations}};
push @created, $s->{id};
like($s->{id}, qr/^L\d+$/, 'station id L<n>');
is($s->{inserted}, 3, '3 days inserted');
is($s->{replaced}, 0, 'nothing replaced');

# upload again: new days added, stored days replaced; case of the name ignored
$file = csv("location_name,station_name,date,rain_mm,tmax,tmin\ntest_location,farm STATION,2026-03-03,7.0,28,18\ntest_location,Farm station,2026-03-04,0,30,19\n");
$p = $local->parse_file($file, { location_id => $loc_id, station_name => 'Farm Station' });
is_deeply($p->{errors}, [], 'rows of the location and station of the form (case ignored)');
$res = $local->store($p, { sp_person_id => 41 });
is($res->{stations}[0]{id}, $s->{id}, 'same station');
is($res->{stations}[0]{inserted}, 1, '1 new day');
is($res->{stations}[0]{replaced}, 1, '1 day replaced');

my ($info) = @{$local->stations({ location_id => $loc_id })};
is($info->{days}, 4, '4 days stored');
is($info->{first}, '2026-03-01', 'first day');
is($info->{last}, '2026-03-04', 'last day');
is($info->{has_temp}, 1, 'measures temperature');
is($info->{has_radiation}, 1, 'measures radiation');
is($info->{lat} + 0, -22.7, 'position of the location');

# ------------------------------------------------------------------ read
my $daily = $local->station_daily($wx, $s->{id}, -22.7, -47.62, 580, '2026-03-01', '2026-03-31');
is(scalar @{$daily->{days}}, 4, 'daily data');
my %d = map { $_->{date} => $_ } @{$daily->{days}};
is($d{'2026-03-03'}{rain}, 7, 'replaced value');
is($d{'2026-03-01'}{et0_method}, 'PM', 'Penman-Monteith with radiation, humidity and wind');
is($d{'2026-03-04'}{et0_method}, 'HS', 'Hargreaves without them');
is($d{'2026-03-02'}{tmean}, 20.1 + (30.5 - 20.1) / 2, 'tmean from max and min when missing');
is($daily->{rain_reported}, 1, 'rain reported');

my $near = $local->nearby_stations($wx, -22.75, -47.60, 50);
my ($found) = grep { $_->{id} eq $s->{id} } @$near;
ok($found, 'station found within 50 km');
is($found->{network}, 'local', 'network local');
ok($found->{ready}, 'ready');
is($found->{rain_only}, 0, 'not only rain');
ok(!grep({ $_->{id} eq $s->{id} } @{$local->nearby_stations($wx, 10, 10, 50)}), 'not found far away');

# ------------------------------------------------------------------ errors (nothing stored)
my $err = sub { my ($content, $opt) = @_; return join("\n", @{$local->parse_file(csv($content), $opt)->{errors}}) };
like($err->("location_name,station_name,date,rain_mm\nNowhere Farm,S1,2026-03-01,1\n"), qr/does not exist in the database/, 'unknown location');
like($err->("station_name,date,rain_mm\nS1,2026-03-01,1\n"), qr/location/, 'location needed');
like($err->("location_name,date,rain_mm\ntest_location,2026-03-01,1\n"), qr/needs the columns station_name/, 'station_name column required');
like($err->("date,rain_mm\n2026-03-01,1\n", { location_id => $loc_id, station_name => 'S1' }), qr/needs the columns location_name, station_name/,
    'columns required even when the form gives location and station');
like($err->("location_name,station_name,date,rain_mm\ntest_location,,2026-03-01,1\n"), qr/station_name is empty/, 'empty station_name');
like($err->("location_name,station_name,date,rain_mm\n,S1,2026-03-01,1\n"), qr/location_name is empty/, 'empty location_name');
like($err->("location_name,station_name,date,rain_mm\ntest_location,S2,2026-03-01,1\n", { location_id => $loc_id, station_name => 'S1' }),
    qr/'S2' is not S1, the station chosen/, 'other station than the one of the form');
like($err->("location_name,station_name,date,tmax,tmin\ntest_location,S1,2026-03-01,18,25\n"), qr/tmin \(25\) is above tmax/, 'tmin above tmax');
like($err->("location_name,station_name,date,tmax\ntest_location,S1,2026-03-01,85\n"), qr/out of the plausible range/, 'implausible value');
like($err->("location_name,station_name,date,rain_mm\ntest_location,S1,2026-03-01,abc\n"), qr/not a number/, 'not a number');
like($err->("location_name,station_name,date,rain_mm\ntest_location,S1,2026-03-01,1\ntest_location,S1,2026-03-01,2\n"), qr/already has a row/, 'duplicated day');
like($err->("location_name,station_name,date,rain_mm\ntest_location,S1,2099-03-01,1\n"), qr/future/, 'future date');
like($err->("location_name,station_name,date,rain_mm\ntest_location,S1,2026-02-30,1\n"), qr/does not exist/, 'impossible date');
like($err->("location_name,station_name,date,rain_mm\ntest_location,S1,03/04/2026,1\n"), qr/YYYY-MM-DD/, 'ambiguous day/month');
like($err->("location_name,station_name,date,rain_mm\ntest_location,S1,2026-03-01,1\n", { location_id => 999999999 }), qr/not found/, 'unknown location of the form');
like($err->("location_name,station_name,date,foo\ntest_location,S1,2026-03-01,1\n"), qr/no weather column/, 'no weather column');
like($err->("location_name,station_name,date,time,temp\ntest_location,S1,2026-03-01,10:00,25\n"), qr/daily data only/, 'sub-daily rows refused by default');

# DD/MM/YYYY found from the file
$p = $local->parse_file(csv("location_name,station_name,date,rain_mm\ntest_location,S1,13/03/2026,1\ntest_location,S1,02/03/2026,2\n"));
is_deeply($p->{errors}, [], 'DD/MM/YYYY read');
ok($p->{stations}[0]{days}{'2026-03-02'}, '02/03/2026 = 2 March');

# ------------------------------------------------------------------ sub-daily
my $rows = "location_name,station_name,date,time,temp,rain_mm,rh,wind_ms,radiation_wm2\n";
foreach my $h (0 .. 23) {
    $rows .= sprintf("test_location,Logger,2026-03-05,%02d:00,%.1f,%s,80,2,%d\n", $h, 20 + ($h > 12 ? 24 - $h : $h) / 2, $h == 15 ? '4.2' : '0', ($h >= 6 && $h <= 18) ? 500 : 0);
}
$rows .= "test_location,Logger,2026-03-06,00:00,19,0,80,2,0\n";    # 1 record: incomplete day
$p = $local->parse_file(csv($rows), { resolution => 'subdaily' });
is_deeply($p->{errors}, [], 'sub-daily file accepted when allowed');
is($p->{resolution}, 'subdaily', 'sub-daily');
my $days = $p->{stations}[0]{days};
is($days->{'2026-03-05'}{tmax}, 26, 'max of the day');
is($days->{'2026-03-05'}{tmin}, 20, 'min of the day');
is(sprintf('%.1f', $days->{'2026-03-05'}{rain}), '4.2', 'rain summed');
is($days->{'2026-03-05'}{n_records}, 24, '24 records');
is($days->{'2026-03-05'}{complete}, 1, 'complete day');
is($days->{'2026-03-06'}{complete}, 0, 'incomplete day');
ok(scalar(grep { /less than 80%/ } @{$p->{warnings}}), 'warning for the incomplete day');
$res = $local->store($p, { sp_person_id => 41 });
push @created, $res->{stations}[0]{id};
$daily = $local->station_daily($wx, $res->{stations}[0]{id}, -22.7, -47.62, 580, '2026-03-05', '2026-03-06');
%d = map { $_->{date} => $_ } @{$daily->{days}};
ok(!defined $d{'2026-03-06'}{tmax}, 'incomplete day left empty');
ok(defined $d{'2026-03-05'}{radiation}, 'radiation from W/m2');

# ------------------------------------------------------------------ delete
ok($local->delete_station($s->{id}), 'deleted');
is(scalar @{$local->stations({ station_id => $s->{id} })}, 0, 'station gone');
is($schema->storage->dbh->selectrow_array('SELECT count(*) FROM local_weather_daily WHERE local_weather_station_id = ?', undef, $local->db_id($s->{id})), 0, 'its days gone');

done_testing();

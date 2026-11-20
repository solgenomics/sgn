
# CXGN::Weather::station_daily: a day is complete (max/min and ET0 given)
# when 16 distinct hours were observed, whatever the interval of the records.
# The hourly reader is replaced by canned records: no network.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use Time::Local qw(timegm);
use CXGN::Weather;

my @records;
{
    no warnings 'redefine';
    *CXGN::Weather::_iem_hourly = sub { return [ @records ] };
}
my $wx = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1) });

# records every $step minutes from $from_h (inclusive) to $to_h (exclusive), UTC (longitude 0 = UTC days)
sub records {
    my ($day, $from_h, $to_h, $step) = @_;
    my @r;
    for (my $m = $from_h * 60; $m < $to_h * 60; $m += $step) {
        push @r, { time => timegm(0, $m % 60, int($m / 60), $day, 9, 2026), temp_c => 15 + $m / 120 };
    }
    return @r;
}

sub day_of {
    my $res = $wx->station_daily('airport', 'TEST', 0, 0, 0, '2026-10-01', '2026-10-31');
    my %d = map { $_->{date} => $_ } @{$res->{days}};
    return \%d;
}

# 10-minute records during 3 hours: 18 records, but only 3 hours of the day
@records = records(5, 9, 12, 10);
my $d = day_of()->{'2026-10-05'};
is($d->{hours}, 18, '18 records');
is($d->{complete}, 0, '3 hours of 10-minute records: not complete');
ok(!defined $d->{tmax} && !defined $d->{tmin}, 'no max/min');
ok(!defined $d->{et0}, 'no ET0');

# 10-minute records during 16 hours: complete
@records = records(6, 4, 20, 10);
$d = day_of()->{'2026-10-06'};
is($d->{complete}, 1, '16 hours of 10-minute records: complete');
ok(defined $d->{tmax} && $d->{tmax} > $d->{tmin}, 'max and min');
is($d->{et0_method}, 'HS', 'ET0');

# hourly records: 15 hours are not enough, 24 are
@records = records(7, 0, 15, 60);
is(day_of()->{'2026-10-07'}{complete}, 0, '15 hourly records: not complete');
@records = records(8, 0, 24, 60);
is(day_of()->{'2026-10-08'}{complete}, 1, '24 hourly records: complete');

# several reports in the same hour (special reports) count as one hour
@records = (records(9, 0, 8, 60), map { records(9, $_, $_ + 1, 6) } 8 .. 9);
$d = day_of()->{'2026-10-09'};
ok($d->{hours} >= 16, "$d->{hours} records");
is($d->{complete}, 0, 'but only 10 distinct hours: not complete');

done_testing();

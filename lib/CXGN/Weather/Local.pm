package CXGN::Weather::Local;

=head1 NAME

CXGN::Weather::Local - weather data that users upload from their own stations

=head1 SYNOPSIS

  my $local = CXGN::Weather::Local->new({ schema => $bcs_schema });

  # read and check a CSV / Excel file (nothing is stored yet)
  my $parsed = $local->parse_file($file, {
      location_id => $id,             # optional: rows without location_name go here
      station_name => 'Farm station', # optional: rows without station_name get this name
      resolution => 'daily',          # 'daily' (one row per day) or 'subdaily' (also hourly / 15-min rows)
  });
  die join("\n", @{$parsed->{errors}}) if @{$parsed->{errors}};

  # store it: new days are added, days already stored are replaced
  my $res = $local->store($parsed, { sp_person_id => $id, archived_file => $path });

  # stations within a range, in the format of CXGN::Weather::nearby_stations
  my $list = $local->nearby_stations($wx, $lat, $lon, 200);

  # daily data, in the format of CXGN::Weather::station_daily
  my $daily = $local->station_daily($wx, 'L12', $lat, $lon, $elev, '2026-01-01', '2026-06-30');

=head1 DESCRIPTION

A research farm often has its own weather station: its data are uploaded as a
file and become the network 'local' of the Weather page. Each station
belongs to a Breedbase location (nd_geolocation) and has a name, unique in
that location. Tables: local_weather_station and local_weather_daily (db
patch AddLocalWeatherStationTables). Only daily values are stored: sub-daily
files (when the configuration allows them) are summarized per day on upload.

File columns (header names are not case sensitive; aliases in %ALIASES):

  location_name   name of a Breedbase location (or chosen in the upload form)
  station_name    name of the station (or typed in the upload form)
  date            YYYY-MM-DD (also DD/MM/YYYY or MM/DD/YYYY when the file shows which)
  time            HH:MM, sub-daily files only (or date and time together in 'datetime')
  tmax, tmin, tmean   air temperature, degrees C (daily files)
  temp            air temperature of the record, degrees C (sub-daily files)
  rain_mm         rain, mm
  rh              relative humidity, %
  wind_ms         mean wind speed, m/s
  radiation_mj    solar radiation, MJ/m2 (of the day, or of the record when sub-daily)
  radiation_wm2   mean solar irradiance, W/m2
  station_latitude, station_longitude, station_elevation   when the station is not at the location's position

Times are local times of the station.

=head1 AUTHOR

Chris Simoes

=cut

use Moose;
use Try::Tiny;
use POSIX qw(floor);
use Time::Local qw(timegm);
use List::Util qw(max min sum);
use CXGN::File::Parse;

has 'schema' => (isa => 'Bio::Chado::Schema', is => 'ro', required => 1);

# the network name of the uploaded stations and the prefix of their ids
our $NETWORK = 'local';
my $ID_PREFIX = 'L';

my @COLUMNS = qw(location_name station_name date time datetime tmax tmin tmean temp rain_mm rh wind_ms radiation_mj radiation_wm2
    station_latitude station_longitude station_elevation);

my %ALIASES = (
    location_name => ['location', 'location name', 'research_station'],
    station_name => ['station', 'station name', 'weather_station'],
    date => ['day', 'obs_date', 'data'],
    time => ['hour', 'hora', 'obs_time'],
    datetime => ['date_time', 'timestamp', 'date time'],
    tmax => ['tmax_c', 'temp_max', 'max_temp', 'temperature_max', 'max_temperature'],
    tmin => ['tmin_c', 'temp_min', 'min_temp', 'temperature_min', 'min_temperature'],
    tmean => ['tmean_c', 'tavg', 'temp_mean', 'mean_temp', 'temperature_mean', 'mean_temperature'],
    temp => ['temp_c', 'temperature', 'air_temp', 'air_temperature'],
    rain_mm => ['rain', 'rainfall', 'precipitation', 'precip', 'prcp', 'precipitation_mm', 'chuva'],
    rh => ['rh_pct', 'humidity', 'relative_humidity'],
    wind_ms => ['wind', 'wind_speed', 'wind_speed_ms'],
    radiation_mj => ['radiation', 'solar_radiation', 'srad', 'radiation_mj_m2'],
    radiation_wm2 => ['irradiance', 'solar_radiation_wm2', 'radiation_w_m2'],
    station_latitude => ['latitude', 'lat'],
    station_longitude => ['longitude', 'lon', 'long'],
    station_elevation => ['elevation', 'altitude', 'elev'],
);

# plausible ranges; values outside are errors (a wrong unit or a typo)
my %RANGE = (
    tmax => [-60, 60], tmin => [-60, 60], tmean => [-60, 60], temp => [-60, 60],
    rain_mm => [0, 1000], rh => [0, 100], wind_ms => [0, 75],
    radiation_mj => [0, 50], radiation_wm2 => [0, 1500],
    station_latitude => [-90, 90], station_longitude => [-180, 180], station_elevation => [-500, 9000],
);
my %LABEL = (
    tmax => 'tmax (C)', tmin => 'tmin (C)', tmean => 'tmean (C)', temp => 'temp (C)', rain_mm => 'rain_mm', rh => 'rh (%)',
    wind_ms => 'wind_ms (m/s)', radiation_mj => 'radiation_mj (MJ/m2)', radiation_wm2 => 'radiation_wm2 (W/m2)',
    station_latitude => 'station_latitude', station_longitude => 'station_longitude', station_elevation => 'station_elevation (m)',
);
my $MAX_ERRORS = 40;

=head2 template_columns($resolution)

The columns of the upload template ('daily' or 'subdaily').

=cut

sub template_columns {
    my ($self, $resolution) = @_;
    return ($resolution // '') eq 'subdaily'
        ? [qw(location_name station_name date time temp rain_mm rh wind_ms radiation_wm2)]
        : [qw(location_name station_name date tmax tmin tmean rain_mm rh wind_ms radiation_mj)];
}

# ------------------------------------------------------------------ values

sub _number {
    my $v = shift;
    return (undef, 1) if !defined $v;
    $v =~ s/^\s+|\s+$//g;
    return (undef, 1) if $v eq '' || $v =~ /^(na|n\/a|nan|null|-|--|\.)$/i;
    $v =~ s/^(-?\d+),(\d+)$/$1.$2/;    # decimal comma
    return ($v + 0, 1) if $v =~ /^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/;
    return (undef, 0);
}

sub _valid_ymd {
    my ($y, $m, $d) = @_;
    return 0 if $m < 1 || $m > 12 || $d < 1 || $d > 31;
    return eval { timegm(0, 0, 12, $d, $m - 1, $y); 1 } ? 1 : 0;
}

# split a date (with or without a time) into its parts. Returns a hash:
# { y, m, d, min (minutes of the day or undef) } for unambiguous dates, or
# { a, b, y, min } when the order of day and month is not known yet.
sub _date_parts {
    my $v = shift;
    return if !defined $v;
    $v =~ s/^\s+|\s+$//g;
    return if $v eq '';
    my $minutes = sub {
        my ($h, $mi, $ampm) = @_;
        return if !defined $h;
        if ($ampm) { $h = $h % 12; $h += 12 if lc($ampm) eq 'pm'; }
        return if $h > 24 || $mi > 59;
        return $h * 60 + $mi;
    };
    # Excel serial number (a date cell read without its format)
    if ($v =~ /^(\d{5})(\.\d+)?$/ && $1 > 20000 && $1 < 80000) {
        my @t = gmtime(($1 - 25569) * 86400);
        my $min = $2 ? floor($2 * 1440 + 0.5) : undef;
        $min = undef if defined $min && $min >= 1440;
        return { y => $t[5] + 1900, m => $t[4] + 1, d => $t[3], min => $min };
    }
    my $time = qr/(?:[T\s,]+(\d{1,2})(?::|h)(\d{2})(?::\d{2}(?:\.\d+)?)?\s*([AaPp][Mm])?)?\s*(?:Z|[+-]\d\d:?\d\d)?/;
    if ($v =~ /^(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})$time$/) {
        return { y => $1, m => $2 + 0, d => $3 + 0, min => scalar($minutes->($4, $5, $6)), has_time => defined $4 ? 1 : 0 };
    }
    if ($v =~ /^(\d{1,2})[-\/.](\d{1,2})[-\/.](\d{4}|\d{2})$time$/) {
        my $y = length($3) == 2 ? 2000 + $3 : $3;
        return { a => $1 + 0, b => $2 + 0, y => $y, min => scalar($minutes->($4, $5, $6)), has_time => defined $4 ? 1 : 0 };
    }
    return { bad => 1 };
}

sub _time_minutes {
    my $v = shift;
    return if !defined $v;
    $v =~ s/^\s+|\s+$//g;
    return if $v eq '';
    # Excel time fraction
    if ($v =~ /^0?\.\d+$/ || $v eq '0') { my $m = floor($v * 1440 + 0.5); return $m < 1440 ? $m : undef; }
    if ($v =~ /^(\d{1,2})(?::|h)?(\d{2})(?::\d{2})?\s*([AaPp][Mm])?\s*(?:UTC|Z)?$/) {
        my ($h, $mi) = ($1, $2);
        if ($3) { $h = $h % 12; $h += 12 if lc($3) eq 'pm'; }
        return if $h > 24 || $mi > 59;
        return $h * 60 + $mi;
    }
    return if $v !~ /^\d{1,2}$/;
    return $v <= 24 ? $v * 60 : undef;    # just the hour
}

# nd_geolocation keeps coordinates as real (float4): -22.7 comes back as -22.7000007629395
sub _round {
    my ($v, $d) = @_;
    return defined $v ? sprintf("%.${d}f", $v) + 0 : undef;
}

sub _iso {
    my ($y, $m, $d) = @_;
    return sprintf('%04d-%02d-%02d', $y, $m, $d);
}

sub _today {
    my @t = localtime;
    return _iso($t[5] + 1900, $t[4] + 1, $t[3]);
}

# ------------------------------------------------------------------ locations

sub _location_by_id {
    my ($self, $id) = @_;
    return if !$id || $id !~ /^\d+$/;
    my $row = $self->schema->resultset('NaturalDiversity::NdGeolocation')->find({ nd_geolocation_id => $id });
    return $row ? { id => $row->nd_geolocation_id, name => $row->description, lat => $row->latitude, lon => $row->longitude, elev => $row->altitude } : undef;
}

sub _location_by_name {
    my ($self, $name, $cache) = @_;
    return $cache->{$name} if exists $cache->{$name};
    my $rs = $self->schema->resultset('NaturalDiversity::NdGeolocation');
    my @rows = $rs->search({ description => $name })->all;
    @rows = $rs->search(\[ 'lower(description) = lower(?)', $name ])->all if !@rows;
    my $loc = @rows == 1 ? { id => $rows[0]->nd_geolocation_id, name => $rows[0]->description, lat => $rows[0]->latitude,
        lon => $rows[0]->longitude, elev => $rows[0]->altitude } : undef;
    $cache->{$name} = $loc;
    return $loc;
}

# ------------------------------------------------------------------ parse

=head2 parse_file($file, \%opt)

Reads and checks a CSV, XLS or XLSX file. The columns location_name and
station_name are required (a value in every row). Options: location_id and
station_name (when given, every row must be of that location / station),
resolution ('daily', the default, or 'subdaily'), type (file
type when the extension does not say it). Returns { errors => [...],
warnings => [...], stations => [ { location, name, lat, lon, elev, days =>
{ date => {...} } } ], resolution => 'daily'|'subdaily', rows => N }.
Nothing is stored.

=cut

sub parse_file {
    my ($self, $file, $opt) = @_;
    $opt ||= {};
    my $allow_subdaily = ($opt->{resolution} // 'daily') eq 'subdaily';
    my (@errors, @warnings);
    my $err = sub { push @errors, shift if @errors < $MAX_ERRORS; $errors[$MAX_ERRORS - 1] = 'Too many errors: only the first ones are shown.' if @errors >= $MAX_ERRORS; };
    my $fail = sub { return { errors => [ @_ ], warnings => [], stations => [], rows => 0 } };

    my %args = (file => $file, optional_columns => \@COLUMNS, column_aliases => \%ALIASES);
    $args{type} = $opt->{type} if $opt->{type};
    my $parsed = try { CXGN::File::Parse->new(%args)->parse() } catch { { errors => [ "The file could not be read: $_" ] } };
    return $fail->(@{$parsed->{errors}}) if @{$parsed->{errors} || []};
    my %has = map { $_ => 1 } @{$parsed->{columns} || []};
    my $rows = $parsed->{data} || [];
    return $fail->('The file has no data rows.') if !@$rows;
    return $fail->('The file needs a "date" column (or "datetime").') if !$has{date} && !$has{datetime};
    my @measures = grep { $has{$_} } qw(tmax tmin tmean temp rain_mm rh wind_ms radiation_mj radiation_wm2);
    return $fail->('The file has no weather column. Use the columns of the template: tmax, tmin, tmean, rain_mm, rh, wind_ms, radiation_mj'
        . ($allow_subdaily ? ' (or temp, radiation_wm2 for hourly data)' : '') . '.') if !@measures;
    my %known = map { $_ => 1 } @COLUMNS;
    my @unknown = grep { !$known{$_} } @{$parsed->{columns} || []};
    push @warnings, 'Columns not used: ' . join(', ', @unknown) . '.' if @unknown;

    my $default_loc = $opt->{location_id} ? $self->_location_by_id($opt->{location_id}) : undef;
    return $fail->('The location of the upload was not found.') if $opt->{location_id} && !$default_loc;
    my $only_station = $opt->{station_name} // '';
    $only_station =~ s/^\s+|\s+$//g;
    my @missing = grep { !$has{$_} } qw(location_name station_name);
    return $fail->('The file needs the columns ' . join(', ', @missing) . ' (see the data template).') if @missing;

    # 1st pass: dates (the order of day and month is found from the whole file)
    my ($dmy, $mdy, $ambiguous) = (0, 0, 0);
    foreach my $r (@$rows) {
        my $p = _date_parts($r->{datetime} // $r->{date});
        $r->{_dt} = $p;
        next if !$p || $p->{bad} || !exists $p->{a};
        if ($p->{a} > 12 && $p->{b} <= 12) { $dmy++ }
        elsif ($p->{b} > 12 && $p->{a} <= 12) { $mdy++ }
        else { $ambiguous++ }
    }
    return $fail->('The dates mix DD/MM/YYYY and MM/DD/YYYY. Write all dates as YYYY-MM-DD.') if $dmy && $mdy;
    return $fail->('The dates can be read as DD/MM/YYYY or as MM/DD/YYYY. Write them as YYYY-MM-DD.') if $ambiguous && !$dmy && !$mdy;
    push @warnings, 'Dates read as ' . ($dmy ? 'DD/MM/YYYY' : 'MM/DD/YYYY') . '.' if $dmy || $mdy;

    my $today = _today();
    my (%loc_cache, %stations, %seen, $subdaily, $daily_rows);
    my $time_col = $has{time};
    foreach my $r (@$rows) {
        my $line = 'Row ' . ($r->{_row} // '?');
        my $p = $r->{_dt};
        my $raw_date = $r->{datetime} // $r->{date};
        if (!$p) { $err->("$line: the date is empty."); next; }
        if ($p->{bad}) { $err->("$line: the date '$raw_date' is not valid (use YYYY-MM-DD)."); next; }
        my ($y, $m, $d) = exists $p->{a} ? ($p->{y}, $dmy ? ($p->{b}, $p->{a}) : ($p->{a}, $p->{b})) : ($p->{y}, $p->{m}, $p->{d});
        if (!_valid_ymd($y, $m, $d)) { $err->("$line: the date '$raw_date' does not exist."); next; }
        my $date = _iso($y, $m, $d);
        if ($date gt $today) { $err->("$line: the date $date is in the future."); next; }

        my $min = $p->{min};
        if ($time_col && defined $r->{time} && $r->{time} ne '') {
            $min = _time_minutes($r->{time});
            if (!defined $min) { $err->("$line: the time '$r->{time}' is not valid (use HH:MM)."); next; }
        }
        elsif (defined $p->{has_time} && $p->{has_time} && !defined $min) { $err->("$line: the time in '$raw_date' is not valid."); next; }
        if (defined $min) {
            if (!$allow_subdaily) {
                return $fail->('This site accepts daily data only: one row per day, without a time (setting weather_upload_resolution). Summarize the records per day first.');
            }
            $subdaily = 1;
        }
        else { $daily_rows = 1; }

        my $lname = $r->{location_name} // '';
        if ($lname eq '') { $err->("$line: location_name is empty (required)."); next; }
        my $loc = $self->_location_by_name($lname, \%loc_cache);
        if (!$loc) { $err->("$line: the location '$lname' does not exist in the database (add it in Manage > Locations)."); next; }
        if ($default_loc && $loc->{id} != $default_loc->{id}) { $err->("$line: the location '$lname' is not $default_loc->{name}, the location of this upload."); next; }
        my $sname = $r->{station_name} // '';
        $sname =~ s/^\s+|\s+$//g;
        if ($sname eq '') { $err->("$line: station_name is empty (required)."); next; }
        if ($only_station ne '' && lc($sname) ne lc($only_station)) { $err->("$line: the station '$sname' is not $only_station, the station chosen for this upload."); next; }
        if (length($sname) > 200) { $err->("$line: the station name is longer than 200 characters."); next; }

        my %val;
        my $ok = 1;
        foreach my $k (@measures, grep { $has{$_} } qw(station_latitude station_longitude station_elevation)) {
            my ($v, $good) = _number($r->{$k});
            if (!$good) { $err->("$line: $LABEL{$k} '$r->{$k}' is not a number."); $ok = 0; next; }
            next if !defined $v;
            my ($lo, $hi) = @{$RANGE{$k}};
            if ($v < $lo || $v > $hi) { $err->("$line: $LABEL{$k} = $v is out of the plausible range ($lo to $hi): check the unit."); $ok = 0; next; }
            $val{$k} = $v;
        }
        next if !$ok;
        if (defined $val{tmax} && defined $val{tmin} && $val{tmin} > $val{tmax} + 0.05) { $err->("$line: tmin ($val{tmin}) is above tmax ($val{tmax})."); next; }

        my $skey = $loc->{id} . "\t" . lc($sname);
        my $st = $stations{$skey} ||= { location => $loc, name => $sname, records => {} };
        foreach my $k (qw(station_latitude station_longitude station_elevation)) {
            (my $f = $k) =~ s/^station_//;
            $st->{$f} //= $val{$k} if defined $val{$k};
        }
        my $key = defined $min ? "$date " . sprintf('%04d', $min) : $date;
        if ($seen{$skey}{$key}++) {
            $err->("$line: $sname already has a row for " . (defined $min ? sprintf('%s %02d:%02d', $date, int($min / 60), $min % 60) : $date) . '.');
            next;
        }
        push @{$st->{records}{$date}}, { min => $min, %val };
    }
    return $fail->('The file mixes daily rows (without time) and rows with a time. Use one kind per file.') if $subdaily && $daily_rows && !@errors;
    return { errors => \@errors, warnings => \@warnings, stations => [], rows => scalar(@$rows) } if @errors;

    my @out;
    foreach my $st (sort { $a->{location}{name} cmp $b->{location}{name} || lc($a->{name}) cmp lc($b->{name}) } values %stations) {
        my ($days, $interval) = $subdaily ? _summarize_subdaily($st->{records}) : _summarize_daily($st->{records});
        my $incomplete = grep { !$_->{complete} } values %$days;
        push @warnings, sprintf('%s: %d of %d days have less than 80%% of the records (interval %d min): their values are not used.',
            $st->{name}, $incomplete, scalar(keys %$days), $interval) if $incomplete;
        push @out, { location => $st->{location}, name => $st->{name}, lat => $st->{latitude}, lon => $st->{longitude}, elev => $st->{elevation},
            days => $days, interval_min => $interval };
    }
    return { errors => [], warnings => \@warnings, stations => \@out, rows => scalar(@$rows), resolution => $subdaily ? 'subdaily' : 'daily' };
}

sub _summarize_daily {
    my $records = shift;
    my %days;
    foreach my $date (keys %$records) {
        my $r = $records->{$date}[0];
        my $rad = $r->{radiation_mj} // (defined $r->{radiation_wm2} ? $r->{radiation_wm2} * 0.0864 : undef);
        my $tmean = $r->{tmean} // $r->{temp};
        $days{$date} = { date => $date, tmax => $r->{tmax}, tmin => $r->{tmin}, tmean => $tmean, rain => $r->{rain_mm}, rh => $r->{rh},
            wind => $r->{wind_ms}, radiation => $rad, n_records => undef, complete => 1 };
    }
    return (\%days, 1440);
}

# records of the same day -> one day. The interval of the logger is the
# median time between records; a day is complete with >= 80% of its records.
sub _summarize_subdaily {
    my $records = shift;
    my @times;
    foreach my $date (sort keys %$records) {
        my ($y, $m, $d) = split /-/, $date;
        my $base = timegm(0, 0, 0, $d, $m - 1, $y) / 60;
        push @times, map { $base + $_->{min} } @{$records->{$date}};
    }
    @times = sort { $a <=> $b } @times;
    my @gaps = sort { $a <=> $b } grep { $_ > 0 } map { $times[$_] - $times[$_ - 1] } 1 .. $#times;
    my $interval = @gaps ? $gaps[int(@gaps / 2)] : 60;
    $interval = 1440 if $interval > 1440;
    my $expected = 1440 / $interval;
    my $mean = sub { my @l = grep { defined } @_; return @l ? sum(@l) / @l : undef };
    my %days;
    foreach my $date (keys %$records) {
        my @r = @{$records->{$date}};
        my $n = scalar @r;
        my $enough = sub { my $k = shift; my $c = grep { defined $_->{$k} } @r; return $c >= 0.8 * $expected };
        my @hi = grep { defined } map { ($_->{tmax}, $_->{temp}) } @r;
        my @lo = grep { defined } map { ($_->{tmin}, $_->{temp}) } @r;
        my $temps_ok = $enough->('temp') || $enough->('tmax');
        my $rad;
        if ($enough->('radiation_wm2')) { $rad = $mean->(map { $_->{radiation_wm2} } @r) * 0.0864 }
        elsif ($enough->('radiation_mj')) { $rad = sum(map { $_->{radiation_mj} // 0 } @r) }
        $days{$date} = {
            date => $date,
            tmax => ($temps_ok && @hi) ? max(@hi) : undef,
            tmin => ($temps_ok && @lo) ? min(@lo) : undef,
            tmean => $enough->('temp') ? $mean->(map { $_->{temp} } @r) : undef,
            rain => $enough->('rain_mm') ? sum(map { $_->{rain_mm} // 0 } @r) : undef,
            rh => $enough->('rh') ? $mean->(map { $_->{rh} } @r) : undef,
            wind => $enough->('wind_ms') ? $mean->(map { $_->{wind_ms} } @r) : undef,
            radiation => $rad,
            n_records => $n,
            complete => $n >= 0.8 * $expected ? 1 : 0,
        };
    }
    return (\%days, $interval);
}

# ------------------------------------------------------------------ store

=head2 new_stations($parsed)

The stations of parse_file() that do not exist yet (same location and name,
case ignored): [ { name, location_id, location_name } ]. Only curators may
create stations; submitters add data to existing ones.

=cut

sub new_stations {
    my ($self, $parsed) = @_;
    my $dbh = $self->schema->storage->dbh;
    my @new;
    foreach my $st (@{$parsed->{stations} || []}) {
        my ($id) = $dbh->selectrow_array('SELECT local_weather_station_id FROM local_weather_station WHERE nd_geolocation_id = ? AND lower(name) = lower(?)',
            undef, $st->{location}{id}, $st->{name});
        push @new, { name => $st->{name}, location_id => $st->{location}{id}, location_name => $st->{location}{name} } if !$id;
    }
    return \@new;
}


=head2 store($parsed, \%opt)

Stores the stations of parse_file(). A station is found by location and name
(created when new; its position is updated when the file gives one). Days
already stored are replaced. Options: sp_person_id, archived_file. Returns
{ stations => [ { id, name, location_id, location_name, inserted, replaced, first, last } ] }.

=cut

sub store {
    my ($self, $parsed, $opt) = @_;
    $opt ||= {};
    die "The file has errors: nothing was stored.\n" if @{$parsed->{errors} || []};
    my $dbh = $self->schema->storage->dbh;
    my @out;
    $self->schema->txn_do(sub {
        foreach my $st (@{$parsed->{stations}}) {
            my ($id) = $dbh->selectrow_array('SELECT local_weather_station_id FROM local_weather_station WHERE nd_geolocation_id = ? AND lower(name) = lower(?)',
                undef, $st->{location}{id}, $st->{name});
            if ($id) {
                my @set = grep { defined $st->{$_->[1]} } (['latitude', 'lat'], ['longitude', 'lon'], ['altitude', 'elev']);
                $dbh->do('UPDATE local_weather_station SET modified_date = now()' . join('', map { ", $_->[0] = ?" } @set) . ' WHERE local_weather_station_id = ?',
                    undef, (map { $st->{$_->[1]} } @set), $id);
            }
            else {
                ($id) = $dbh->selectrow_array('INSERT INTO local_weather_station (nd_geolocation_id, name, latitude, longitude, altitude, sp_person_id)
                    VALUES (?, ?, ?, ?, ?, ?) RETURNING local_weather_station_id', undef,
                    $st->{location}{id}, $st->{name}, $st->{lat}, $st->{lon}, $st->{elev}, $opt->{sp_person_id});
            }
            my $h = $dbh->prepare('INSERT INTO local_weather_daily (local_weather_station_id, obs_date, tmax, tmin, tmean, rain, rh, wind, radiation,
                    n_records, complete, archived_file, sp_person_id, upload_date)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                ON CONFLICT (local_weather_station_id, obs_date) DO UPDATE SET tmax = EXCLUDED.tmax, tmin = EXCLUDED.tmin, tmean = EXCLUDED.tmean,
                    rain = EXCLUDED.rain, rh = EXCLUDED.rh, wind = EXCLUDED.wind, radiation = EXCLUDED.radiation, n_records = EXCLUDED.n_records,
                    complete = EXCLUDED.complete, archived_file = EXCLUDED.archived_file, sp_person_id = EXCLUDED.sp_person_id, upload_date = now()
                RETURNING (xmax = 0)');
            my ($ins, $rep) = (0, 0);
            my @dates = sort keys %{$st->{days}};
            foreach my $date (@dates) {
                my $d = $st->{days}{$date};
                $h->execute($id, $date, (map { $d->{$_} } qw(tmax tmin tmean rain rh wind radiation n_records)), $d->{complete} ? 1 : 0,
                    $opt->{archived_file}, $opt->{sp_person_id});
                my ($new) = $h->fetchrow_array;
                $new ? $ins++ : $rep++;
            }
            push @out, { id => $ID_PREFIX . $id, name => $st->{name}, location_id => $st->{location}{id}, location_name => $st->{location}{name},
                inserted => $ins, replaced => $rep, first => $dates[0], last => $dates[-1] };
        }
    });
    return { stations => \@out };
}

=head2 preview($parsed)

What store() would do, without storing: [ { name, location_id,
location_name, exists, days, first, last, new_days, replaced_days } ].

=cut

sub preview {
    my ($self, $parsed) = @_;
    my $dbh = $self->schema->storage->dbh;
    my @out;
    foreach my $st (@{$parsed->{stations} || []}) {
        my ($id) = $dbh->selectrow_array('SELECT local_weather_station_id FROM local_weather_station WHERE nd_geolocation_id = ? AND lower(name) = lower(?)',
            undef, $st->{location}{id}, $st->{name});
        my @dates = sort keys %{$st->{days}};
        my $stored = 0;
        if ($id && @dates) {
            ($stored) = $dbh->selectrow_array('SELECT count(*) FROM local_weather_daily WHERE local_weather_station_id = ? AND obs_date = ANY(?::date[])',
                undef, $id, \@dates);
        }
        push @out, { name => $st->{name}, location_id => $st->{location}{id}, location_name => $st->{location}{name}, exists => $id ? 1 : 0,
            days => scalar(@dates), first => $dates[0], last => $dates[-1], new_days => @dates - $stored, replaced_days => $stored + 0 };
    }
    return \@out;
}

# ------------------------------------------------------------------ stations file

my @STATION_COLUMNS = qw(location_name station_name station_latitude station_longitude station_elevation description);

=head2 station_template_columns()

The columns of the template that adds stations.

=cut

sub station_template_columns { return [ @STATION_COLUMNS ] }

=head2 parse_stations_file($file, \%opt)

Reads a file of stations (one row per station), all columns required:
location_name, station_name, station_latitude, station_longitude,
station_elevation and description. With opt location_id every row must be of
that location. Returns { errors, warnings, stations => [ { location, name, lat,
lon, elev, description, exists } ] }. Nothing is stored.

=cut

sub parse_stations_file {
    my ($self, $file, $opt) = @_;
    $opt ||= {};
    my (@errors, @warnings);
    my $err = sub { push @errors, shift if @errors < $MAX_ERRORS };
    my $fail = sub { return { errors => [ @_ ], warnings => [], stations => [] } };
    my %aliases = map { $_ => $ALIASES{$_} } grep { $ALIASES{$_} } @STATION_COLUMNS;
    $aliases{description} = ['notes', 'comment', 'comments'];
    my %args = (file => $file, optional_columns => \@STATION_COLUMNS, column_aliases => \%aliases);
    $args{type} = $opt->{type} if $opt->{type};
    my $parsed = try { CXGN::File::Parse->new(%args)->parse() } catch { { errors => [ "The file could not be read: $_" ] } };
    return $fail->(@{$parsed->{errors}}) if @{$parsed->{errors} || []};
    my %has = map { $_ => 1 } @{$parsed->{columns} || []};
    my $rows = $parsed->{data} || [];
    return $fail->('The file has no data rows.') if !@$rows;
    my @required = qw(location_name station_name station_latitude station_longitude station_elevation description);
    my @missing = grep { !$has{$_} } @required;
    return $fail->('The file needs the columns ' . join(', ', @missing) . ' (see the stations template).') if @missing;
    my %known = map { $_ => 1 } @STATION_COLUMNS;
    my @unknown = grep { !$known{$_} } @{$parsed->{columns} || []};
    push @warnings, 'Columns not used: ' . join(', ', @unknown) . '.' if @unknown;
    my $default_loc = $opt->{location_id} ? $self->_location_by_id($opt->{location_id}) : undef;
    return $fail->('The location of the upload was not found.') if $opt->{location_id} && !$default_loc;

    my $dbh = $self->schema->storage->dbh;
    my (%loc_cache, %seen, @out);
    foreach my $r (@$rows) {
        my $line = 'Row ' . ($r->{_row} // '?');
        my $lname = $r->{location_name} // '';
        if ($lname eq '') { $err->("$line: location_name is empty (required)."); next; }
        my $loc = $self->_location_by_name($lname, \%loc_cache);
        if (!$loc) { $err->("$line: the location '$lname' does not exist in the database (add it in Manage > Locations)."); next; }
        if ($default_loc && $loc->{id} != $default_loc->{id}) { $err->("$line: the location '$lname' is not $default_loc->{name}, the location of this upload."); next; }
        my $name = $r->{station_name} // '';
        $name =~ s/^\s+|\s+$//g;
        if ($name eq '') { $err->("$line: the station name is empty."); next; }
        if (length($name) > 200) { $err->("$line: the station name is longer than 200 characters."); next; }
        if ($seen{$loc->{id} . "\t" . lc $name}++) { $err->("$line: the station '$name' of $loc->{name} is in the file twice."); next; }
        my %val;
        my $ok = 1;
        foreach my $k (qw(station_latitude station_longitude station_elevation)) {
            my ($v, $good) = _number($r->{$k});
            if (!$good) { $err->("$line: $LABEL{$k} '$r->{$k}' is not a number."); $ok = 0; next; }
            if (!defined $v) { $err->("$line: $k is empty (required)."); $ok = 0; next; }
            my ($lo, $hi) = @{$RANGE{$k}};
            if ($v < $lo || $v > $hi) { $err->("$line: $LABEL{$k} = $v is out of the range $lo to $hi."); $ok = 0; next; }
            $val{$k} = $v;
        }
        my $desc = $r->{description} // '';
        $desc =~ s/^\s+|\s+$//g;
        if ($desc eq '') { $err->("$line: description is empty (required: model, what it measures, where it is)."); $ok = 0; }
        next if !$ok;
        my ($id) = $dbh->selectrow_array('SELECT local_weather_station_id FROM local_weather_station WHERE nd_geolocation_id = ? AND lower(name) = lower(?)',
            undef, $loc->{id}, $name);
        push @out, { location => $loc, name => $name, lat => $val{station_latitude}, lon => $val{station_longitude}, elev => $val{station_elevation},
            description => substr($desc, 0, 2000), exists => $id ? 1 : 0, id => $id };
    }
    return { errors => \@errors, warnings => \@warnings, stations => @errors ? [] : \@out };
}

=head2 store_stations($parsed, \%opt)

Creates the stations of parse_stations_file(); a station that exists already
(same location and name) gets the position and description of the file when
given. Option sp_person_id. Returns { created, updated, stations => [ { id,
name, location_name, created } ] }.

=cut

sub store_stations {
    my ($self, $parsed, $opt) = @_;
    $opt ||= {};
    die "The file has errors: nothing was stored.\n" if @{$parsed->{errors} || []};
    my $dbh = $self->schema->storage->dbh;
    my ($created, $updated, @out) = (0, 0);
    $self->schema->txn_do(sub {
        foreach my $st (@{$parsed->{stations}}) {
            my ($id) = $dbh->selectrow_array('SELECT local_weather_station_id FROM local_weather_station WHERE nd_geolocation_id = ? AND lower(name) = lower(?)',
                undef, $st->{location}{id}, $st->{name});
            if ($id) {
                my @set = grep { defined $st->{$_->[1]} } (['latitude', 'lat'], ['longitude', 'lon'], ['altitude', 'elev'], ['description', 'description']);
                $dbh->do('UPDATE local_weather_station SET modified_date = now()' . join('', map { ", $_->[0] = ?" } @set) . ' WHERE local_weather_station_id = ?',
                    undef, (map { $st->{$_->[1]} } @set), $id);
                $updated++;
            }
            else {
                ($id) = $dbh->selectrow_array('INSERT INTO local_weather_station (nd_geolocation_id, name, latitude, longitude, altitude, description, sp_person_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING local_weather_station_id', undef,
                    $st->{location}{id}, $st->{name}, $st->{lat}, $st->{lon}, $st->{elev}, $st->{description}, $opt->{sp_person_id});
                $created++;
            }
            push @out, { id => $ID_PREFIX . $id, name => $st->{name}, location_id => $st->{location}{id}, location_name => $st->{location}{name}, created => $st->{exists} ? 0 : 1 };
        }
    });
    return { created => $created, updated => $updated, stations => \@out };
}

# ------------------------------------------------------------------ read

=head2 db_id($station_id)

The table id of a station id of the 'local' network ('L12' -> 12), or undef.

=cut

sub db_id {
    my ($self, $id) = @_;
    return (defined $id && $id =~ /^$ID_PREFIX(\d+)$/i) ? $1 + 0 : undef;
}

=head2 stations(\%filter)

Uploaded stations with a summary of their data. Filter: location_id or
station_id ('L12'). Each: id, db_id, name, location_id, location_name, lat,
lon, elev (the location's when the station has none), first, last, days,
has_temp, has_rain, has_rh, has_wind, has_radiation, uploaded_by,
uploaded_by_id, sp_person_id, last_upload.

=cut

sub stations {
    my ($self, $filter) = @_;
    $filter ||= {};
    my (@where, @bind);
    if ($filter->{location_id}) { push @where, 's.nd_geolocation_id = ?'; push @bind, $filter->{location_id}; }
    if (defined $filter->{station_id}) {
        my $id = $self->db_id($filter->{station_id}) // return [];
        push @where, 's.local_weather_station_id = ?'; push @bind, $id;
    }
    my $q = "SELECT s.local_weather_station_id, s.name, s.nd_geolocation_id, g.description,
            coalesce(s.latitude, g.latitude), coalesce(s.longitude, g.longitude), coalesce(s.altitude, g.altitude),
            s.sp_person_id, p.first_name, p.last_name,
            min(d.obs_date), max(d.obs_date), count(d.obs_date),
            bool_or(d.tmax IS NOT NULL OR d.tmin IS NOT NULL), bool_or(d.rain IS NOT NULL), bool_or(d.rh IS NOT NULL),
            bool_or(d.wind IS NOT NULL), bool_or(d.radiation IS NOT NULL), max(d.upload_date)
        FROM local_weather_station s
        JOIN nd_geolocation g ON (g.nd_geolocation_id = s.nd_geolocation_id)
        LEFT JOIN sgn_people.sp_person p ON (p.sp_person_id = s.sp_person_id)
        LEFT JOIN local_weather_daily d ON (d.local_weather_station_id = s.local_weather_station_id)
        " . (@where ? 'WHERE ' . join(' AND ', @where) : '') . "
        GROUP BY s.local_weather_station_id, g.nd_geolocation_id, p.sp_person_id
        ORDER BY g.description, s.name";
    my $h = $self->schema->storage->dbh->prepare($q);
    $h->execute(@bind);
    my @out;
    while (my @r = $h->fetchrow_array) {
        my $date = sub { my $v = shift; return defined $v ? substr($v, 0, 10) : undef };
        push @out, {
            network => $NETWORK, id => $ID_PREFIX . $r[0], db_id => $r[0], name => $r[1], location_id => $r[2], location_name => $r[3],
            lat => _round($r[4], 5), lon => _round($r[5], 5), elev => _round($r[6], 1), sp_person_id => $r[7],
            uploaded_by => join(' ', grep { defined && $_ ne '' } $r[8], $r[9]),
            first => $date->($r[10]), last => $date->($r[11]), days => $r[12] + 0,
            has_temp => $r[13] ? 1 : 0, has_rain => $r[14] ? 1 : 0, has_rh => $r[15] ? 1 : 0, has_wind => $r[16] ? 1 : 0, has_radiation => $r[17] ? 1 : 0,
            last_upload => defined $r[18] ? substr($r[18], 0, 16) : undef,
        };
    }
    return \@out;
}

=head2 nearby_stations($wx, $lat, $lon, $range_km)

Uploaded stations within $range_km (with a position), in the format of
CXGN::Weather::nearby_stations: network 'local', ready, rain_only, measures.

=cut

sub nearby_stations {
    my ($self, $wx, $lat, $lon, $range_km) = @_;
    my @out;
    foreach my $s (@{$self->stations()}) {
        next if !defined $s->{lat} || !defined $s->{lon} || !$s->{days};
        my $dkm = $wx->distance_km($lat, $lon, $s->{lat}, $s->{lon});
        next if $dkm > $range_km;
        my $b = $wx->bearing($lat, $lon, $s->{lat}, $s->{lon});
        push @out, {
            %$s,
            distance_km => sprintf('%.1f', $dkm) + 0,
            bearing => sprintf('%.0f', $b) + 0,
            direction => $dkm < 0.05 ? '' : $wx->compass($b),
            ready => 1,
            rain_only => $s->{has_temp} ? 0 : 1,
            rain_amounts => $s->{has_rain},
            measures => [ grep { $_ } ($s->{has_temp} ? 'temperature' : ''), ($s->{has_rain} ? 'rain' : ''), ($s->{has_radiation} ? 'radiation' : ''),
                ($s->{has_rh} ? 'humidity' : ''), ($s->{has_wind} ? 'wind' : '') ],
        };
    }
    return [ sort { $a->{distance_km} <=> $b->{distance_km} } @out ];
}

=head2 station_daily($wx, $station_id, $lat, $lon, $elev, $start, $end)

Daily data of an uploaded station between two dates, in the format of
CXGN::Weather::station_daily. ET0: FAO-56 Penman-Monteith when the day has
radiation, humidity and wind, else Hargreaves-Samani.

=cut

sub station_daily {
    my ($self, $wx, $station_id, $lat, $lon, $elev, $start, $end) = @_;
    my $id = $self->db_id($station_id) // die "Unknown uploaded station $station_id.\n";
    my ($st) = @{$self->stations({ station_id => $station_id })};
    die "Unknown uploaded station $station_id.\n" if !$st;
    $lat = $st->{lat} if defined $st->{lat};
    $elev = $st->{elev} if defined $st->{elev};
    my $h = $self->schema->storage->dbh->prepare('SELECT obs_date, tmax, tmin, tmean, rain, rh, wind, radiation, n_records, complete
        FROM local_weather_daily WHERE local_weather_station_id = ? AND obs_date BETWEEN ? AND ? ORDER BY obs_date');
    $h->execute($id, $start, $end);
    my $r1 = sub { my $v = shift; return defined $v ? sprintf('%.1f', $v) + 0 : undef };
    my @days;
    while (my ($date, $tmax, $tmin, $tmean, $rain, $rh, $wind, $rad, $n, $complete) = $h->fetchrow_array) {
        $date = substr($date, 0, 10);
        ($tmax, $tmin, $tmean, $rain, $rh, $wind, $rad) = () if !$complete;
        $tmean //= (defined $tmax && defined $tmin) ? ($tmax + $tmin) / 2 : undef;
        my ($y, $m, $d) = split /-/, $date;
        my $doy = (gmtime(timegm(0, 0, 12, $d, $m - 1, $y)))[7] + 1;
        my ($et0, $method);
        if (defined $tmax && defined $tmin) {
            if (defined $rad && defined $rh && defined $wind) {
                $et0 = $wx->penman_monteith_et0(lat => $lat, elev => $elev, doy => $doy, tmax => $tmax, tmin => $tmin, rh => $rh, rs => $rad, wind => $wind, wind_height => 2);
                $method = 'PM';
            }
            else {
                $et0 = $wx->hargreaves_et0($lat, $doy, $tmax, $tmin);
                $method = 'HS';
            }
        }
        push @days, {
            date => $date, hours => $n // 24, complete => $complete ? 1 : 0,
            tmax => $r1->($tmax), tmin => $r1->($tmin), tmean => $r1->($tmean),
            rh => defined $rh ? sprintf('%.0f', $rh) + 0 : undef,
            rain => $r1->($rain), rain_hours => (defined $rain && $rain > 0) ? 1 : 0,
            wind_mean => defined $wind ? $r1->($wind * 3.6) : undef,
            radiation => $r1->($rad), et0 => $et0, et0_method => $method,
        };
    }
    my $by = $st->{uploaded_by} ? ", uploaded by $st->{uploaded_by}" : '';
    return {
        source => "Station $st->{name} of $st->{location_name} (data uploaded to Breedbase$by)",
        note => 'Daily values uploaded by users from the station of the research farm. Days summarized from hourly records with less than 80% of the records are left empty. ET0: FAO-56 Penman-Monteith when radiation, humidity and wind are given (wind taken at 2 m), else Hargreaves-Samani.',
        rain_reported => $st->{has_rain} ? 1 : 0,
        ($st->{has_temp} ? () : (rain_only => 1)),
        days => \@days,
    };
}

=head2 delete_station($station_id)

Deletes an uploaded station and all its data.

=cut

sub delete_station {
    my ($self, $station_id) = @_;
    my $id = $self->db_id($station_id) // return 0;
    return $self->schema->storage->dbh->do('DELETE FROM local_weather_station WHERE local_weather_station_id = ?', undef, $id) > 0 ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;

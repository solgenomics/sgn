package SGN::Controller::SeedQuest::AJAX::Weather;

use Moose;
use Data::Dumper;
use JSON;
use Try::Tiny;
use List::Util qw(sum max min);
use LWP::UserAgent;
use URI::Escape;
use Digest::SHA qw(hmac_sha256_hex);
use Excel::Writer::XLSX;
use File::Temp qw(tempfile);
use POSIX qw(strftime);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

# ============================================================================
# CROPS ENDPOINT
# ============================================================================

sub get_crops : Path('/ajax/seedquest/weather/crops') Args(0) ActionClass('REST') { }
sub get_crops_GET {
    my ($self, $c) = @_;

    # Verified base temps / methods — see SEEDQUEST_WEATHER_RESEARCH_2026-05-22.md.
    # cap_temp set => modified "86/50" method (cap Tmax, floor Tmin at base); undef => simple average.
    # maturity_gdd/_chu = default accumulation targets to physiological maturity (editable per variety).
    my @crops = (
        { id => 1, crop_name => 'Corn / Maize',      base_temp => 10,  cap_temp => 30,    use_chu => 1, method => 'modified', maturity_gdd => 2700, maturity_chu => 2900 },
        { id => 2, crop_name => 'Soybean',           base_temp => 10,  cap_temp => 30,    use_chu => 0, method => 'modified', maturity_gdd => 2400, maturity_chu => undef },
        { id => 3, crop_name => 'Sunflower',         base_temp => 6.7, cap_temp => undef, use_chu => 0, method => 'simple',   maturity_gdd => 1550, maturity_chu => undef },
        { id => 4, crop_name => 'Wheat',             base_temp => 0,   cap_temp => undef, use_chu => 0, method => 'simple',   maturity_gdd => 2000, maturity_chu => undef },
        { id => 5, crop_name => 'Barley',            base_temp => 0,   cap_temp => undef, use_chu => 0, method => 'simple',   maturity_gdd => 1850, maturity_chu => undef },
        { id => 6, crop_name => 'Rapeseed / Canola', base_temp => 5,   cap_temp => undef, use_chu => 0, method => 'simple',   maturity_gdd => 1500, maturity_chu => undef },
        { id => 7, crop_name => 'Custom',            base_temp => 10,  cap_temp => undef, use_chu => 1, method => 'simple',   maturity_gdd => undef, maturity_chu => undef },
    );

    $c->stash->{rest} = { crops => \@crops };
}

# ============================================================================
# GDD CALCULATION ENDPOINT
# ============================================================================

sub calculate_gdd : Path('/ajax/seedquest/weather/gdd') Args(0) ActionClass('REST') { }
sub calculate_gdd_GET { shift->_do_gdd_calculation(@_); }
sub calculate_gdd_POST { shift->_do_gdd_calculation(@_); }

sub _do_gdd_calculation {
    my ($self, $c) = @_;

    # Defense-in-depth: verify user is logged in
    unless ($c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in first!' };
        return;
    }

    my $location_id = $c->req->param('location_id');
    my $seasons_json = $c->req->param('seasons');
    # NB: base_temp can legitimately be 0 (e.g. wheat) — use defined-or, not ||.
    my $base_temp = $c->req->param('base_temp');
    $base_temp = 10 unless defined $base_temp && $base_temp ne '';
    # cap_temp set (e.g. 30 => corn 86/50 method); undef/'' => simple average method.
    my $cap_temp = $c->req->param('cap_temp');
    $cap_temp = undef unless defined $cap_temp && $cap_temp ne '';
    my $data_source = $c->req->param('data_source') || 'openmeteo';

    # Resolve coordinates up front; error clearly instead of defaulting to a
    # hard-coded town (previously Mirgorod) which silently returned wrong data.
    my ($lat, $lon) = $self->_get_location_coords($c, $location_id);
    unless (defined $lat && defined $lon) {
        $c->stash->{rest} = { error => "Location has no coordinates. Set latitude/longitude for this location first." };
        return;
    }

    try {
        my $seasons = decode_json($seasons_json);
        my @results;
        my $cache_stats = { from_cache => 0, from_api => 0 };

        foreach my $season (@$seasons) {
            my $year = $season->{year};
            my $start_date = $season->{start_date} || $season->{start} || "$year-04-15";
            my $end_date = $season->{end_date} || $season->{end} || "$year-09-30";

            # Use cache only if it fully covers the requested range — otherwise a
            # partial cache (e.g. 5 of 60 days) would silently undercount GDD.
            my $weather_data = $self->_get_cached_weather($c, $location_id, $start_date, $end_date);
            my $exp_days = int(($self->_date_to_timestamp($end_date) - $self->_date_to_timestamp($start_date)) / 86400) + 1;
            my $used_cache = 0;

            if ($weather_data && scalar(@$weather_data) >= $exp_days) {
                $cache_stats->{from_cache} += scalar(@$weather_data);
                $used_cache = 1;
            } else {
                # Source resolution BY LOCATION: a ground station mapped to THIS
                # location wins (truth on the field); otherwise Open-Meteo, which is
                # available globally on land.
                my $api_data;
                my ($resolved, $station) = $self->_resolve_source($c, $location_id);
                my $actual_source = 'openmeteo';

                if ($resolved eq 'davis') {
                    $api_data = $self->_fetch_davis_data($c, $station, $start_date, $end_date);
                    $actual_source = 'davis' if $api_data;
                } elsif ($resolved eq 'ecowitt') {
                    $api_data = $self->_fetch_ecowitt_data($c, $station, $start_date, $end_date);
                    $actual_source = 'ecowitt' if $api_data;
                }

                # Fall back to Open-Meteo (always available on land).
                if (!$api_data) {
                    $api_data = $self->_fetch_openmeteo_data($lat, $lon, $start_date, $end_date);
                    $actual_source = 'openmeteo';
                }

                $weather_data = $self->_parse_api_response($api_data, $actual_source);
                $data_source = $actual_source;  # Update for response

                # Cache the data
                if ($weather_data && scalar(@$weather_data) > 0) {
                    $self->_cache_weather_data($c, $location_id, $weather_data, $data_source);
                    $cache_stats->{from_api} += scalar(@$weather_data);
                }
            }

            # Calculate GDD/CHU via shared helpers; skip days with missing temps
            # (do not fabricate 20/10) and track real mean temperature.
            my @daily_data;
            my ($total_gdd, $total_chu, $total_precip, $total_tavg) = (0, 0, 0, 0);
            my $missing_days = 0;

            foreach my $day (@{$weather_data || []}) {
                my $tmax = $day->{tmax};
                my $tmin = $day->{tmin};
                my $precip = $day->{precip} // 0;
                if (!defined $tmax || !defined $tmin) { $missing_days++; next; }
                my $tavg = ($tmax + $tmin) / 2;

                my $gdd = $self->_gdd_day($tmax, $tmin, $base_temp, $cap_temp);
                my $chu_day = $self->_chu_day($tmax, $tmin);
                $total_gdd += $gdd;
                $total_chu += $chu_day;
                $total_precip += $precip;
                $total_tavg += $tavg;

                push @daily_data, {
                    date => $day->{date},
                    tmax => sprintf("%.1f", $tmax),
                    tmin => sprintf("%.1f", $tmin),
                    tavg => sprintf("%.1f", $tavg),
                    gdd_day => sprintf("%.1f", $gdd),
                    gdd_cumulative => sprintf("%.1f", $total_gdd),
                    chu_day => sprintf("%.1f", $chu_day),
                    chu_cumulative => sprintf("%.1f", $total_chu),
                    precip_day => sprintf("%.1f", $precip),
                    precip_cumulative => sprintf("%.1f", $total_precip),
                };
            }

            push @results, {
                year => $year,
                start_date => $start_date,
                end_date => $end_date,
                total_gdd => sprintf("%.1f", $total_gdd),
                total_chu => sprintf("%.1f", $total_chu),
                total_precip => sprintf("%.1f", $total_precip),
                days_count => scalar(@daily_data),
                missing_days => $missing_days,
                avg_temp => sprintf("%.1f", scalar(@daily_data) > 0 ? $total_tavg / scalar(@daily_data) : 0),
                daily_data => \@daily_data,
                data_source => $used_cache ? 'cached' : $data_source,
            };
        }

        # Build summary and combine all daily data for Excel export
        my ($sum_gdd, $sum_chu, $sum_precip, $total_days) = (0, 0, 0, 0);
        my @all_daily_data;

        foreach my $r (@results) {
            $sum_gdd += $r->{total_gdd};
            $sum_chu += $r->{total_chu};
            $sum_precip += $r->{total_precip};
            $total_days += $r->{days_count};
            # Combine all daily data for Excel export
            push @all_daily_data, @{$r->{daily_data} || []};
        }
        my $years_count = scalar(@results);

        $c->stash->{rest} = {
            success => 1,
            multi_year => ($years_count > 1) ? 1 : 0,
            years => \@results,
            # All daily data combined for Excel export
            all_daily_data => \@all_daily_data,
            summary => {
                avg_gdd => sprintf("%.1f", $years_count > 0 ? $sum_gdd / $years_count : 0),
                avg_chu => sprintf("%.1f", $years_count > 0 ? $sum_chu / $years_count : 0),
                avg_precip => sprintf("%.1f", $years_count > 0 ? $sum_precip / $years_count : 0),
                total_days => $total_days,
                years_count => $years_count,
            },
            total_gdd => $results[0]->{total_gdd} || 0,
            total_chu => $results[0]->{total_chu} || 0,
            total_precip => $results[0]->{total_precip} || 0,
            days_count => $results[0]->{days_count} || 0,
            daily_data => $results[0]->{daily_data} || [],
            location => { lat => $lat, lon => $lon },
            sync_info => {
                synced => $cache_stats->{from_api},
                existing => $cache_stats->{from_cache},
                message => "Data from $data_source"
            },
        };

    } catch {
        $c->stash->{rest} = { error => "Failed to calculate GDD: $_" };
    };
}

# ============================================================================
# DAYS-TO-MATURITY PROJECTION
# ============================================================================

sub maturity_estimate : Path('/ajax/seedquest/weather/maturity') Args(0) ActionClass('REST') { }
sub maturity_estimate_GET  { shift->_do_maturity(@_); }
sub maturity_estimate_POST { shift->_do_maturity(@_); }

sub _do_maturity {
    my ($self, $c) = @_;

    unless ($c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in first!' };
        return;
    }

    my $location_id = $c->req->param('location_id');
    my $sowing_date = $c->req->param('sowing_date');
    my $metric      = lc($c->req->param('metric') || 'gdd');   # gdd | chu
    my $target      = $c->req->param('target');                # accumulation target to maturity
    my $base_temp   = $c->req->param('base_temp');
    $base_temp = 10 unless defined $base_temp && $base_temp ne '';
    my $cap_temp    = $c->req->param('cap_temp');
    $cap_temp = undef unless defined $cap_temp && $cap_temp ne '';

    unless ($sowing_date && defined $target && $target > 0) {
        $c->stash->{rest} = { error => 'sowing_date and a positive target are required.' };
        return;
    }

    my ($lat, $lon) = $self->_get_location_coords($c, $location_id);
    unless (defined $lat && defined $lon) {
        $c->stash->{rest} = { error => 'Location has no coordinates. Set latitude/longitude first.' };
        return;
    }

    my $result = try {
        # Accumulate from sowing up to a season+margin, but not beyond today.
        my $sow_ts     = $self->_date_to_timestamp($sowing_date);
        my $horizon_ts = $sow_ts + 300 * 86400;
        my $end_ts     = $horizon_ts < time() ? $horizon_ts : time();
        my $end_date   = $self->_timestamp_to_date($end_ts);

        my $weather  = $self->_get_cached_weather($c, $location_id, $sowing_date, $end_date);
        my $exp_days = int(($end_ts - $sow_ts) / 86400) + 1;
        if (!$weather || scalar(@$weather) < $exp_days) {
            my $api = $self->_fetch_openmeteo_data($lat, $lon, $sowing_date, $end_date);
            $weather = $self->_parse_api_response($api, 'openmeteo');
            $self->_cache_weather_data($c, $location_id, $weather, 'openmeteo') if $weather && @$weather;
        }
        my @days = sort { ($a->{date} // '') cmp ($b->{date} // '') } @{$weather || []};

        my ($cum, $n, $sum_daily, $reached_date) = (0, 0, 0, undef);
        foreach my $d (@days) {
            my ($tmax, $tmin) = ($d->{tmax}, $d->{tmin});
            next unless defined $tmax && defined $tmin;
            my $inc = ($metric eq 'chu')
                ? $self->_chu_day($tmax, $tmin)
                : $self->_gdd_day($tmax, $tmin, $base_temp, $cap_temp);
            $cum += $inc; $n++; $sum_daily += $inc;
            $reached_date = $d->{date} if !$reached_date && $cum >= $target;
        }

        my %out = (
            success        => 1,
            metric         => $metric,
            target         => $target + 0,
            accumulated    => sprintf('%.0f', $cum),
            days_with_data => $n,
            sowing_date    => $sowing_date,
        );
        if ($reached_date) {
            $out{status}           = 'reached';
            $out{maturity_date}    = $reached_date;
            $out{days_to_maturity} = int(($self->_date_to_timestamp($reached_date) - $sow_ts) / 86400);
        } elsif ($n > 0 && $sum_daily > 0) {
            # Project the remainder using mean daily accumulation observed so far.
            my $avg        = $sum_daily / $n;
            my $extra_days = int(($target - $cum) / $avg + 0.5);
            $out{status}           = 'projected';
            $out{avg_daily}        = sprintf('%.2f', $avg);
            $out{days_to_maturity} = $n + $extra_days;
            $out{maturity_date}    = $self->_timestamp_to_date($sow_ts + ($n + $extra_days) * 86400);
        } else {
            $out{status} = 'insufficient_data';
        }
        return \%out;
    } catch {
        return { error => "Maturity estimate failed: $_" };
    };

    $c->stash->{rest} = $result;
}

# ============================================================================
# DATABASE CACHING
# ============================================================================

sub _get_cached_weather {
    my ($self, $c, $location_id, $start_date, $end_date) = @_;

    my @data;
    try {
        my $dbh = $c->dbc->dbh;
        # Priority merge: ground-truth stations > virtual reanalysis
        my $sth = $dbh->prepare(q{
            SELECT DISTINCT ON (date)
                date, temp_max, temp_min, temp_mean, precipitation,
                humidity_mean, solar_radiation, evapotranspiration,
                wind_speed_max, dew_point, soil_temp, soil_moisture, source
            FROM weather_data
            WHERE location_id = ? AND date BETWEEN ? AND ?
            ORDER BY date,
                CASE source
                    WHEN 'davis' THEN 1
                    WHEN 'ecowitt' THEN 1
                    WHEN 'open-meteo' THEN 2
                    WHEN 'noaa' THEN 3
                    ELSE 4
                END
        });
        $sth->execute($location_id, $start_date, $end_date);

        while (my $row = $sth->fetchrow_hashref) {
            push @data, {
                date    => $row->{date},
                tmax    => $row->{temp_max},
                tmin    => $row->{temp_min},
                tmean   => $row->{temp_mean},
                precip  => $row->{precipitation} || 0,
                humidity => $row->{humidity_mean},
                solar   => $row->{solar_radiation},
                et0     => $row->{evapotranspiration},
                wind    => $row->{wind_speed_max},
                dewpoint => $row->{dew_point},
                soil_temp => $row->{soil_temp},
                soil_moisture => $row->{soil_moisture},
                source  => $row->{source},
            };
        }
    } catch {
        warn "Weather cache read failed: $_";
    };

    return \@data;
}

sub _cache_weather_data {
    my ($self, $c, $location_id, $data, $source) = @_;

    try {
        my $dbh = $c->dbc->dbh;

        # Upsert into weather_data with multi-source support
        my $sth = $dbh->prepare(q{
            INSERT INTO weather_data
                (location_id, date, temp_max, temp_min, temp_mean,
                 precipitation, humidity_mean, solar_radiation,
                 evapotranspiration, wind_speed_max, dew_point,
                 soil_temp, soil_moisture, source)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (location_id, date, source) DO UPDATE SET
                temp_max = EXCLUDED.temp_max,
                temp_min = EXCLUDED.temp_min,
                temp_mean = EXCLUDED.temp_mean,
                precipitation = EXCLUDED.precipitation,
                humidity_mean = EXCLUDED.humidity_mean,
                solar_radiation = EXCLUDED.solar_radiation,
                evapotranspiration = EXCLUDED.evapotranspiration,
                wind_speed_max = EXCLUDED.wind_speed_max,
                dew_point = EXCLUDED.dew_point,
                soil_temp = EXCLUDED.soil_temp,
                soil_moisture = EXCLUDED.soil_moisture
        });

        foreach my $day (@$data) {
            $sth->execute(
                $location_id,
                $day->{date},
                $day->{tmax},
                $day->{tmin},
                $day->{tmean},
                $day->{precip} || 0,
                $day->{humidity},
                $day->{solar},
                $day->{et0},
                $day->{wind},
                $day->{dewpoint},
                $day->{soil_temp},
                $day->{soil_moisture},
                $source
            );
        }
    } catch {
        warn "Failed to cache weather data: $_";
    };
}

# ============================================================================
# OPEN-METEO API (Free, no API key)
# ============================================================================

sub _fetch_openmeteo_data {
    my ($self, $lat, $lon, $start_date, $end_date) = @_;

    my $ua = LWP::UserAgent->new(timeout => 60);
    # Full 17-variable agronomical dataset from Open-Meteo ERA5-Land
    my $vars = join(',',
        'temperature_2m_max', 'temperature_2m_min', 'temperature_2m_mean',
        'precipitation_sum', 'rain_sum', 'snowfall_sum', 'precipitation_hours',
        'sunshine_duration', 'et0_fao_evapotranspiration',
        'wind_speed_10m_max', 'wind_gusts_10m_max', 'wind_direction_10m_dominant',
        'shortwave_radiation_sum', 'relative_humidity_2m_mean',
        'dew_point_2m_mean',
        'soil_temperature_0_to_7cm_mean', 'soil_moisture_0_to_7cm_mean',
    );
    # Recent seasons (>=2022) come from the Historical Forecast API (≈no lag, tracks
    # actual conditions); older dates from the ERA5 Archive API (1940+, ~5-7 day lag).
    my ($start_year) = split /-/, ($start_date // '');
    my $base = ($start_year && $start_year >= 2022)
        ? 'https://historical-forecast-api.open-meteo.com/v1/forecast'
        : 'https://archive-api.open-meteo.com/v1/archive';
    my $url = sprintf(
        "%s?latitude=%.4f&longitude=%.4f&start_date=%s&end_date=%s&daily=%s&timezone=auto",
        $base, $lat, $lon, $start_date, $end_date, $vars
    );

    my $response = $ua->get($url);
    return $response->is_success ? decode_json($response->decoded_content) : undef;
}

# ============================================================================
# DAVIS WEATHERLINK v2 API
# ============================================================================

# Resolve the weather source for a location: a mapped ground station (Davis/Ecowitt)
# if configured for it, else Open-Meteo (global land coverage).
# Config: $c->config->{weather_station_map} = { <location_id> => { type=>'davis'|'ecowitt', station_id=>..., mac=>... } }
sub _resolve_source {
    my ($self, $c, $location_id) = @_;
    my $map = $c->config->{weather_station_map};
    if ($map && ref $map eq 'HASH' && defined $location_id && $map->{$location_id}) {
        my $m = $map->{$location_id};
        my $type = lc($m->{type} || '');
        if ($type eq 'davis' && $c->config->{davis_api_key} && $c->config->{davis_api_secret}) {
            return ('davis', $m->{station_id});
        }
        if ($type eq 'ecowitt' && $c->config->{ecowitt_app_key} && $c->config->{ecowitt_api_key}) {
            return ('ecowitt', $m->{mac});
        }
    }
    return ('openmeteo', undef);
}

sub _fetch_davis_data {
    my ($self, $c, $station_id, $start_date, $end_date) = @_;

    my $api_key    = $c->config->{davis_api_key} || '';
    my $api_secret = $c->config->{davis_api_secret} || '';
    $station_id  ||= $c->config->{davis_station_id} || '';

    return undef unless $api_key && $api_secret && $station_id;

    my $ua = LWP::UserAgent->new(timeout => 30);

    my $start_ts = $self->_date_to_timestamp($start_date);
    my $end_ts   = $self->_date_to_timestamp($end_date);

    # WeatherLink v2 current auth: api-key as a query param, the RAW secret in the
    # X-Api-Secret header. (The api-signature HMAC method is deprecated.)
    my $url = "https://api.weatherlink.com/v2/historic/$station_id"
            . "?api-key=" . uri_escape($api_key)
            . "&start-timestamp=$start_ts&end-timestamp=$end_ts";

    my $response = $ua->get($url, 'X-Api-Secret' => $api_secret);

    if ($response->is_success) {
        return decode_json($response->decoded_content);
    } else {
        warn "Davis API error: " . $response->status_line;
        return undef;
    }
}

# ============================================================================
# ECOWITT CLOUD API
# ============================================================================

sub _fetch_ecowitt_data {
    my ($self, $c, $mac, $start_date, $end_date) = @_;

    my $app_key = $c->config->{ecowitt_app_key} || '';
    my $api_key = $c->config->{ecowitt_api_key} || '';
    $mac      ||= $c->config->{ecowitt_mac} || '';

    return undef unless $app_key && $api_key && $mac;

    my $ua = LWP::UserAgent->new(timeout => 30);

    # Ecowitt history is a GET with daily aggregation (cycle_type=1day). Was wrongly POST.
    my $url = "https://api.ecowitt.net/api/v3/device/history?"
            . "application_key=" . uri_escape($app_key)
            . "&api_key=" . uri_escape($api_key)
            . "&mac=" . uri_escape($mac)
            . "&start_date=" . uri_escape($start_date)
            . "&end_date=" . uri_escape($end_date)
            . "&call_back=outdoor,rainfall&cycle_type=1day";
    my $response = $ua->get($url);

    if ($response->is_success) {
        return decode_json($response->decoded_content);
    } else {
        warn "Ecowitt API error: " . $response->status_line;
        return undef;
    }
}

# ============================================================================
# API RESPONSE PARSING
# ============================================================================

sub _parse_api_response {
    my ($self, $data, $source) = @_;

    return [] unless $data;

    my @result;

    if ($source eq 'openmeteo') {
        my $daily = $data->{daily} || {};
        my $dates = $daily->{time} || [];

        # Map all 17 Open-Meteo variables to internal field names
        my $tmax_arr   = $daily->{temperature_2m_max} || [];
        my $tmin_arr   = $daily->{temperature_2m_min} || [];
        my $tmean_arr  = $daily->{temperature_2m_mean} || [];
        my $precip_arr = $daily->{precipitation_sum} || [];
        my $humid_arr  = $daily->{relative_humidity_2m_mean} || [];
        my $solar_arr  = $daily->{shortwave_radiation_sum} || [];
        my $et0_arr    = $daily->{et0_fao_evapotranspiration} || [];
        my $wind_arr   = $daily->{wind_speed_10m_max} || [];
        my $dew_arr    = $daily->{dew_point_2m_mean} || [];
        my $soilt_arr  = $daily->{soil_temperature_0_to_7cm_mean} || [];
        my $soilm_arr  = $daily->{soil_moisture_0_to_7cm_mean} || [];

        for my $i (0..$#$dates) {
            push @result, {
                date          => $dates->[$i],
                tmax          => $tmax_arr->[$i] // 20,
                tmin          => $tmin_arr->[$i] // 10,
                tmean         => $tmean_arr->[$i],
                precip        => $precip_arr->[$i] // 0,
                humidity      => $humid_arr->[$i],
                solar         => $solar_arr->[$i],
                et0           => $et0_arr->[$i],
                wind          => $wind_arr->[$i],
                dewpoint      => $dew_arr->[$i],
                soil_temp     => $soilt_arr->[$i],
                soil_moisture => $soilm_arr->[$i],
            };
        }
    }
    elsif ($source eq 'davis') {
        my $sensors = $data->{sensors} || [];
        foreach my $sensor (@$sensors) {
            next unless $sensor->{sensor_type} == 45; # ISS sensor
            foreach my $rec (@{$sensor->{data} || []}) {
                push @result, {
                    date => $self->_timestamp_to_date($rec->{ts}),
                    tmax => $rec->{temp_hi_at} ? ($rec->{temp_hi_at} - 32) * 5/9 : undef,
                    tmin => $rec->{temp_lo_at} ? ($rec->{temp_lo_at} - 32) * 5/9 : undef,
                    precip => $rec->{rainfall_mm} // 0,
                };
            }
        }
    }
    elsif ($source eq 'ecowitt') {
        my $outdoor = $data->{data}{outdoor} || {};
        my $temps = $outdoor->{temperature}{list} || [];
        my $rain = $data->{data}{rainfall}{daily}{list} || [];

        for my $i (0..$#$temps) {
            my $t = $temps->[$i];
            push @result, {
                date => $t->{time},
                tmax => $t->{high},
                tmin => $t->{low},
                precip => $rain->[$i]{value} // 0,
            };
        }
    }

    return \@result;
}

# ============================================================================
# STATION CONFIGURATION
# ============================================================================

# Path matches what the UI actually calls (/station_config/get|save); the old
# /station/config path 404'd and double-registered GET+POST on one path.
sub get_station_config : Path('/ajax/seedquest/weather/station_config/get') Args(0) ActionClass('REST') { }
sub get_station_config_GET {
    my ($self, $c) = @_;

    my $config = {
        source => 'openmeteo',
        davis_configured => ($c->config->{davis_api_key} ? 1 : 0),
        ecowitt_configured => ($c->config->{ecowitt_app_key} ? 1 : 0),
        description => 'Weather data from Open-Meteo Historical API',
        editable => 0,   # station credentials live in sgn_local.conf, not the UI
    };

    $c->stash->{rest} = { success => 1, config => $config };
}

sub save_station_config : Path('/ajax/seedquest/weather/station_config/save') Args(0) ActionClass('REST') { }
sub save_station_config_POST {
    my ($self, $c) = @_;

    unless ($c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in first!' };
        return;
    }

    # Credentials are server-managed (sgn_local.conf). Report honestly instead of
    # falsely claiming the change was saved.
    $c->stash->{rest} = {
        success => 0,
        message => "Weather source is configured on the server (sgn_local.conf); it cannot be changed from the UI.",
    };
}

# ============================================================================
# DATA SOURCES LIST
# ============================================================================

sub get_data_sources : Path('/ajax/seedquest/weather/sources') Args(0) ActionClass('REST') { }
sub get_data_sources_GET {
    my ($self, $c) = @_;

    my @sources = (
        {
            id => 'openmeteo',
            name => 'Open-Meteo',
            description => 'Free historical weather API (1940-present)',
            configured => 1,
            requires_key => 0,
        },
        {
            id => 'davis',
            name => 'Davis WeatherLink',
            description => 'Davis Instruments weather stations',
            configured => ($c->config->{davis_api_key} ? 1 : 0),
            requires_key => 1,
        },
        {
            id => 'ecowitt',
            name => 'Ecowitt Cloud',
            description => 'Ecowitt weather stations',
            configured => ($c->config->{ecowitt_app_key} ? 1 : 0),
            requires_key => 1,
        },
    );

    $c->stash->{rest} = { success => 1, sources => \@sources };
}

# ============================================================================
# CACHE STATISTICS
# ============================================================================

sub get_cache_stats : Path('/ajax/seedquest/weather/cache/stats') Args(0) ActionClass('REST') { }
sub get_cache_stats_GET {
    my ($self, $c) = @_;

    my $stats = { total_records => 0, locations => 0, date_range => {} };

    try {
        my $dbh = $c->dbc->dbh;
        my $sth = $dbh->prepare(q{
            SELECT COUNT(*) as total,
                   COUNT(DISTINCT location_id) as locations,
                   MIN(date) as min_date,
                   MAX(date) as max_date
            FROM weather_data
        });
        $sth->execute();
        my $row = $sth->fetchrow_hashref;

        $stats = {
            total_records => $row->{total} || 0,
            locations => $row->{locations} || 0,
            date_range => {
                min => $row->{min_date} || 'N/A',
                max => $row->{max_date} || 'N/A',
            },
        };
    } catch {
        # Table doesn't exist yet
    };

    $c->stash->{rest} = { success => 1, stats => $stats };
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Single source of truth for GDD/CHU so the on-screen calculator and the Excel
# export can never disagree. cap defined => corn 86/50 (cap tmax, floor tmin at
# base); cap undef => simple average. Returns undef when temps are missing.
sub _gdd_day {
    my ($self, $tmax, $tmin, $base, $cap) = @_;
    return undef unless defined $tmax && defined $tmin;
    my $gdd;
    if (defined $cap) {
        my $t_hi = $tmax > $cap  ? $cap  : $tmax;
        my $t_lo = $tmin < $base ? $base : $tmin;
        $gdd = ($t_hi + $t_lo) / 2 - $base;
    } else {
        $gdd = ($tmax + $tmin) / 2 - $base;
    }
    return $gdd < 0 ? 0 : $gdd;
}

# Ontario CHU (clamping each term independently, like the export did).
sub _chu_day {
    my ($self, $tmax, $tmin) = @_;
    return undef unless defined $tmax && defined $tmin;
    my $ymax = 3.33 * ($tmax - 10) - 0.084 * ($tmax - 10) ** 2;
    $ymax = 0 if $ymax < 0;
    my $ymin = 1.8 * ($tmin - 4.4);
    $ymin = 0 if $ymin < 0;
    return ($ymax + $ymin) / 2;
}

sub _get_location_coords {
    my ($self, $c, $location_id) = @_;

    my ($lat, $lon);   # undef => location has no usable coordinates (caller must handle)
    if ($location_id) {
        try {
            my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
            my $loc = $schema->resultset('NaturalDiversity::NdGeolocation')->find($location_id);
            if ($loc) {
                $lat = $loc->latitude  if defined $loc->latitude;
                $lon = $loc->longitude if defined $loc->longitude;
            }
        } catch { };
    }

    return ($lat, $lon);
}

sub _date_to_timestamp {
    my ($self, $date) = @_;
    my ($y, $m, $d) = split /-/, $date;
    use Time::Local;
    return timelocal(0, 0, 0, $d, $m - 1, $y);
}

sub _timestamp_to_date {
    my ($self, $ts) = @_;
    my @t = localtime($ts);
    return sprintf("%04d-%02d-%02d", $t[5] + 1900, $t[4] + 1, $t[3]);
}

# ============================================================================
# EXCEL EXPORT
# ============================================================================

sub export_weather : Path('/ajax/seedquest/weather/export') Args(0) {
    my ($self, $c) = @_;

    unless ($c->user()) {
        $c->res->status(401);
        $c->res->body('Login required');
        return;
    }

    my $location_id = $c->req->param('location_id');
    my $start_date  = $c->req->param('start_date');
    my $end_date    = $c->req->param('end_date');
    my $base_temp   = $c->req->param('base_temp');
    $base_temp = 10 unless defined $base_temp && $base_temp ne '';
    my $cap_temp    = $c->req->param('cap_temp');
    $cap_temp = undef unless defined $cap_temp && $cap_temp ne '';

    unless ($location_id && $start_date && $end_date) {
        $c->res->status(400);
        $c->res->body('Missing parameters: location_id, start_date, end_date');
        return;
    }

    # Get location name for filename
    my $dbh = $c->dbc->dbh;
    my ($loc_name) = $dbh->selectrow_array(
        "SELECT description FROM nd_geolocation WHERE nd_geolocation_id = ?",
        undef, $location_id
    );
    $loc_name ||= "location_$location_id";
    $loc_name =~ s/[^a-zA-Z0-9_-]/_/g;

    # Fetch weather data from cache
    my $sth = $dbh->prepare(q{
        SELECT DISTINCT ON (date)
            date, temp_max, temp_min, temp_mean, precipitation,
            humidity_mean, solar_radiation, evapotranspiration,
            wind_speed_max, dew_point, soil_temp, soil_moisture, source
        FROM weather_data
        WHERE location_id = ? AND date BETWEEN ? AND ?
        ORDER BY date,
            CASE source
                WHEN 'davis' THEN 1 WHEN 'ecowitt' THEN 1
                WHEN 'open-meteo' THEN 2 WHEN 'noaa' THEN 3
                ELSE 4
            END
    });
    $sth->execute($location_id, $start_date, $end_date);

    my @rows;
    while (my $row = $sth->fetchrow_hashref) {
        push @rows, $row;
    }

    # Generate Excel file
    # Must pass path (not FH) to Excel::Writer::XLSX so data is
    # written to disk and readable back via the same path.
    my ($fh, $tmpfile) = tempfile(SUFFIX => '.xlsx', UNLINK => 1);
    close($fh);
    my $workbook = Excel::Writer::XLSX->new($tmpfile);

    # --- Formats ---
    my $hdr_fmt = $workbook->add_format(
        bold => 1, bg_color => '#2c3e50', color => 'white',
        border => 1, align => 'center', valign => 'vcenter',
    );
    my $date_fmt = $workbook->add_format(num_format => 'yyyy-mm-dd', border => 1);
    my $num_fmt  = $workbook->add_format(num_format => '0.0', border => 1, align => 'center');
    my $num2_fmt = $workbook->add_format(num_format => '0.00', border => 1, align => 'center');
    my $int_fmt  = $workbook->add_format(num_format => '0', border => 1, align => 'center');
    my $title_fmt = $workbook->add_format(
        bold => 1, size => 14, color => '#2c3e50',
    );
    my $sub_fmt = $workbook->add_format(italic => 1, color => '#7f8c8d');

    # === Sheet 1: Daily Data ===
    my $ws1 = $workbook->add_worksheet('Daily Weather Data');
    $ws1->set_landscape();
    $ws1->fit_to_pages(1, 0);

    # Title rows
    $ws1->merge_range('A1:N1', "Weather Data: $loc_name", $title_fmt);
    $ws1->merge_range('A2:N2', "Period: $start_date to $end_date | Base temp: ${base_temp}°C", $sub_fmt);

    # Headers
    my @headers = (
        'Date', 'Tmax (°C)', 'Tmin (°C)', 'Tmean (°C)',
        'Precip (mm)', 'Humidity (%)', 'Solar (MJ/m²)',
        'ET₀ (mm)', 'Wind max (km/h)', 'Dew point (°C)',
        'Soil T (°C)', 'Soil moisture',
        'GDD/day', 'GDD cum.', 'CHU/day', 'CHU cum.',
        'Precip cum. (mm)', 'Source',
    );
    for my $i (0..$#headers) {
        $ws1->write(3, $i, $headers[$i], $hdr_fmt);
        $ws1->set_column($i, $i, $i == 0 ? 12 : 10);
    }

    # Data rows with GDD/CHU calculations
    my $gdd_cum = 0;
    my $chu_cum = 0;
    my $precip_cum = 0;
    my $row_idx = 4;

    foreach my $r (@rows) {
        my $tmax = $r->{temp_max};
        my $tmin = $r->{temp_min};
        my $tavg = $r->{temp_mean} || (defined $tmax && defined $tmin ? ($tmax + $tmin) / 2 : undef);
        my $precip = $r->{precipitation} || 0;

        # GDD/CHU via the shared helpers — identical maths to the on-screen
        # calculator, so screen and Excel can no longer disagree.
        my $gdd_day = $self->_gdd_day($tmax, $tmin, $base_temp, $cap_temp) // 0;
        $gdd_cum += $gdd_day;
        my $chu_day = $self->_chu_day($tmax, $tmin) // 0;
        $chu_cum += $chu_day;
        $precip_cum += $precip;

        $ws1->write_date_time($row_idx, 0, $r->{date} . 'T00:00:00', $date_fmt);
        $ws1->write_number($row_idx, 1, $tmax // 0, $num_fmt);
        $ws1->write_number($row_idx, 2, $tmin // 0, $num_fmt);
        $ws1->write_number($row_idx, 3, $tavg // 0, $num_fmt);
        $ws1->write_number($row_idx, 4, $precip, $num_fmt);
        $ws1->write_number($row_idx, 5, $r->{humidity_mean} // 0, $num_fmt);
        $ws1->write_number($row_idx, 6, $r->{solar_radiation} // 0, $num_fmt);
        $ws1->write_number($row_idx, 7, $r->{evapotranspiration} // 0, $num2_fmt);
        $ws1->write_number($row_idx, 8, $r->{wind_speed_max} // 0, $num_fmt);
        $ws1->write_number($row_idx, 9, $r->{dew_point} // 0, $num_fmt);
        $ws1->write_number($row_idx, 10, $r->{soil_temp} // 0, $num_fmt);
        $ws1->write_number($row_idx, 11, $r->{soil_moisture} // 0, $num2_fmt);
        $ws1->write_number($row_idx, 12, sprintf('%.1f', $gdd_day), $num_fmt);
        $ws1->write_number($row_idx, 13, sprintf('%.1f', $gdd_cum), $num_fmt);
        $ws1->write_number($row_idx, 14, sprintf('%.1f', $chu_day), $num_fmt);
        $ws1->write_number($row_idx, 15, sprintf('%.1f', $chu_cum), $num_fmt);
        $ws1->write_number($row_idx, 16, sprintf('%.1f', $precip_cum), $num_fmt);
        $ws1->write_string($row_idx, 17, $r->{source} || '', $num_fmt);
        $row_idx++;
    }

    # Autofilter
    $ws1->autofilter(3, 0, $row_idx - 1, $#headers);
    # Freeze header row
    $ws1->freeze_panes(4, 1);

    # === Sheet 2: Summary ===
    my $ws2 = $workbook->add_worksheet('Summary');
    $ws2->merge_range('A1:D1', "Season Summary: $loc_name", $title_fmt);
    $ws2->merge_range('A2:D2', "$start_date to $end_date", $sub_fmt);

    my $summary_hdr = $workbook->add_format(bold => 1, border => 1, bg_color => '#ecf0f1');
    my $summary_val = $workbook->add_format(border => 1, num_format => '0.0', align => 'center');

    my @summary = (
        ['Total Days', scalar @rows],
        ['Total GDD (base ' . $base_temp . '°C)', $gdd_cum],
        ['Total CHU', $chu_cum],
        ['Total Precipitation (mm)', $precip_cum],
        ['Avg Tmax (°C)', @rows ? (List::Util::sum(map { $_->{temp_max} // 0 } @rows) / @rows) : 0],
        ['Avg Tmin (°C)', @rows ? (List::Util::sum(map { $_->{temp_min} // 0 } @rows) / @rows) : 0],
        ['Max Tmax (°C)', @rows ? List::Util::max(map { $_->{temp_max} // 0 } @rows) : 0],
        ['Min Tmin (°C)', @rows ? List::Util::min(map { $_->{temp_min} // 0 } @rows) : 0],
    );

    for my $i (0..$#summary) {
        $ws2->write(3 + $i, 0, $summary[$i][0], $summary_hdr);
        $ws2->write(3 + $i, 1, sprintf('%.1f', $summary[$i][1]), $summary_val);
    }
    $ws2->set_column(0, 0, 30);
    $ws2->set_column(1, 1, 15);

    $workbook->close();

    # Send file
    my $filename = "weather_${loc_name}_${start_date}_${end_date}.xlsx";
    open(my $in, '<:raw', $tmpfile) or die "Cannot read temp file: $!";
    my $data = do { local $/; <$in> };
    close($in);

    $c->res->content_type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    $c->res->header('Content-Disposition' => "attachment; filename=\"$filename\"");
    $c->res->body($data);
}

1;

#!/usr/bin/env perl
# Workflow: /feature — Weather Data Backfill
# Backfills weather data for all locations via Open-Meteo Historical API.
# Skips dates that already have data to avoid duplicate work.
#
# Usage: docker exec breedbase_web perl /home/production/cxgn/sgn/bin/backfill_weather.pl
#   or from host: perl bin/backfill_weather.pl (with DB connection)

use strict;
use warnings;
use DBI;
use LWP::UserAgent;
use JSON;
use POSIX qw(strftime);

# --- Configuration ---
my $DB_NAME = $ENV{BREEDBASE_DB} || 'breedbase';
my $DB_HOST = $ENV{BREEDBASE_DB_HOST} || 'breedbase_db';
my $DB_USER = $ENV{BREEDBASE_DB_USER} || 'postgres';
my $DB_PORT = $ENV{BREEDBASE_DB_PORT} || '5432';
my $START_DATE = $ENV{BACKFILL_START} || '2020-01-01';
my $END_DATE   = $ENV{BACKFILL_END}   || strftime('%Y-%m-%d', localtime(time - 86400));
my $SOURCE = 'open-meteo';

# Open-Meteo API variables (full 17-variable agronomical set)
my @OM_VARS = qw(
    temperature_2m_max temperature_2m_min temperature_2m_mean
    precipitation_sum rain_sum snowfall_sum precipitation_hours
    sunshine_duration et0_fao_evapotranspiration
    wind_speed_10m_max wind_gusts_10m_max wind_direction_10m_dominant
    shortwave_radiation_sum relative_humidity_2m_mean
    dew_point_2m_mean
    soil_temperature_0_to_7cm_mean soil_moisture_0_to_7cm_mean
);

# --- DB Connection ---
my $dsn = "dbi:Pg:dbname=$DB_NAME;host=$DB_HOST;port=$DB_PORT";
my $dbh = DBI->connect($dsn, $DB_USER, '', {
    RaiseError => 1,
    AutoCommit => 1,
    PrintError => 0,
}) or die "Cannot connect to $dsn: $DBI::errstr\n";

print "Connected to $DB_NAME @ $DB_HOST\n";

# --- Get all locations with coordinates ---
my $loc_sth = $dbh->prepare(q{
    SELECT nd_geolocation_id, description, latitude, longitude
    FROM nd_geolocation
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL
    ORDER BY nd_geolocation_id
});
$loc_sth->execute();

my @locations;
while (my $row = $loc_sth->fetchrow_hashref) {
    push @locations, $row;
}
print "Found " . scalar(@locations) . " locations with coordinates\n\n";

# --- Upsert statement ---
my $upsert_sth = $dbh->prepare(q{
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

my $ua = LWP::UserAgent->new(timeout => 120);

foreach my $loc (@locations) {
    my $loc_id  = $loc->{nd_geolocation_id};
    my $name    = $loc->{description};
    my $lat     = $loc->{latitude};
    my $lon     = $loc->{longitude};

    # Check existing date coverage to find gaps
    my ($existing) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM weather_data WHERE location_id = ? AND source = ?",
        undef, $loc_id, $SOURCE
    );

    print "=== $name (ID=$loc_id, lat=$lat, lon=$lon) — $existing existing records ===\n";

    # Fetch in yearly chunks to respect Open-Meteo limits
    my ($start_year) = $START_DATE =~ /^(\d{4})/;
    my ($end_year)   = $END_DATE   =~ /^(\d{4})/;

    my $total_inserted = 0;

    for my $year ($start_year .. $end_year) {
        my $chunk_start = ($year == $start_year) ? $START_DATE : "$year-01-01";
        my $chunk_end   = ($year == $end_year)   ? $END_DATE   : "$year-12-31";

        # Skip if chunk_end is before chunk_start
        next if $chunk_end lt $chunk_start;

        my $vars_str = join(',', @OM_VARS);
        my $url = sprintf(
            "https://archive-api.open-meteo.com/v1/archive?latitude=%.4f&longitude=%.4f&start_date=%s&end_date=%s&daily=%s&timezone=auto",
            $lat, $lon, $chunk_start, $chunk_end, $vars_str
        );

        my $response = $ua->get($url);
        unless ($response->is_success) {
            warn "  WARN: API failed for $name/$year: " . $response->status_line . "\n";
            next;
        }

        my $data = eval { decode_json($response->decoded_content) };
        if ($@) {
            warn "  WARN: JSON parse error for $name/$year: $@\n";
            next;
        }

        my $daily = $data->{daily} || {};
        my $dates = $daily->{time} || [];

        # Rate-limit protection: brief pause between API calls
        sleep(1) if scalar(@$dates) > 0;

        my $chunk_count = 0;
        for my $i (0 .. $#$dates) {
            $upsert_sth->execute(
                $loc_id,
                $dates->[$i],
                $daily->{temperature_2m_max}[$i],
                $daily->{temperature_2m_min}[$i],
                $daily->{temperature_2m_mean}[$i],
                $daily->{precipitation_sum}[$i]           // 0,
                $daily->{relative_humidity_2m_mean}[$i],
                $daily->{shortwave_radiation_sum}[$i],
                $daily->{et0_fao_evapotranspiration}[$i],
                $daily->{wind_speed_10m_max}[$i],
                $daily->{dew_point_2m_mean}[$i],
                $daily->{soil_temperature_0_to_7cm_mean}[$i],
                $daily->{soil_moisture_0_to_7cm_mean}[$i],
                $SOURCE
            );
            $chunk_count++;
        }
        $total_inserted += $chunk_count;
        print "  $year: $chunk_count days fetched\n";
    }

    print "  TOTAL: $total_inserted records upserted\n\n";
}

$dbh->disconnect();
print "=== Backfill complete ===\n";

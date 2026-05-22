#!/usr/bin/env python3
"""
SeedQuest / BreedBase weather auto-sync (rewritten 2026-05-22)

Writes into the SAME `weather_data` table the Perl Weather controller reads from,
so the nightly sync actually warms the GDD calculator's cache. (The old script
stored JSON blobs in nd_geolocationprop, which nothing read.)

- Recent days come from the Open-Meteo Historical Forecast API (low lag, tracks
  actuals); see SEEDQUEST_WEATHER_RESEARCH_2026-05-22.md.
- Upsert on (location_id, date, source); optional retention cleanup.

cron:  0 6 * * *  /srv/breedbase/tools/weather/sync_weather.py
"""

import os
import sys
import argparse
from datetime import datetime, timedelta

import requests
import psycopg2
import psycopg2.extras

DB_CONFIG = {
    'host':     os.environ.get('PGHOST', 'breedbase_db'),
    'database': os.environ.get('PGDATABASE', 'breedbase'),
    'user':     os.environ.get('PGUSER', 'postgres'),
    'password': os.environ.get('PGPASSWORD'),
}
LOG_FILE = '/srv/breedbase/volume/weather/sync.log'

# Open-Meteo daily variables -> weather_data columns
DAILY_VARS = [
    'temperature_2m_max', 'temperature_2m_min', 'temperature_2m_mean',
    'precipitation_sum', 'relative_humidity_2m_mean', 'shortwave_radiation_sum',
    'et0_fao_evapotranspiration', 'wind_speed_10m_max', 'dew_point_2m_mean',
    'soil_temperature_0_to_7cm_mean', 'soil_moisture_0_to_7cm_mean',
]
COL_FROM_VAR = {
    'temperature_2m_max': 'temp_max',
    'temperature_2m_min': 'temp_min',
    'temperature_2m_mean': 'temp_mean',
    'precipitation_sum': 'precipitation',
    'relative_humidity_2m_mean': 'humidity_mean',
    'shortwave_radiation_sum': 'solar_radiation',
    'et0_fao_evapotranspiration': 'evapotranspiration',
    'wind_speed_10m_max': 'wind_speed_max',
    'dew_point_2m_mean': 'dew_point',
    'soil_temperature_0_to_7cm_mean': 'soil_temp',
    'soil_moisture_0_to_7cm_mean': 'soil_moisture',
}

ARCHIVE_URL = 'https://archive-api.open-meteo.com/v1/archive'
RECENT_URL  = 'https://historical-forecast-api.open-meteo.com/v1/forecast'

DDL = """
CREATE TABLE IF NOT EXISTS weather_data (
    id                 SERIAL PRIMARY KEY,
    location_id        INTEGER NOT NULL,
    date               DATE    NOT NULL,
    temp_max           REAL, temp_min REAL, temp_mean REAL,
    precipitation      REAL, humidity_mean REAL, solar_radiation REAL,
    evapotranspiration REAL, wind_speed_max REAL, dew_point REAL,
    soil_temp          REAL, soil_moisture REAL,
    source             TEXT NOT NULL DEFAULT 'open-meteo',
    updated_at         TIMESTAMP DEFAULT now(),
    UNIQUE (location_id, date, source)
);
CREATE INDEX IF NOT EXISTS weather_data_loc_date ON weather_data (location_id, date);
ALTER TABLE weather_data ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE weather_data ADD COLUMN IF NOT EXISTS solar_radiation REAL;
ALTER TABLE weather_data ADD COLUMN IF NOT EXISTS dew_point REAL;
ALTER TABLE weather_data ADD COLUMN IF NOT EXISTS soil_temp REAL;
ALTER TABLE weather_data ADD COLUMN IF NOT EXISTS soil_moisture REAL;
CREATE UNIQUE INDEX IF NOT EXISTS weather_data_location_date_source_unique
    ON weather_data (location_id, date, source);
"""

UPSERT = """
INSERT INTO weather_data
    (location_id, date, temp_max, temp_min, temp_mean, precipitation,
     humidity_mean, solar_radiation, evapotranspiration, wind_speed_max,
     dew_point, soil_temp, soil_moisture, source, updated_at)
VALUES %s
ON CONFLICT (location_id, date, source) DO UPDATE SET
    temp_max = EXCLUDED.temp_max, temp_min = EXCLUDED.temp_min,
    temp_mean = EXCLUDED.temp_mean, precipitation = EXCLUDED.precipitation,
    humidity_mean = EXCLUDED.humidity_mean, solar_radiation = EXCLUDED.solar_radiation,
    evapotranspiration = EXCLUDED.evapotranspiration, wind_speed_max = EXCLUDED.wind_speed_max,
    dew_point = EXCLUDED.dew_point, soil_temp = EXCLUDED.soil_temp,
    soil_moisture = EXCLUDED.soil_moisture, updated_at = now();
"""


def log(msg):
    line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, 'a') as f:
            f.write(line + '\n')
    except OSError:
        pass


def get_locations(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT nd_geolocation_id, description, latitude, longitude
            FROM nd_geolocation
            WHERE latitude IS NOT NULL AND longitude IS NOT NULL
        """)
        return [{'id': r[0], 'name': r[1], 'lat': float(r[2]), 'lon': float(r[3])}
                for r in cur.fetchall()]


def fetch_openmeteo(lat, lon, start_date, end_date):
    """Recent dates (>=2022) -> Historical Forecast API (low lag); older -> Archive."""
    base = RECENT_URL if int(start_date[:4]) >= 2022 else ARCHIVE_URL
    params = {
        'latitude': lat, 'longitude': lon,
        'start_date': start_date, 'end_date': end_date,
        'daily': ','.join(DAILY_VARS), 'timezone': 'auto',
    }
    r = requests.get(base, params=params, timeout=60)
    r.raise_for_status()
    return r.json()


def rows_from_response(location_id, data, source='open-meteo'):
    daily = (data or {}).get('daily') or {}
    dates = daily.get('time') or []
    rows = []
    for i, d in enumerate(dates):
        def val(var):
            arr = daily.get(var) or []
            return arr[i] if i < len(arr) else None
        rows.append((
            location_id, d,
            val('temperature_2m_max'), val('temperature_2m_min'), val('temperature_2m_mean'),
            val('precipitation_sum'), val('relative_humidity_2m_mean'), val('shortwave_radiation_sum'),
            val('et0_fao_evapotranspiration'), val('wind_speed_10m_max'), val('dew_point_2m_mean'),
            val('soil_temperature_0_to_7cm_mean'), val('soil_moisture_0_to_7cm_mean'),
            source, datetime.now(),
        ))
    return rows


def sync(days_back=30, retain_days=730):
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    try:
        with conn.cursor() as cur:
            cur.execute(DDL)
        conn.commit()

        locations = get_locations(conn)
        log(f"=== Weather sync: {len(locations)} location(s) ===")
        if not locations:
            return

        end_date = datetime.now().strftime('%Y-%m-%d')
        start_date = (datetime.now() - timedelta(days=days_back)).strftime('%Y-%m-%d')
        log(f"Range {start_date} .. {end_date}")

        ok = 0
        for loc in locations:
            try:
                data = fetch_openmeteo(loc['lat'], loc['lon'], start_date, end_date)
                rows = rows_from_response(loc['id'], data)
                if rows:
                    with conn.cursor() as cur:
                        psycopg2.extras.execute_values(cur, UPSERT, rows)
                    conn.commit()
                    ok += 1
                    log(f"  ✓ {loc['name']} (id={loc['id']}): {len(rows)} days")
                else:
                    log(f"  · {loc['name']} (id={loc['id']}): no data returned")
            except Exception as e:
                conn.rollback()
                log(f"  ✗ {loc['name']} (id={loc['id']}): {e}")

        if ok == 0:
            raise RuntimeError(f"Weather sync failed for all {len(locations)} locations")

        if retain_days and retain_days > 0:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM weather_data WHERE date < (CURRENT_DATE - %s::int)", (retain_days,))
                deleted = cur.rowcount
            conn.commit()
            if deleted:
                log(f"Retention: removed {deleted} rows older than {retain_days} days")

        log(f"=== Done: {ok}/{len(locations)} locations ===")
    finally:
        conn.close()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--days', type=int, default=30, help='Days of history to refresh')
    p.add_argument('--retain', type=int, default=730, help='Delete weather_data older than N days (0 = keep all)')
    p.add_argument('--list', action='store_true', help='List locations only')
    args = p.parse_args()

    if args.list:
        conn = psycopg2.connect(**DB_CONFIG)
        for loc in get_locations(conn):
            print(f"  {loc['id']}: {loc['name']} ({loc['lat']}, {loc['lon']})")
        conn.close()
    else:
        sync(args.days, args.retain)


if __name__ == '__main__':
    main()

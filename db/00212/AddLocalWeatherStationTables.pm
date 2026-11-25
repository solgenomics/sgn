#!/usr/bin/env perl

=head1 NAME

AddLocalWeatherStationTables

=head1 SYNOPSIS

mx-run AddLocalWeatherStationTables [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds the tables of the weather stations that users upload themselves (the
station of a research farm, read from a CSV or Excel file):

  public.local_weather_station   one station, attached to a location (nd_geolocation)
  public.local_weather_daily     its daily observations (one row per station and day)

Used by the Weather page (/breeders/weather) as the 'local' network and by
the Weather section of the trial page. See CXGN::Weather::Local.

=head1 AUTHOR

Chris Simoes

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddLocalWeatherStationTables;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the tables local_weather_station and local_weather_daily (weather data uploaded from the stations of research farms)

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

CREATE TABLE IF NOT EXISTS public.local_weather_station (
    local_weather_station_id serial PRIMARY KEY,
    nd_geolocation_id bigint NOT NULL REFERENCES public.nd_geolocation (nd_geolocation_id) ON DELETE CASCADE,
    name varchar(200) NOT NULL,
    latitude double precision,
    longitude double precision,
    altitude double precision,
    description text,
    sp_person_id bigint REFERENCES sgn_people.sp_person (sp_person_id) ON DELETE SET NULL,
    create_date timestamp without time zone DEFAULT now(),
    modified_date timestamp without time zone DEFAULT now(),
    UNIQUE (nd_geolocation_id, name)
);

COMMENT ON TABLE public.local_weather_station IS 'Weather stations whose data users upload (CSV/Excel), attached to a location. See CXGN::Weather::Local.';

CREATE TABLE IF NOT EXISTS public.local_weather_daily (
    local_weather_station_id bigint NOT NULL REFERENCES public.local_weather_station (local_weather_station_id) ON DELETE CASCADE,
    obs_date date NOT NULL,
    tmax real,
    tmin real,
    tmean real,
    rain real,
    rh real,
    wind real,
    radiation real,
    n_records integer,
    complete boolean NOT NULL DEFAULT true,
    archived_file text,
    sp_person_id bigint REFERENCES sgn_people.sp_person (sp_person_id) ON DELETE SET NULL,
    upload_date timestamp without time zone DEFAULT now(),
    PRIMARY KEY (local_weather_station_id, obs_date)
);

COMMENT ON TABLE public.local_weather_daily IS 'Daily observations of the uploaded weather stations: temperatures (C), rain (mm), relative humidity (%), mean wind (m/s), solar radiation (MJ/m2/day). n_records: sub-daily records summarized into the day (NULL for daily uploads).';

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.local_weather_station TO web_usr;
GRANT USAGE ON SEQUENCE public.local_weather_station_local_weather_station_id_seq TO web_usr;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.local_weather_daily TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
